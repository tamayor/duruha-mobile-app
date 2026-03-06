import 'dart:async';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/consumer/features/subscription/futureplan/domain/consumer_future_plan_subscription_model.dart';
import 'package:duruha/features/consumer/features/tx/presentation/widgets/faq_customer_order_note.dart';
import 'package:duruha/shared/produce/data/produce_repository.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'crop_selection_state.dart';
import 'widgets/order_form.dart';
import '../data/transaction_draft_service.dart';
import 'package:duruha/core/services/session_service.dart';
import 'transaction_review_screen.dart';
import 'package:duruha/core/faq/faq.dart';

class TransactionCreateScreen extends StatefulWidget {
  final List<String> selectedCropIds;

  /// 'order' — single purchase (immediate matching)
  /// 'plan'  — recurring subscription (future deliveries)
  final String mode;

  const TransactionCreateScreen({
    super.key,
    required this.selectedCropIds,
    required this.mode,
  });

  @override
  State<TransactionCreateScreen> createState() =>
      _TransactionCreateScreenState();
}

class _TransactionCreateScreenState extends State<TransactionCreateScreen> {
  final _produceRepository = ProduceRepository();

  bool _isLoading = true;
  bool _isAllCompact = false;
  List<Produce> _selectedProduce = [];

  final Map<String, CropSelectionState> _cropStates = {};

  RealtimeChannel? _realtimeChannel;
  Timer? _debounce;

  TransactionMode get _txMode =>
      widget.mode == 'plan' ? TransactionMode.plan : TransactionMode.order;

  bool get _isPlan => _txMode == TransactionMode.plan;

  ConsumerFuturePlanSubscription? _cfpSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeRealtime();
    if (_isPlan) _loadCfpSubscription();
  }

  Future<void> _loadCfpSubscription() async {
    try {
      final userId = await SessionService.getUserId();
      if (userId == null) return;
      final supabase = Supabase.instance.client;
      // First resolve consumer_id from user_id
      final consumerRow = await supabase
          .from('user_consumers')
          .select('consumer_id')
          .eq('user_id', userId)
          .maybeSingle();
      final consumerId = consumerRow?['consumer_id'] as String?;
      if (consumerId == null) return;

      // Fetch active CFP subscription joined with config via explicit FK
      final response = await supabase
          .from('consumer_future_plan_subscriptions')
          .select('*, consumer_future_plan_configs!cfp_subs_config_fkey(*)')
          .eq('consumer_id', consumerId)
          .eq('is_active', true)
          .order('starts_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (response != null && mounted) {
        setState(() {
          _cfpSubscription = ConsumerFuturePlanSubscription.fromJson(
            Map<String, dynamic>.from(response),
          );
        });
      }
    } catch (e) {
      debugPrint('⚠️ [CFP] Failed to load subscription: $e');
    }
  }

  void _subscribeRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel(
          'tx_create_produce_${DateTime.now().millisecondsSinceEpoch}',
        ) // 👈 only change needed
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'farmer_offers',
          callback: (payload) {
            _debouncedReloadAll();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'produce_variety_listing',
          callback: (payload) {
            _debouncedReloadAll();
          },
        )
        .subscribe((status, [error]) {});
  }

  void _debouncedReloadAll() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      debugPrint(
        '🔄 [REALTIME] Reloading ${_selectedProduce.length} produce(s)...',
      );
      for (final produce in _selectedProduce) {
        _reloadProduce(produce.id);
      }
    });
  }

  Future<void> _loadData() async {
    try {
      if (widget.selectedCropIds.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final filtered = await _produceRepository.fetchProduceByIds(
        widget.selectedCropIds,
        mode: 'for_consumer',
      );

      if (filtered.isEmpty && mounted) {
        DuruhaSnackBar.showError(
          context,
          'Could not load crop details. Please re-select crops.',
        );
      }

      if (mounted) {
        setState(() {
          _selectedProduce = filtered;
          _isLoading = false;
        });
      }

      for (var produce in filtered) {
        final draft = await TransactionDraftService.getDraft(
          produce.id,
          _txMode,
        );

        final state = CropSelectionState(
          dateController: TextEditingController(),
          selectedUnit: draft?.selectedUnit ?? produce.unitOfMeasure,
          selectedVariants: [],
          varietyQuantityControllers: {},
          varietyAvailableDates: draft?.varietyAvailableDates ?? {},
          varietyDisposalDates: draft?.varietyDisposalDates ?? {},
          varietyDateNeeded: draft?.varietyDateNeeded ?? {},
          varietyRecurrence: draft?.varietyRecurrence ?? {},
          varietySelectedFormId: draft?.varietySelectedFormId ?? {},
          // Price locks are NEVER restored — reset on every session entry
          // to prevent stale locks from bleeding between mode switches.
          varietyPriceLock: {},
        );

        if (draft != null) {
          _applyDraft(produce, state, draft);
        }

        if (mounted) {
          setState(() => _cropStates[produce.id] = state);
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('❌ [TX CREATE] Error: $e');
      if (mounted) {
        DuruhaSnackBar.showError(context, 'Error loading data: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  /// Silently re-fetches a single produce and updates listings/prices in place.
  Future<void> _reloadProduce(String produceId) async {
    try {
      final refreshed = await _produceRepository.fetchProduceByIds([
        produceId,
      ], mode: 'for_consumer');
      if (!mounted || refreshed.isEmpty) {
        return;
      }
      // // Log price change for debugging
      // final oldProduce = _selectedProduce.firstWhere(
      //   (p) => p.id == produceId,
      //   orElse: () => refreshed.first,
      // );
      // final oldPrices = oldProduce.varieties
      //     .expand((v) => v.listings)
      //     .map((l) => '${l.produceForm}:${l.duruhaToConsumerPrice}')
      //     .join(', ');
      // final newPrices = refreshed.first.varieties
      //     .expand((v) => v.listings)
      //     .map((l) => '${l.produceForm}:${l.duruhaToConsumerPrice}')
      //     .join(', ');
      // debugPrint('📊 [RELOAD] OLD prices: $oldPrices');
      // debugPrint('📊 [RELOAD] NEW prices: $newPrices');
      setState(() {
        final idx = _selectedProduce.indexWhere((p) => p.id == produceId);
        if (idx != -1) _selectedProduce[idx] = refreshed.first;
      });
    } catch (e) {
      // debugPrint('⚠️ [TX CREATE] Silent reload failed for $produceId: $e');
    }
  }

  /// Applies a saved draft back into a [CropSelectionState].
  void _applyDraft(
    Produce produce,
    CropSelectionState state,
    CropDraftData draft,
  ) {
    state.varietyAvailableDates = Map.from(draft.varietyAvailableDates);
    state.varietyDisposalDates = Map.from(draft.varietyDisposalDates);
    state.varietyDateNeeded = Map.from(draft.varietyDateNeeded);
    state.varietyRecurrence = Map.from(draft.varietyRecurrence);
    state.varietySelectedFormId = Map.from(draft.varietySelectedFormId);
    state.varietyGroups = draft.varietyGroups
        .map((g) => Set<String>.from(g))
        .toList();

    if (draft.selectedHarvestDates.isNotEmpty) {
      state.selectedHarvestDates = List.from(draft.selectedHarvestDates);
      final dates = state.selectedHarvestDates..sort();
      state.dateController.text = dates.length == 1
          ? DateFormat('MMM dd, yyyy').format(dates.first)
          : '${dates.length} dates selected';
    }

    if (draft.perDatePledges.isNotEmpty) {
      state.perDatePledges = List.from(draft.perDatePledges);
      if (draft.dateSpecificDemand.isNotEmpty) {
        state.dateSpecificDemand = Map.from(draft.dateSpecificDemand);
      }
    } else if (draft.varietyQuantities.isNotEmpty) {
      state.selectedVariants = draft.varietyQuantities.keys.toList();
      for (final entry in draft.varietyQuantities.entries) {
        state.varietyQuantityControllers[entry.key] = TextEditingController(
          text: entry.value.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), ''),
        );
      }
    }
  }

  Future<void> _saveDraft(String cropId) async {
    final state = _cropStates[cropId];
    if (state == null) return;

    final quantities = <String, double>{};
    for (final entry in state.varietyQuantityControllers.entries) {
      final val = double.tryParse(entry.value.text);
      if (val != null && val > 0) quantities[entry.key] = val;
    }

    await TransactionDraftService.saveDraft(
      cropId,
      CropDraftData(
        selectedHarvestDates: state.selectedHarvestDates,
        selectedUnit: state.selectedUnit,
        varietyQuantities: quantities,
        varietyAvailableDates: state.varietyAvailableDates,
        varietyDisposalDates: state.varietyDisposalDates,
        varietyDateNeeded: state.varietyDateNeeded,
        varietyGroups: state.varietyGroups,
        simulatedDemand: state.simulatedDemand,
        perDatePledges: state.perDatePledges,
        dateSpecificDemand: state.dateSpecificDemand,
        varietySelectedFormId: state.varietySelectedFormId,
        varietyPriceLock: state.varietyPriceLock,
        varietyRecurrence: state.varietyRecurrence,
      ),
      _txMode,
    );
  }

  Future<void> _clearAll() async {
    final confirmed = await _confirmDialog(
      'Clear Drafts?',
      'This will clear all entered data for these crops.',
    );
    if (confirmed != true) return;

    await TransactionDraftService.clearAllForMode(_txMode);
    if (mounted) {
      DuruhaSnackBar.showSuccess(context, 'Drafts cleared');
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/consumer/shop', (route) => false);
    }
  }

  Future<void> _removeProduce(String produceId) async {
    await TransactionDraftService.clearDraft(produceId, _txMode);
    setState(() {
      _selectedProduce.removeWhere((p) => p.id == produceId);
      _cropStates.remove(produceId);
    });
    if (_selectedProduce.isEmpty && mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    for (final state in _cropStates.values) {
      state.dateController.dispose();
      for (final c in state.varietyQuantityControllers.values) {
        c.dispose();
      }
    }
    super.dispose();
  }

  // ─── Validation & Navigation ─────────────────────────────────────────────────

  void _goToReview() {
    for (var produce in _selectedProduce) {
      final state = _cropStates[produce.id]!;
      final name = produce.nameEnglish;

      if (_isPlan) {
        _clearPlanStockErrors(state);
      }

      // Shared: field-level validation errors must be empty
      if (state.validationErrors.isNotEmpty) {
        DuruhaSnackBar.showWarning(
          context,
          'Please fix quantity errors for $name before continuing.',
        );
        return;
      }

      if (_isPlan) {
        if (!_validatePlan(produce, state)) return;
      } else {
        if (!_validateOrder(produce, state)) return;
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TransactionReviewScreen(
          mode: widget.mode,
          selectedProduce: _selectedProduce,
          cropStates: _cropStates,
        ),
      ),
    );
  }

  /// Clears stock-validation errors for varieties that have a recurring schedule
  /// (Plan mode: stock is irrelevant for future dates).
  void _clearPlanStockErrors(CropSelectionState state) {
    for (final entry in state.varietyRecurrence.entries) {
      final recurrence = entry.value;
      if (recurrence != null && recurrence.isNotEmpty) {
        final qtyController = state.varietyQuantityControllers[entry.key];
        final qty = double.tryParse(qtyController?.text ?? '') ?? 0;
        if (qty == 0) state.validationErrors.remove(entry.key);
      }
    }
  }

  bool _validatePlan(Produce produce, CropSelectionState state) {
    // ── 1. Validate each produce has at least one item selected ──────────────
    final selectedVariants = state.selectedVariants;
    final varietyGroups = state.varietyGroups;

    if (selectedVariants.isEmpty && varietyGroups.isEmpty) {
      DuruhaSnackBar.showWarning(
        context,
        'Please select at least one variety or group for ${produce.nameEnglish}.',
      );
      return false;
    }

    // ── 2. Validate ungrouped varieties ───────────────────────────────────────
    final groupedVarieties = varietyGroups.expand((g) => g).toSet();
    final ungroupedVariants = selectedVariants
        .where((v) => !groupedVarieties.contains(v))
        .toList();

    for (final v in ungroupedVariants) {
      final controller = state.varietyQuantityControllers[v];
      final qty = double.tryParse(controller?.text ?? '') ?? 0;

      if (qty <= 0) {
        DuruhaSnackBar.showWarning(
          context,
          'Please enter a quantity for "$v" in ${produce.nameEnglish}.',
        );
        return false;
      }

      // Check recurrence
      final recurrence =
          state.varietyRecurrence[v] ?? state.varietyRecurrence['qty_$v'];
      if (recurrence == null || recurrence.isEmpty) {
        DuruhaSnackBar.showWarning(
          context,
          'Please set a recurring schedule for "$v" in ${produce.nameEnglish}.',
        );
        return false;
      }
    }

    // ── 3. Validate groups ────────────────────────────────────────────────────
    for (int i = 0; i < varietyGroups.length; i++) {
      final group = varietyGroups[i];
      if (group.isEmpty) continue;

      // Use the first member's controller as the group quantity holder
      final firstMember = group.first;
      final controller = state.varietyQuantityControllers[firstMember];
      final qty = double.tryParse(controller?.text ?? '') ?? 0;

      if (qty <= 0) {
        DuruhaSnackBar.showWarning(
          context,
          'Please enter a quantity for Group ${i + 1} in ${produce.nameEnglish}.',
        );
        return false;
      }

      // Check recurrence — stored under 'group_i'
      final recurrence = state.varietyRecurrence['group_$i'];
      if (recurrence == null || recurrence.isEmpty) {
        DuruhaSnackBar.showWarning(
          context,
          'Please set a recurring schedule for Group ${i + 1} in ${produce.nameEnglish}.',
        );
        return false;
      }
    }

    return true;
  }

  bool _validateOrder(Produce produce, CropSelectionState state) {
    bool anyQuantity = false;
    bool allDatesSet = true;

    for (final entry in state.varietyQuantityControllers.entries) {
      final qty = double.tryParse(entry.value.text) ?? 0;
      if (qty > 0) {
        anyQuantity = true;
        final key = entry.key;
        // Support both 'qty_<name>' and bare variety name keys
        final dateKey = key.startsWith('qty_')
            ? key.replaceFirst('qty_', '')
            : key;
        if (state.varietyDateNeeded[dateKey] == null &&
            state.varietyDateNeeded[key] == null) {
          allDatesSet = false;
          break;
        }
      }
    }

    if (!anyQuantity) {
      DuruhaSnackBar.showWarning(
        context,
        'Please enter a quantity for at least one variety of '
        '${produce.nameEnglish}.',
      );
      return false;
    }

    if (!allDatesSet) {
      DuruhaSnackBar.showWarning(
        context,
        'Please set a delivery date for every item in your '
        '${produce.nameEnglish} order.',
      );
      return false;
    }
    return true;
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modeTitle = _isPlan ? 'Plan Order' : 'Order Now';

    List<Widget> slivers = [];
    if (!_isLoading) {
      for (var p in _selectedProduce) {
        slivers.add(_buildCropSliver(p));
      }
      slivers.add(const SliverPadding(padding: EdgeInsets.only(bottom: 120)));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_selectedProduce.map((p) => p.id).toList());
      },
      child: DuruhaScaffold(
        appBarTitle: modeTitle,
        onBackPressed: () {
          Navigator.of(context).pop(_selectedProduce.map((p) => p.id).toList());
        },
        appBarActions: [
          IconButton(
            icon: Icon(_isAllCompact ? Icons.unfold_more : Icons.unfold_less),
            onPressed: () => setState(() => _isAllCompact = !_isAllCompact),
            tooltip: _isAllCompact ? 'Expand All' : 'Collapse All',
          ),
          if (!_isPlan)
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'How Orders Work',
              onPressed: () =>
                  DuruhaFaqModal.show(context, faqCustomerOrderNote),
            ),
          if (_selectedProduce.isNotEmpty && !_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Clear Draft',
              onPressed: _clearAll,
            ),
        ],
        isLoading: _isLoading,
        body: _selectedProduce.isEmpty && !_isLoading
            ? const Center(child: Text('No crops selected'))
            : DuruhaScrollHideWrapper(
                bar: _buildModeNote(theme),
                hideHeight: 100,
                body: CustomScrollView(slivers: slivers),
              ),
        floatingActionButton: _selectedProduce.isNotEmpty && !_isLoading
            ? FloatingActionButton.extended(
                onPressed: _goToReview,
                backgroundColor: theme.colorScheme.tertiary,
                foregroundColor: theme.colorScheme.onTertiary,
                elevation: 8,
                label: const Text('Continue'),
                icon: const Icon(Icons.chevron_right_rounded),
              )
            : null,
      ),
    );
  }

  Widget _buildCropSliver(Produce produce) {
    final theme = Theme.of(context);
    final state = _cropStates[produce.id]!;

    return DuruhaSectionSliver(
      compactOverride: _isAllCompact,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          produce.imageThumbnailUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.eco_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
      title: Text(produce.nameEnglish),
      subtitle: (produce.nameScientific?.isNotEmpty ?? false)
          ? Text(
              produce.nameScientific!,
              style: const TextStyle(fontStyle: FontStyle.italic),
            )
          : null,
      trailing: IconButton(
        onPressed: () => _removeProduce(produce.id),
        icon: Icon(
          Icons.remove_circle_outline_rounded,
          color: theme.colorScheme.error,
        ),
        tooltip: 'Remove Crop',
      ),
      content: DuruhaSectionContainer(
        title: _isPlan ? 'Plan Details' : 'Order Details',
        subtitle: _isPlan
            ? 'Set recurring schedule and quantities'
            : 'Set delivery date and quantities',
        children: [
          OrderForm(
            mode: widget.mode,
            produce: produce,
            state: state,
            onAvailableDatePicked: (_) => _saveDraft(produce.id),
            onDisposalDatePicked: (_) => _saveDraft(produce.id),
            onStateChanged: () => _saveDraft(produce.id),
            onProduceChanged: () => _reloadProduce(produce.id),
            planStartDate: _isPlan ? _cfpSubscription?.startsAt : null,
            planEndDate: _isPlan ? _cfpSubscription?.expiresAt : null,
          ),
        ],
      ),
    );
  }

  Widget _buildModeNote(ThemeData theme) {
    // Plan mode: show CFP subscription info when available
    if (_isPlan && _cfpSubscription != null) {
      final sub = _cfpSubscription!;
      final color = theme.colorScheme.onPrimary;
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_repeat_rounded, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sub.planName ?? 'Consumer Future Plan',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _cfpInfoRow(
              theme,
              Icons.price_change_outlined,
              'Total value',
              sub.formattedValueRange ?? 'N/A',
              color,
            ),
            _cfpInfoRow(
              theme,
              Icons.date_range_outlined,
              'Schedule window',
              '${DateFormat('MMM d').format(sub.startsAt)} – ${DateFormat('MMM d, yyyy').format(sub.expiresAt)}',
              color,
            ),
          ],
        ),
      );
    }

    // Fallback for plan mode without subscription, or order mode
    final isOrder = !_isPlan;
    final icon = isOrder ? Icons.shopping_bag_outlined : Icons.repeat_rounded;
    final color = isOrder
        ? theme.colorScheme.tertiary
        : theme.colorScheme.secondary;
    final text = isOrder
        ? '🛒 Order Mode — Select varieties, set delivery date & quantity. '
              'Only in-stock varieties can be ordered (within 30 days).'
        : '📅 Plan Mode — Schedule recurring deliveries. '
              'Subscribe to a Consumer Future Plan to unlock scheduling up to 12 months ahead.';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cfpInfoRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmDialog(String title, String content) {
    final theme = Theme.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.colorScheme.onPrimary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Clear',
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
