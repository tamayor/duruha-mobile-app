import 'dart:async';
import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/consumer/features/subscription/futureplan/domain/consumer_future_plan_subscription_model.dart';
import 'package:duruha/shared/produce/data/produce_repository.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:duruha/shared/produce/domain/produce_variety.dart';
import 'package:duruha/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'crop_selection_state.dart';
import '../data/transaction_draft_service.dart';
import '../data/transaction_repository.dart';
import 'widgets/recurring_picker.dart';
import '../../subscription/pricelock/domain/price_lock_subscription_model.dart';
import '../../subscription/pricelock/data/subscription_repository.dart';
import '../../../shared/presentation/consumer_loading_screen.dart';
import '../../manage/presentation/order_details_screen.dart';
import 'package:duruha/core/faq/faq_transaction_review.dart';
import 'package:duruha/core/constants/color_marker.dart';
import '../../subscription/quality/domain/quality_subscription_model.dart';

// ─── Price-range helper ───────────────────────────────────────────────────────

/// Computed price range for a set of variety listings.
class _PriceRange {
  final double min;
  final double max;

  const _PriceRange(this.min, this.max);

  bool get isSingle => (max - min).abs() < 0.001;

  String get label => isSingle
      ? DuruhaFormatter.formatCurrency(min)
      : '${DuruhaFormatter.formatCurrency(min)}–${DuruhaFormatter.formatCurrency(max)}';
}

/// A single line item in the plan's delivery breakdown.
class _PlanEntry {
  final String label;
  final double qty;
  final double priceMin;
  final double priceMax;
  final int dateCount;

  const _PlanEntry({
    required this.label,
    required this.qty,
    required this.priceMin,
    required this.priceMax,
    this.dateCount = 1,
  });
}

/// A breakdown entry for a single delivery (no dateCount).
class _DeliveryEntry {
  final String label;
  final double qty;
  final double priceMin;
  final double priceMax;

  const _DeliveryEntry({
    required this.label,
    required this.qty,
    required this.priceMin,
    required this.priceMax,
  });
}

/// Computes min/max duruhaToConsumerPrice across the listings selected for
/// [varieties].  If no listing exists for a variety it is treated as ₱0.
_PriceRange _computePriceRange(
  List<ProduceVariety> varieties,
  Map<String, String?> selectedFormIds,
) {
  if (varieties.isEmpty) return const _PriceRange(0, 0);

  double minP = double.infinity;
  double maxP = -double.infinity;

  for (final v in varieties) {
    final sfid = selectedFormIds[v.name];
    final listing = v.listings.isEmpty
        ? null
        : (sfid != null
              ? (v.listings.where((l) => l.listingId == sfid).firstOrNull ??
                    v.listings.first)
              : v.listings.first);
    final price = listing?.duruhaToConsumerPrice ?? 0.0;
    if (price < minP) minP = price;
    if (price > maxP) maxP = price;
  }

  if (minP == double.infinity) minP = 0;
  if (maxP == -double.infinity) maxP = 0;
  return _PriceRange(minP, maxP);
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class TransactionReviewScreen extends StatefulWidget {
  final String mode;
  final List<Produce> selectedProduce;
  final Map<String, CropSelectionState> cropStates;

  const TransactionReviewScreen({
    super.key,
    required this.mode,
    required this.selectedProduce,
    required this.cropStates,
  });

  @override
  State<TransactionReviewScreen> createState() =>
      _TransactionReviewScreenState();
}

class _TransactionReviewScreenState extends State<TransactionReviewScreen> {
  final _txRepository = TransactionRepository();
  final _produceRepository = ProduceRepository();
  final _noteController = TextEditingController();
  bool _isSubmitting = false;

  List<Produce> _produce = [];
  RealtimeChannel? _realtimeChannel;
  Timer? _debounce;

  // Order-mode specific
  bool _isOrderPriceLocked = false;

  // Price-lock subscription (order mode only)
  final _subRepository = SubscriptionRepository();
  List<PriceLockSubscription> _subscriptions = [];
  PriceLockSubscription? _activeSubscription;
  // Quality subscription
  QualitySubscription? _qualitySubscription;
  bool _isLoadingQuality = true;
  bool _isLoadingSubscription = true;
  bool _isAllCompact = false;

  // CFP subscription (plan mode only)
  ConsumerFuturePlanSubscription? _cfpSubscription;

  TransactionMode get _txMode =>
      widget.mode == 'plan' ? TransactionMode.plan : TransactionMode.order;
  bool get _isPlan => _txMode == TransactionMode.plan;

  @override
  void initState() {
    super.initState();
    _produce = List.from(widget.selectedProduce);
    _fetchQualitySubscription();
    if (!_isPlan) {
      _fetchSubscriptions();
    } else {
      setState(() => _isLoadingSubscription = false);
      _loadCfpSubscription();
    }
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('review_produce_${DateTime.now().millisecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'farmer_offers',
          callback: (_) => _debouncedReloadAll(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'produce_variety_listing',
          callback: (_) => _debouncedReloadAll(),
        )
        .subscribe();
  }

  void _debouncedReloadAll() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      for (final p in List.from(_produce)) {
        _reloadProduce(p.id);
      }
    });
  }

  Future<void> _reloadProduce(String produceId) async {
    try {
      final refreshed = await _produceRepository.fetchProduceByIds([
        produceId,
      ], mode: 'for_consumer');
      if (!mounted || refreshed.isEmpty) return;
      setState(() {
        final idx = _produce.indexWhere((p) => p.id == produceId);
        if (idx != -1) _produce[idx] = refreshed.first;
      });
    } catch (e) {
      debugPrint('⚠️ [REVIEW] Silent reload failed for $produceId: $e');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    _noteController.dispose();
    super.dispose();
  }

  // ─── Subscription loading ─────────────────────────────────────────────────

  Future<void> _loadCfpSubscription() async {
    try {
      final userId = await SessionService.getUserId();
      if (userId == null) return;
      final consumerRow = await Supabase.instance.client
          .from('user_consumers')
          .select('consumer_id')
          .eq('user_id', userId)
          .maybeSingle();
      final consumerId = consumerRow?['consumer_id'] as String?;
      if (consumerId == null) return;
      final response = await Supabase.instance.client
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
      debugPrint('⚠️ [REVIEW-CFP] Failed to load subscription: $e');
    }
  }

  Future<void> _fetchQualitySubscription() async {
    try {
      final consumerId = await SessionService.getRoleId();
      if (consumerId == null) {
        setState(() => _isLoadingQuality = false);
        return;
      }
      final sub = await _subRepository.getActiveQualitySubscription(consumerId);
      if (mounted) {
        setState(() {
          _qualitySubscription = sub;
          _isLoadingQuality = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ [REVIEW-QUALITY] Failed to load quality subscription: $e');
      if (mounted) setState(() => _isLoadingQuality = false);
    }
  }

  Future<void> _fetchSubscriptions() async {
    final consumerId = await SessionService.getRoleId();
    if (consumerId == null) {
      if (mounted) setState(() => _isLoadingSubscription = false);
      return;
    }
    final subs = await _subRepository.getConsumerPriceLockSubscriptions();
    subs.sort((a, b) {
      if (a.status == 'active' && b.status != 'active') return -1;
      if (a.status != 'active' && b.status == 'active') return 1;
      if (a.remainingCredits != b.remainingCredits) {
        return b.remainingCredits.compareTo(a.remainingCredits);
      }
      return b.endsAt.compareTo(a.endsAt);
    });
    if (mounted) {
      setState(() {
        _subscriptions = subs;
        _activeSubscription =
            (subs.isNotEmpty &&
                subs.first.status == 'active' &&
                subs.first.remainingCredits > 0)
            ? subs.first
            : null;
        _isLoadingSubscription = false;
      });
    }
  }

  // ─── Grand total calculations ─────────────────────────────────────────────

  /// Single-delivery estimated total (both modes).
  double get _grandTotal {
    double total = 0;
    for (final produce in _produce) {
      final state = widget.cropStates[produce.id]!;
      final entries = _buildSingleDeliveryBreakdown(produce, state);
      double sub = 0;
      for (final entry in entries) {
        sub += entry.priceMin * entry.qty;
      }
      total += sub;
    }
    return total;
  }

  /// Total across all recurring deliveries — min price estimate (plan only).
  double get _grandTotalAllDeliveries {
    if (!_isPlan) return _grandTotal;
    double total = 0;
    for (final produce in _produce) {
      final state = widget.cropStates[produce.id]!;
      final entries = _buildPlanBreakdown(produce, state);
      for (final e in entries) {
        total += e.priceMin * e.qty * e.dateCount;
      }
    }
    return total;
  }

  /// Total across all recurring deliveries — max price estimate (plan only).
  double get _grandTotalAllDeliveriesMax {
    if (!_isPlan) return _grandTotalMax;
    double total = 0;
    for (final produce in _produce) {
      final state = widget.cropStates[produce.id]!;
      final entries = _buildPlanBreakdown(produce, state);
      for (final e in entries) {
        total += e.priceMax * e.qty * e.dateCount;
      }
    }
    return total;
  }

  /// Max estimated total for Order mode.
  double get _grandTotalMax {
    double total = 0;
    for (final produce in _produce) {
      final state = widget.cropStates[produce.id]!;
      final entries = _buildSingleDeliveryBreakdown(produce, state);
      double sub = 0;
      for (final entry in entries) {
        sub += entry.priceMax * entry.qty;
      }
      total += sub;
    }
    return total;
  }

  /// Builds quantity map: varietyName → qty (for non-plan breakdowns).
  Map<String, double> _buildVarietyBreakdown(CropSelectionState state) {
    final map = <String, double>{};
    state.varietyQuantityControllers.forEach((k, c) {
      final qty = double.tryParse(c.text) ?? 0;
      if (qty > 0) map[k] = qty;
    });
    return map;
  }

  /// Builds plan breakdown entries, grouping grouped varieties under one entry
  /// per group (min/max across members) to avoid double-counting.
  List<_PlanEntry> _buildPlanBreakdown(
    Produce produce,
    CropSelectionState state,
  ) {
    final entries = <_PlanEntry>[];
    final groupedVarieties = state.varietyGroups.expand((g) => g).toSet();

    // ── Ungrouped varieties ───────────────────────────────────────────────────
    for (final variant in state.selectedVariants) {
      if (groupedVarieties.contains(variant)) continue;
      final ctrl = state.varietyQuantityControllers[variant];
      final qty = double.tryParse(ctrl?.text ?? '') ?? 0;
      if (qty <= 0) continue;

      final price = _resolvePrice(produce, state, variant);
      final dateCount = _recurrenceDatesCount(state, variant);
      entries.add(
        _PlanEntry(
          label: variant,
          qty: qty,
          priceMin: price.min,
          priceMax: price.max,
          dateCount: dateCount,
        ),
      );
    }

    // ── Groups: one entry per group, min/max across all members ───────────────
    for (int i = 0; i < state.varietyGroups.length; i++) {
      final group = state.varietyGroups[i];
      if (group.isEmpty) continue;

      // Qty from first member (all share the same qty after the fix)
      final firstMember = group.first;
      final ctrl = state.varietyQuantityControllers[firstMember];
      final qty = double.tryParse(ctrl?.text ?? '') ?? 0;
      if (qty <= 0) continue;

      final price = _resolvePrice(produce, state, 'group_$i');
      final dateCount = _recurrenceDatesCount(state, 'group_$i');
      entries.add(
        _PlanEntry(
          label: 'Group ${i + 1}',
          qty: qty,
          priceMin: price.min,
          priceMax: price.max,
          dateCount: dateCount,
        ),
      );
    }

    return entries;
  }

  /// Builds a breakdown for a single delivery, respecting groups.
  List<_DeliveryEntry> _buildSingleDeliveryBreakdown(
    Produce produce,
    CropSelectionState state,
  ) {
    final entries = <_DeliveryEntry>[];
    final qtys = _buildVarietyBreakdown(state);
    final groupedVarieties = state.varietyGroups.expand((g) => g).toSet();

    // 1. Ungrouped
    for (final variant in state.selectedVariants) {
      if (groupedVarieties.contains(variant)) continue;
      final qty = qtys[variant] ?? 0;
      if (qty <= 0) continue;

      final price = _resolvePrice(produce, state, variant);
      entries.add(
        _DeliveryEntry(
          label: variant,
          qty: qty,
          priceMin: price.min,
          priceMax: price.max,
        ),
      );
    }

    // 2. Groups
    for (int i = 0; i < state.varietyGroups.length; i++) {
      final group = state.varietyGroups[i];
      if (group.isEmpty) continue;

      // Check if any member has a quantity assigned
      final membersWithQty = group.where((m) => (qtys[m] ?? 0) > 0).toList();
      if (membersWithQty.isEmpty) continue;

      // Use the first member's quantity (after fix, all group members share one quantity)
      final qty = qtys[membersWithQty.first]!;
      final price = _resolvePrice(produce, state, 'group_$i');

      entries.add(
        _DeliveryEntry(
          label: 'Group ${i + 1}',
          qty: qty,
          priceMin: price.min,
          priceMax: price.max,
        ),
      );
    }

    return entries;
  }

  /// Resolves the price range for a variety key (supports groups and "Any").
  _PriceRange _resolvePrice(
    Produce produce,
    CropSelectionState state,
    String key,
  ) {
    List<ProduceVariety> targets = [];

    if (key.startsWith('group_')) {
      final idx = int.tryParse(key.replaceFirst('group_', ''));
      if (idx != null && idx < state.varietyGroups.length) {
        final names = state.varietyGroups[idx];
        targets = produce.varieties
            .where((v) => names.contains(v.name))
            .toList();
      }
    } else if (key.toLowerCase() == 'any') {
      targets = produce.varieties;
    } else {
      final v = produce.varieties.firstWhere(
        (v) => v.name == key,
        orElse: () => produce.varieties.first,
      );
      targets = [v];
    }

    return _computePriceRange(targets, state.varietySelectedFormId);
  }

  /// Returns the number of scheduled dates for a variety key in plan mode.
  int _recurrenceDatesCount(CropSelectionState state, String key) {
    String? recStr =
        state.varietyRecurrence[key] ?? state.varietyRecurrence['qty_$key'];
    if (recStr == null || recStr.isEmpty) {
      for (int i = 0; i < state.varietyGroups.length; i++) {
        if (state.varietyGroups[i].contains(key)) {
          final groupKey = 'group_$i';
          recStr =
              state.varietyRecurrence[groupKey] ??
              state.varietyRecurrence['qty_$groupKey'];
          break;
        }
      }
    }
    if (recStr == null || recStr.isEmpty) return 1;
    return RecurringPickerUtil.computeDates(recStr).length;
  }

  // ─── Plan mode validation ─────────────────────────────────────────────────

  /// True when the grand total (min) is below the subscription minimum.
  bool get _planBelowMin {
    if (!_isPlan) return false;
    final min = _cfpSubscription?.minTotalValue;
    if (min == null || min <= 0) return false;
    return _grandTotalAllDeliveries < min;
  }

  /// True when the grand total (max) exceeds the subscription maximum.
  bool get _planAboveMax {
    if (!_isPlan) return false;
    final max = _cfpSubscription?.maxTotalValue;
    if (max == null || max <= 0) return false;
    return _grandTotalAllDeliveriesMax > max;
  }

  /// True when any scheduled delivery date falls outside the subscription window.
  bool get _planDatesOutOfRange {
    if (!_isPlan || _cfpSubscription == null) return false;
    final start = _cfpSubscription!.startsAt;
    final end = _cfpSubscription!.expiresAt;
    for (final produce in _produce) {
      final state = widget.cropStates[produce.id]!;
      for (final recStr in state.varietyRecurrence.values) {
        if (recStr == null || recStr.isEmpty) continue;
        final dates = RecurringPickerUtil.computeDates(recStr);
        for (final d in dates) {
          final day = DateTime(d.year, d.month, d.day);
          if (day.isBefore(DateTime(start.year, start.month, start.day)) ||
              day.isAfter(DateTime(end.year, end.month, end.day))) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// True when the plan is invalid and confirm should be disabled.
  bool get _isPlanInvalid =>
      _isPlan && (_planBelowMin || _planAboveMax || _planDatesOutOfRange);

  // ─── Price-lock credit calculations ──────────────────────────────────────

  bool get _isOverLimit {
    // Check plan mode credit limits
    if (_isPlan && _activeSubscription != null) {
      final totalLocked = _calculateTotalLockedCredits();
      final totalUnlocked = _calculateTotalUnlockedCredits();
      final newRemaining = _activeSubscription!.remainingCredits - totalLocked;
      return newRemaining < 0;
    }

    // Check order mode price lock limits
    if (!_isPlan && _isOrderPriceLocked && _activeSubscription != null) {
      final orderTotal = _grandTotalMax;
      return _activeSubscription!.remainingCredits < orderTotal;
    }

    return false;
  }

  double _calculateTotalLockedCredits() {
    if (_activeSubscription == null) return 0;
    double total = 0;
    for (final produce in _produce) {
      final state = widget.cropStates[produce.id]!;
      final qtys = _buildVarietyBreakdown(state);
      final groupedVarieties = state.varietyGroups.expand((g) => g).toSet();

      // Ungrouped
      for (final variant in state.selectedVariants) {
        if (groupedVarieties.contains(variant)) continue;
        if (state.varietyPriceLock[variant] != true) continue;
        final qty = qtys[variant] ?? 0;
        if (qty <= 0) continue;
        final price = _resolvePrice(produce, state, variant);
        total += price.max * qty;
      }

      // Groups
      for (int i = 0; i < state.varietyGroups.length; i++) {
        final group = state.varietyGroups[i];
        if (group.isEmpty) continue;
        // If ANY member of the group is locked, the whole group quantity is considered locked
        bool isLocked = group.any((m) => state.varietyPriceLock[m] == true);
        if (!isLocked) continue;

        final membersWithQty = group.where((m) => (qtys[m] ?? 0) > 0).toList();
        if (membersWithQty.isEmpty) continue;

        final qty = qtys[membersWithQty.first]!;
        final price = _resolvePrice(produce, state, 'group_$i');
        total += price.max * qty;
      }
    }
    return total;
  }

  double _calculateTotalUnlockedCredits() {
    double total = 0;
    for (final produce in _produce) {
      final state = widget.cropStates[produce.id]!;
      final qtys = _buildVarietyBreakdown(state);
      final groupedVarieties = state.varietyGroups.expand((g) => g).toSet();

      // Ungrouped
      for (final variant in state.selectedVariants) {
        if (groupedVarieties.contains(variant)) continue;
        if (state.varietyPriceLock[variant] == true) continue;
        final qty = qtys[variant] ?? 0;
        if (qty <= 0) continue;
        final price = _resolvePrice(produce, state, variant);
        total += price.min * qty;
      }

      // Groups
      for (int i = 0; i < state.varietyGroups.length; i++) {
        final group = state.varietyGroups[i];
        if (group.isEmpty) continue;
        // Group is unlocked ONLY if no member is locked
        bool isLocked = group.any((m) => state.varietyPriceLock[m] == true);
        if (isLocked) continue;

        final membersWithQty = group.where((m) => (qtys[m] ?? 0) > 0).toList();
        if (membersWithQty.isEmpty) continue;

        final qty = qtys[membersWithQty.first]!;
        final price = _resolvePrice(produce, state, 'group_$i');
        total += price.min * qty;
      }
    }
    return total;
  }

  // ─── Submission ───────────────────────────────────────────────────────────

  Future<void> _submitAll() async {
    if (_isPlan) {
      await _submitPlan();
    } else {
      await _submitOrder();
    }
  }

  Future<void> _submitOrder() async {
    setState(() => _isSubmitting = true);
    HapticFeedback.heavyImpact();

    try {
      final Map<String, Map<String, double>> cropQuantities = {};
      final Map<String, Map<String, DateTime?>> cropVarietyDateNeeded = {};
      final Map<String, Map<String, String?>> cropFormSelections = {};
      final Map<String, Map<String, bool>> cropPriceLocks = {};
      final Map<String, List<Set<String>>> varietyGroups = {};
      final Map<String, String> cropQualities = {};

      for (final produce in _produce) {
        final state = widget.cropStates[produce.id]!;

        final quantities = <String, double>{};
        for (final entry in state.varietyQuantityControllers.entries) {
          final q = double.tryParse(entry.value.text) ?? 0;
          if (q > 0) quantities[entry.key] = q;
        }

        cropQuantities[produce.id] = quantities;
        cropVarietyDateNeeded[produce.id] = state.varietyDateNeeded;
        varietyGroups[produce.id] = state.varietyGroups;
        cropQualities[produce.id] =
            _qualitySubscription?.tierName ?? 'Selection';

        // Convert listing IDs → form names
        final formNames = <String, String?>{};
        for (final entry in state.varietySelectedFormId.entries) {
          final vName = entry.key;
          final sfid = entry.value;
          if (sfid == null) {
            formNames[vName] = null;
            continue;
          }
          if (vName == 'Any') {
            formNames[vName] = sfid;
          } else {
            final variety = produce.varieties.firstWhere(
              (v) => v.name == vName,
              orElse: () => produce.varieties.first,
            );
            final listing = variety.listings.firstWhere(
              (l) => l.listingId == sfid,
              orElse: () => variety.listings.first,
            );
            formNames[vName] = listing.produceForm;
          }
        }
        cropFormSelections[produce.id] = formNames;

        cropPriceLocks[produce.id] = {};
      }

      // Prepare price lock subscription if locked
      final cplsIdToUse = (_isOrderPriceLocked && _activeSubscription != null)
          ? _activeSubscription!.cplsId
          : null;

      if (supabase.auth.currentUser == null) {
        throw Exception('You must be logged in to create an order.');
      }

      final result = await _txRepository.txCreateOrder(
        selectedProduce: _produce,
        cropQuantities: cropQuantities,
        cropQualities: cropQualities,
        varietyDateNeeded: cropVarietyDateNeeded,
        varietyGroups: varietyGroups,
        varietySelectedFormId: cropFormSelections,
        varietyPriceLock: cropPriceLocks,
        note: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : null,
        cplsId: cplsIdToUse,
      );

      if (result == null) {
        throw Exception('Order could not be completed. Please try again.');
      }

      await TransactionDraftService.clearAllForMode(TransactionMode.order);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OrderDetailsScreen(
              orderId: result.placeOrderResult.orderId,
              action: 'new',
              placeOrderResult: result.placeOrderResult,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        DuruhaSnackBar.showError(context, 'Order failed: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitPlan() async {
    setState(() => _isSubmitting = true);
    HapticFeedback.heavyImpact();

    try {
      final Map<String, Map<String, double>> cropQuantities = {};
      final Map<String, Map<String, String?>> cropRecurrences = {};
      final Map<String, List<Set<String>>> varietyGroups = {};
      final Map<String, Map<String, String?>> cropFormSelections = {};
      final Map<String, String> cropQualities = {};
      final Map<String, Map<String, bool>> cropPriceLocks = {};

      for (final produce in _produce) {
        final state = widget.cropStates[produce.id]!;

        cropPriceLocks[produce.id] = {};

        final quantities = <String, double>{};
        for (final entry in state.varietyQuantityControllers.entries) {
          final q = double.tryParse(entry.value.text) ?? 0;
          if (q > 0) quantities[entry.key] = q;
        }

        cropQuantities[produce.id] = quantities;
        cropRecurrences[produce.id] = state.varietyRecurrence;
        varietyGroups[produce.id] = state.varietyGroups;
        cropQualities[produce.id] = _qualitySubscription?.tierName ?? 'Saver';

        final formNames = <String, String?>{};
        for (final entry in state.varietySelectedFormId.entries) {
          final vName = entry.key;
          final sfid = entry.value;
          if (sfid == null) {
            formNames[vName] = null;
            continue;
          }
          if (vName == 'Any') {
            formNames[vName] = sfid;
          } else {
            final variety = produce.varieties.firstWhere(
              (v) => v.name == vName,
              orElse: () => produce.varieties.first,
            );
            final listing = variety.listings.firstWhere(
              (l) => l.listingId == sfid,
              orElse: () => variety.listings.first,
            );
            formNames[vName] = listing.produceForm;
          }
        }
        cropFormSelections[produce.id] = formNames;
      }

      final orderId = await _txRepository.txCreatePlan(
        selectedProduce: _produce,
        cropQuantities: cropQuantities,
        cropQualities: cropQualities,
        cropVarietyRecurrence: cropRecurrences,
        varietyGroups: varietyGroups,
        varietySelectedFormId: cropFormSelections,
        note: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : null,
      );

      if (orderId == null) {
        throw Exception('Plan could not be created. Please try again.');
      }

      await TransactionDraftService.clearAllForMode(TransactionMode.plan);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => OrderDetailsScreen(orderId: orderId, action: 'new'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        DuruhaSnackBar.showError(context, 'Plan failed: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DuruhaScaffold(
      appBarTitle: _isPlan ? 'Review Plan' : 'Review Order',
      appBarActions: [
        IconButton(
          icon: Icon(_isAllCompact ? Icons.unfold_more : Icons.unfold_less),
          onPressed: () => setState(() => _isAllCompact = !_isAllCompact),
          tooltip: _isAllCompact ? 'Expand All' : 'Collapse All',
        ),
        IconButton(
          icon: const Icon(Icons.help_outline_rounded),
          tooltip: 'Pricing FAQ',
          onPressed: () => TransactionReviewFaq.show(context),
        ),
      ],
      body: Stack(
        children: [
          (_isLoadingSubscription || _isLoadingQuality)
              ? const ConsumerLoadingScreen()
              : CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // Mode indicator banner
                          _buildModeBanner(theme),
                          const SizedBox(height: 12),

                          // Quality subscription banner
                          _buildQualitySubscriptionBanner(theme),
                          const SizedBox(height: 16),

                          // Grand total card
                          _buildGrandTotalCard(theme),
                          const SizedBox(height: 20),

                          DuruhaTextField(
                            label: 'Order Notes',
                            icon: Icons.notes_rounded,
                            controller: _noteController,
                            maxLines: 2,
                            isRequired: false,
                          ),
                          const SizedBox(height: 24),
                        ]),
                      ),
                    ),

                    // Produce Cards
                    ..._produce.map((produce) {
                      final state = widget.cropStates[produce.id]!;
                      return DuruhaSectionSliver(
                        compactOverride: _isAllCompact,
                        headerPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        contentPadding: const EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          24,
                        ),
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
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
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
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                ),
                              )
                            : null,
                        content: _buildReviewCard(theme, produce, state),
                      );
                    }),

                    const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
                  ],
                ),
          _buildSubmitBar(theme),
        ],
      ),
    );
  }

  Widget _buildModeBanner(ThemeData theme) {
    final isOrder = !_isPlan;

    // ── Plan mode with CFP subscription ──────────────────────────────────────
    if (_isPlan && _cfpSubscription != null) {
      final sub = _cfpSubscription!;
      final color = theme.colorScheme.secondaryContainer;
      final onColor = theme.colorScheme.onSecondaryContainer;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_repeat_rounded, size: 18, color: onColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sub.planName ?? 'Consumer Future Plan',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: onColor,
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
              sub.formattedValueRange ?? 'No limit set',
              onColor,
            ),
            _cfpInfoRow(
              theme,
              Icons.date_range_outlined,
              'Schedule window',
              '${DateFormat('MMM d').format(sub.startsAt)} – '
                  '${DateFormat('MMM d, yyyy').format(sub.expiresAt)}',
              onColor,
            ),
            // ── Validation warnings ───────────────────────────────────────
            if (_planBelowMin || _planAboveMax || _planDatesOutOfRange) ...[
              const SizedBox(height: 8),
              Divider(height: 1, color: onColor.withValues(alpha: 0.2)),
              const SizedBox(height: 8),
              if (_planBelowMin)
                _cfpWarningRow(
                  theme,
                  Icons.arrow_downward_rounded,
                  'Total is below the minimum plan value '
                  '(${DuruhaFormatter.formatCurrency(sub.minTotalValue!)}). '
                  'Please add more items.',
                  onColor,
                ),
              if (_planAboveMax)
                _cfpWarningRow(
                  theme,
                  Icons.arrow_upward_rounded,
                  'Total exceeds the maximum plan value '
                  '(${DuruhaFormatter.formatCurrency(sub.maxTotalValue!)}). '
                  'Please reduce quantities.',
                  onColor,
                ),
              if (_planDatesOutOfRange)
                _cfpWarningRow(
                  theme,
                  Icons.calendar_month_outlined,
                  'Some scheduled dates fall outside your plan window '
                  '(${DateFormat('MMM d').format(sub.startsAt)} – '
                  '${DateFormat('MMM d, yyyy').format(sub.expiresAt)}). '
                  'Please adjust the recurring schedule.',
                  onColor,
                ),
            ],
          ],
        ),
      );
    }

    // ── Fallback (order mode or plan without subscription) ────────────────────
    final color = isOrder
        ? theme.colorScheme.tertiaryContainer
        : theme.colorScheme.secondaryContainer;
    final onColor = isOrder
        ? theme.colorScheme.onTertiaryContainer
        : theme.colorScheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isOrder ? Icons.shopping_bag_outlined : Icons.repeat_rounded,
            size: 18,
            color: onColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isOrder
                  ? 'Order Mode — This is a one-time purchase. Prices shown are '
                        'based on current listings.'
                  : 'Plan Mode — Recurring deliveries scheduled. '
                        'Prices shown are based on current listings; actual price depends on '
                        'the farmer\'s listing at fulfillment time.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: onColor,
                fontWeight: FontWeight.w500,
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
              color: color.withValues(alpha: 0.75),
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

  Widget _cfpWarningRow(
    ThemeData theme,
    IconData icon,
    String message,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrandTotalCard(ThemeData theme) {
    final showRange = _grandTotal.abs() < _grandTotalMax.abs() - 0.01;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.tertiaryContainer.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.tertiary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isPlan ? 'Total All Deliveries' : 'Order Total',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onTertiary.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Builder(
            builder: (context) {
              if (_isPlan) {
                final minTotal = _grandTotalAllDeliveries;
                final maxTotal = _grandTotalAllDeliveriesMax;
                final showPlanRange = (maxTotal - minTotal).abs() > 0.01;
                return Column(
                  children: [
                    Text(
                      showPlanRange
                          ? '${DuruhaFormatter.formatCurrency(minTotal)} – ${DuruhaFormatter.formatCurrency(maxTotal)}'
                          : DuruhaFormatter.formatCurrency(minTotal),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.onTertiary,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (showPlanRange)
                      Text(
                        'Price range based on active farmer listings',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onTertiary.withValues(
                            alpha: 0.7,
                          ),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                );
              }
              return Column(
                children: [
                  Text(
                    showRange
                        ? '${DuruhaFormatter.formatCurrency(_grandTotal)} – '
                              '${DuruhaFormatter.formatCurrency(_grandTotalMax)}'
                        : DuruhaFormatter.formatCurrency(_grandTotal),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.onTertiary,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (showRange)
                    Text(
                      'Price range based on active farmer listings',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onTertiary.withValues(
                          alpha: 0.7,
                        ),
                        fontStyle: FontStyle.italic,
                      ),
                    ),

                  // Price Lock Selection (Order Mode Only)
                  if (!_isPlan) ...[
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _showPriceLockSelectionDialog,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isOrderPriceLocked
                                ? theme.colorScheme.tertiary
                                : theme.colorScheme.outlineVariant.withValues(
                                    alpha: 0.3,
                                  ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isOrderPriceLocked
                                  ? Icons.lock_rounded
                                  : Icons.lock_open_rounded,
                              size: 20,
                              color: _isOrderPriceLocked
                                  ? theme.colorScheme.tertiary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Price Lock Status',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    !_isOrderPriceLocked
                                        ? 'Disabled'
                                        : (_activeSubscription?.planName ??
                                              'Active Subscription'),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: _isOrderPriceLocked
                                          ? theme.colorScheme.tertiary
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _showPriceLockSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Price Lock Subscription'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // None / Disable option
                ListTile(
                  leading: Icon(
                    !_isOrderPriceLocked
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text('None / Disable'),
                  subtitle: const Text('Turn off price lock for this order'),
                  onTap: () {
                    setState(() {
                      _isOrderPriceLocked = false;
                      _activeSubscription = null;
                    });
                    Navigator.pop(context);
                  },
                ),
                const Divider(),
                if (_subscriptions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No active subscriptions found.'),
                  )
                else
                  ..._subscriptions.map((sub) {
                    final isActive = _activeSubscription?.cplsId == sub.cplsId;
                    return ListTile(
                      leading: Icon(
                        isActive
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: theme.colorScheme.tertiary,
                      ),
                      title: Text(sub.planName),
                      subtitle: Text(
                        '${sub.remainingCredits.toStringAsFixed(0)} credits remaining',
                      ),
                      onTap: () {
                        setState(() {
                          _isOrderPriceLocked = true;
                          _activeSubscription = sub;
                        });
                        Navigator.pop(context);
                      },
                    );
                  }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubmitBar(ThemeData theme) {
    final isDisabled = _isSubmitting || _isOverLimit || _isPlanInvalid;

    String buttonLabel;
    if (_isSubmitting) {
      buttonLabel = 'Submitting…';
    } else if (_isPlan && _planBelowMin) {
      buttonLabel = 'Total below minimum';
    } else if (_isPlan && _planAboveMax) {
      buttonLabel = 'Total exceeds maximum';
    } else if (_isPlan && _planDatesOutOfRange) {
      buttonLabel = 'Dates out of plan window';
    } else {
      buttonLabel = _isPlan ? 'Confirm Plan' : 'Confirm Order';
    }

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: DuruhaButton(
          icon: _isSubmitting ? null : const Icon(Icons.check_outlined),
          isLoading: _isSubmitting,
          backgroundColor: isDisabled
              ? theme.colorScheme.secondary
              : theme.colorScheme.tertiaryContainer,
          text: buttonLabel,
          onPressed: isDisabled ? null : _submitAll,
        ),
      ),
    );
  }

  // ─── Review Card ──────────────────────────────────────────────────────────

  Widget _buildReviewCard(
    ThemeData theme,
    Produce produce,
    CropSelectionState state,
  ) {
    final breakdown = _buildVarietyBreakdown(state);
    final entries = _buildSingleDeliveryBreakdown(produce, state);
    double subtotal = 0;
    for (final e in entries) {
      subtotal += e.priceMin * e.qty;
    }
    final totalAmt = subtotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Recurring schedules (plan only)
        if (_isPlan && state.varietyRecurrence.isNotEmpty)
          _buildRecurringSection(theme, produce, state),

        // Variety breakdown
        if (breakdown.isNotEmpty) ...[
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              'By Variety',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Column(
              children: _buildVarietyRows(theme, produce, state, breakdown),
            ),
          ),
        ],

        // Pricing summary
        Divider(
          height: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: _buildPricingSummary(
            theme,
            produce,
            state,
            subtotal,
            totalAmt,
          ),
        ),
      ],
    );
  }

  Widget _buildRecurringSection(
    ThemeData theme,
    Produce produce,
    CropSelectionState state,
  ) {
    // Build entries in the same order as By Variety:
    // groups first (by group index), then ungrouped in produce variety order.
    final allRecurrence = state.varietyRecurrence;

    // Collect group entries in index order
    final orderedEntries = <MapEntry<String, String?>>[];
    for (int gi = 0; gi < state.varietyGroups.length; gi++) {
      final groupKey = 'group_$gi';
      if (allRecurrence.containsKey(groupKey) &&
          (allRecurrence[groupKey] ?? '').isNotEmpty) {
        orderedEntries.add(MapEntry(groupKey, allRecurrence[groupKey]));
      }
    }

    // Collect ungrouped variety keys in produce order ('any' treated specially)
    // First collect variety names in produce order
    final producedOrderedNames = <String>[];
    for (final v in produce.varieties) {
      producedOrderedNames.add(v.name);
    }
    // Also add 'any' if present (it's a pseudo-variety)
    if (allRecurrence.keys.any((k) => k == 'qty_any' || k == 'qty_Any')) {
      producedOrderedNames.add('Any');
    }

    for (final name in producedOrderedNames) {
      final qtyKey = 'qty_$name';
      if (allRecurrence.containsKey(qtyKey) &&
          (allRecurrence[qtyKey] ?? '').isNotEmpty) {
        // Exclude if this variety is already covered by a group
        final inGroup = state.varietyGroups.any((g) => g.contains(name));
        if (!inGroup) {
          orderedEntries.add(MapEntry(qtyKey, allRecurrence[qtyKey]));
        }
      }
    }

    final entries = orderedEntries;
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
          height: 1,
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Text(
            'Recurring Schedules',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.4,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: entries.map((e) {
              final rawKey = e.key.startsWith('qty_')
                  ? e.key.replaceFirst('qty_', '')
                  : e.key;
              final isGroup = rawKey.startsWith('group_');
              final gIdx = isGroup
                  ? int.tryParse(rawKey.replaceFirst('group_', ''))
                  : null;
              final groupMembers =
                  isGroup && gIdx != null && gIdx < state.varietyGroups.length
                  ? state.varietyGroups[gIdx].toList()
                  : <String>[];

              final decoded = RecurringPickerUtil.decode(e.value!);
              final humanLabel = RecurringPickerUtil.toLabel(e.value!);
              final dates = RecurringPickerUtil.computeDates(e.value!);
              final fmt = DateFormat('MMM d');
              final rangeText =
                  (decoded.startDate != null && decoded.endDate != null)
                  ? '${fmt.format(decoded.startDate!)} – ${fmt.format(decoded.endDate!)}, ${dates.length} dates'
                  : '${dates.length} dates';

              // ─── Helper: resolve form string for a single variety key ───
              String? resolveForm(String key, ProduceVariety v) {
                if (key.toLowerCase() == 'any') {
                  final sfid = state.varietySelectedFormId[key];
                  if (sfid != null && sfid.isNotEmpty) return sfid;
                  return 'Any Form';
                }
                final sfid = state.varietySelectedFormId[key];
                if (sfid != null) {
                  return v.listings
                      .firstWhere(
                        (l) => l.listingId == sfid,
                        orElse: () => v.listings.first,
                      )
                      .produceForm;
                }
                return v.listings.isNotEmpty
                    ? v.listings.first.produceForm
                    : null;
              }

              if (isGroup) {
                // ─── GROUP CARD ─────────────────────────────────────────
                // Resolve form from first member
                String? groupFormStr;
                if (groupMembers.isNotEmpty) {
                  final firstV = produce.varieties.firstWhere(
                    (v) => v.name == groupMembers.first,
                    orElse: () => produce.varieties.first,
                  );
                  groupFormStr = resolveForm(groupMembers.first, firstV);
                }

                final color = _getEntryColor(produce, state, rawKey);

                return _withLeftBorder(
                  theme: theme,
                  color: color,
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Group header ──
                      Row(
                        children: [
                          Icon(
                            Icons.link_rounded,
                            size: 16,
                            color: theme.colorScheme.onPrimary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            groupFormStr != null
                                ? 'Any of: $groupFormStr'
                                : 'Any of:',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onTertiary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // ── Member rows ──
                      ...groupMembers.map((member) {
                        final isAnyMember = member.toLowerCase() == 'any';
                        final memTargets = isAnyMember
                            ? produce.varieties
                            : produce.varieties
                                  .where((v) => v.name == member)
                                  .toList();
                        final vTarget = memTargets.isNotEmpty
                            ? memTargets.first
                            : produce.varieties.first;
                        final memForm = resolveForm(member, vTarget);
                        final memPriceRange = _computePriceRange(
                          memTargets,
                          state.varietySelectedFormId,
                        );
                        final memQty =
                            double.tryParse(
                              state.varietyQuantityControllers[member]?.text ??
                                  '',
                            ) ??
                            0;
                        final memTotalMin =
                            memPriceRange.min * memQty * dates.length;
                        final memTotalMax =
                            memPriceRange.max * memQty * dates.length;
                        final memHasCost = memPriceRange.max > 0 && memQty > 0;

                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      member,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    if (memForm != null && memForm.isNotEmpty)
                                      Text(
                                        memForm,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color:
                                                  theme.colorScheme.onTertiary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 9,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                              if (memHasCost)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      memPriceRange.isSingle
                                          ? DuruhaFormatter.formatCurrency(
                                              memTotalMin,
                                            )
                                          : '${DuruhaFormatter.formatCurrency(memTotalMin)}–${DuruhaFormatter.formatCurrency(memTotalMax)}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    Text(
                                      '${memPriceRange.label} × ${memQty.toStringAsFixed(0)} × ${dates.length}',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontSize: 9,
                                          ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      }),
                      // ── Recurring footer ──
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.repeat_rounded,
                            size: 12,
                            color: theme.colorScheme.onPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            humanLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              rangeText,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              } else {
                // ─── SINGLE ITEM CARD ────────────────────────────────────
                final isAnyKey = rawKey.toLowerCase() == 'any';
                final singleTargets = isAnyKey
                    ? produce.varieties
                    : produce.varieties.where((v) => v.name == rawKey).toList();
                final v = singleTargets.isNotEmpty
                    ? singleTargets.first
                    : produce.varieties.first;
                final formStr = resolveForm(rawKey, v);
                final priceRange = _computePriceRange(
                  singleTargets,
                  state.varietySelectedFormId,
                );
                final qty =
                    double.tryParse(
                      state.varietyQuantityControllers[rawKey]?.text ?? '',
                    ) ??
                    0;
                final totalMin = priceRange.min * qty * dates.length;
                final totalMax = priceRange.max * qty * dates.length;
                final hasCost = priceRange.max > 0 && qty > 0;

                final color = _getEntryColor(produce, state, rawKey);

                return _withLeftBorder(
                  theme: theme,
                  color: color,
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rawKey,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (formStr != null && formStr.isNotEmpty)
                                  Text(
                                    formStr,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onTertiary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (hasCost)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  priceRange.isSingle
                                      ? DuruhaFormatter.formatCurrency(totalMin)
                                      : '${DuruhaFormatter.formatCurrency(totalMin)}–${DuruhaFormatter.formatCurrency(totalMax)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${priceRange.label} × ${qty.toStringAsFixed(0)} × ${dates.length}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      // ── Recurring footer ──
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.repeat_rounded,
                            size: 12,
                            color: theme.colorScheme.onPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            humanLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              rangeText,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ─── Shared Border Helper ──────────────────────────────────────────────────

  Color _getEntryColor(Produce produce, CropSelectionState state, String key) {
    final activeKeys = <String>[];

    // 1. Groups
    for (int gi = 0; gi < state.varietyGroups.length; gi++) {
      final grpKey = 'group_$gi';
      final hasRec =
          state.varietyRecurrence[grpKey]?.isNotEmpty == true ||
          state.varietyRecurrence['qty_$grpKey']?.isNotEmpty == true;
      bool hasQty = false;
      if (state.varietyGroups[gi].isNotEmpty) {
        final firstVar = state.varietyGroups[gi].first;
        final qtyCtrl = state.varietyQuantityControllers[firstVar];
        if ((double.tryParse(qtyCtrl?.text ?? '') ?? 0) > 0) hasQty = true;
      }
      if (hasRec || hasQty) {
        activeKeys.add(grpKey);
      }
    }

    // 2. Ungrouped Varieties
    final groupedVarieties = state.varietyGroups.expand((g) => g).toSet();
    final allPossible = [...produce.varieties.map((v) => v.name), 'Any'];
    for (final vName in allPossible) {
      if (groupedVarieties.contains(vName)) continue;

      final hasRec =
          state.varietyRecurrence[vName]?.isNotEmpty == true ||
          state.varietyRecurrence['qty_$vName']?.isNotEmpty == true;
      final qtyCtrl = state.varietyQuantityControllers[vName];
      final hasQty = (double.tryParse(qtyCtrl?.text ?? '') ?? 0) > 0;

      if (hasRec || hasQty) {
        activeKeys.add(vName);
      }
    }

    int idx = activeKeys.indexOf(key);
    if (idx < 0) idx = activeKeys.length; // fallback

    return colorMarker[idx % colorMarker.length];
  }

  Widget _withLeftBorder({
    required Widget child,
    required Color color,
    required ThemeData theme,
    EdgeInsetsGeometry? padding,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 6,
            child: ColoredBox(color: color),
          ),
          Padding(
            padding: padding ?? const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: child,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildVarietyRows(
    ThemeData theme,
    Produce produce,
    CropSelectionState state,
    Map<String, double> breakdown,
  ) {
    final rows = <Widget>[];

    if (!_isPlan) {
      // ORDER MODE: groups first, then ungrouped
      // Helper: resolve form string for order mode
      String? resolveFormOrder(String key, List<ProduceVariety> targets) {
        if (key.toLowerCase() == 'any') {
          final sfid = state.varietySelectedFormId[key];
          if (sfid != null && sfid.isNotEmpty) return sfid;
          return 'Any Form';
        }
        final v = targets.isNotEmpty ? targets.first : null;
        if (v == null) return null;
        final sfid = state.varietySelectedFormId[key];
        if (sfid != null) {
          return v.listings
              .firstWhere(
                (l) => l.listingId == sfid,
                orElse: () => v.listings.first,
              )
              .produceForm;
        }
        return v.listings.isNotEmpty ? v.listings.first.produceForm : null;
      }

      for (final group in state.varietyGroups) {
        final selected = group.where((v) => breakdown.containsKey(v)).toList();
        if (selected.isEmpty) continue;

        final dDate = state.varietyDateNeeded[selected.first];
        final groupKey = 'group_${state.varietyGroups.indexOf(group)}';

        // Group form from first member
        String? groupFormStr;
        if (selected.isNotEmpty) {
          final firstV = produce.varieties.firstWhere(
            (v) => v.name == selected.first,
            orElse: () => produce.varieties.first,
          );
          groupFormStr = resolveFormOrder(selected.first, [firstV]);
        }

        final groupQty = breakdown[selected.first] ?? 0.0;

        final memberRows = selected.map((key) {
          final isAny = key.toLowerCase() == 'any';
          final targets = isAny
              ? produce.varieties
              : produce.varieties.where((v) => v.name == key).toList();
          final memPriceRange = _computePriceRange(
            targets,
            state.varietySelectedFormId,
          );
          final memQty = groupQty;
          final memTotalMin = memPriceRange.min * memQty;
          final memTotalMax = memPriceRange.max * memQty;

          final memForm = resolveFormOrder(key, targets);

          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        key,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (memForm != null && memForm.isNotEmpty)
                        Text(
                          memForm,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onTertiary,
                            fontWeight: FontWeight.w600,
                            fontSize: 9,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      memPriceRange.isSingle
                          ? DuruhaFormatter.formatCurrency(memTotalMin)
                          : '${DuruhaFormatter.formatCurrency(memTotalMin)}–${DuruhaFormatter.formatCurrency(memTotalMax)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${memPriceRange.label} × ${memQty.toStringAsFixed(0)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList();

        final isLocked = state.varietyPriceLock[groupKey] ?? false;
        final color = _getEntryColor(produce, state, groupKey);

        rows.add(
          _withLeftBorder(
            theme: theme,
            color: color,
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.link_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            groupFormStr != null
                                ? 'Any of: $groupFormStr'
                                : 'Any of:',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_isOrderPriceLocked &&
                              _activeSubscription != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.lock_rounded,
                                    size: 10,
                                    color: theme.colorScheme.tertiary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Price Locked',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.tertiary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                ),
                const SizedBox(height: 10),
                ...memberRows,
                if (dDate != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Needed ${DuruhaFormatter.formatDate(dDate)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      }

      for (final entry in breakdown.entries) {
        if (entry.key.startsWith('group_')) continue;
        if (state.varietyGroups.any((g) => g.contains(entry.key))) continue;
        final key = entry.key;
        final isAnyKey = key.toLowerCase() == 'any';
        final targets = isAnyKey
            ? produce.varieties.toList()
            : produce.varieties.where((v) => v.name == key).toList();
        final priceRange = _computePriceRange(
          targets,
          state.varietySelectedFormId,
        );
        final form = resolveFormOrder(key, targets);
        final color = _getEntryColor(produce, state, key);
        rows.add(
          _withLeftBorder(
            theme: theme,
            color: color,
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: _buildVarietyRow(
              theme,
              state,
              key,
              entry.value,
              priceRange: priceRange,
              dateNeeded:
                  state.varietyDateNeeded[key] ??
                  state.varietyDateNeeded['qty_$key'],
              priceLock: _isOrderPriceLocked,
              onPriceLockChanged: null,
              unit: state.selectedUnit,
              form: form,
            ),
          ),
        );
      }
    } else {
      // PLAN MODE: show price ranges, no date_needed, no price lock per-row
      // Helper: resolve form string for a variety
      String? resolveForm(String key, ProduceVariety v) {
        if (key.toLowerCase() == 'any') {
          final sfid = state.varietySelectedFormId[key];
          if (sfid != null && sfid.isNotEmpty) return sfid;
          return 'Any Form';
        }
        final sfid = state.varietySelectedFormId[key];
        if (sfid != null) {
          return v.listings
              .firstWhere(
                (l) => l.listingId == sfid,
                orElse: () => v.listings.first,
              )
              .produceForm;
        }
        return v.listings.isNotEmpty ? v.listings.first.produceForm : null;
      }

      // Grouped items
      for (final group in state.varietyGroups) {
        final selected = group.where((v) => breakdown.containsKey(v)).toList();
        if (selected.isEmpty) continue;

        // Group form from first member
        String? groupFormStr;
        if (selected.isNotEmpty) {
          final firstV = produce.varieties.firstWhere(
            (v) => v.name == selected.first,
            orElse: () => produce.varieties.first,
          );
          groupFormStr = resolveForm(selected.first, firstV);
        }

        final groupQty = breakdown[selected.first] ?? 0.0;

        // Member rows
        final memberRows = selected.map((key) {
          final isAny = key.toLowerCase() == 'any';
          final targets = isAny
              ? produce.varieties
              : produce.varieties.where((v) => v.name == key).toList();
          final memV = targets.isNotEmpty
              ? targets.first
              : produce.varieties.first;
          final memPriceRange = _computePriceRange(
            targets,
            state.varietySelectedFormId,
          );
          final memQty = groupQty;
          final memTotal = memPriceRange.min * memQty;
          final memTotalMax = memPriceRange.max * memQty;
          final memForm = resolveForm(key, memV);

          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        key,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (memForm != null && memForm.isNotEmpty)
                        Text(
                          memForm,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onTertiary,
                            fontWeight: FontWeight.w600,
                            fontSize: 9,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      memPriceRange.isSingle
                          ? DuruhaFormatter.formatCurrency(memTotal)
                          : '${DuruhaFormatter.formatCurrency(memTotal)}–${DuruhaFormatter.formatCurrency(memTotalMax)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${memPriceRange.label} × ${memQty.toStringAsFixed(0)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList();

        final groupKey = 'group_${state.varietyGroups.indexOf(group)}';
        final color = _getEntryColor(produce, state, groupKey);

        rows.add(
          _withLeftBorder(
            theme: theme,
            color: color,
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.link_rounded,
                      size: 16,
                      color: theme.colorScheme.onPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      groupFormStr != null
                          ? 'Any of: $groupFormStr'
                          : 'Any of:',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...memberRows,
              ],
            ),
          ),
        );
      }

      // Ungrouped items
      for (final entry in breakdown.entries) {
        if (entry.key.startsWith('group_')) continue;
        final key = entry.key;
        if (state.varietyGroups.any((g) => g.contains(key))) continue;

        final isAny = key.toLowerCase() == 'any';
        final targets = isAny
            ? produce.varieties
            : produce.varieties.where((v) => v.name == key).toList();
        final soloV = targets.isNotEmpty
            ? targets.first
            : produce.varieties.first;
        final priceRange = _computePriceRange(
          targets,
          state.varietySelectedFormId,
        );
        final soloQty = entry.value;
        final soloTotal = priceRange.min * soloQty;
        final soloTotalMax = priceRange.max * soloQty;
        final formStr = resolveForm(key, soloV);
        final color = _getEntryColor(produce, state, key);

        rows.add(
          _withLeftBorder(
            theme: theme,
            color: color,
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        key,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (formStr != null && formStr.isNotEmpty)
                        Text(
                          formStr,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onTertiary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      priceRange.isSingle
                          ? DuruhaFormatter.formatCurrency(soloTotal)
                          : '${DuruhaFormatter.formatCurrency(soloTotal)}–${DuruhaFormatter.formatCurrency(soloTotalMax)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${priceRange.label} × ${soloQty.toStringAsFixed(0)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }
    }

    return rows;
  }

  Widget _buildVarietyRow(
    ThemeData theme,
    CropSelectionState state,
    String label,
    double quantity, {
    required _PriceRange priceRange,
    required String unit,
    DateTime? dateNeeded,
    bool priceLock = false,
    ValueChanged<bool>? onPriceLockChanged,
    int? numDates,
    bool isGrouped = false,
    String? form,
  }) {
    final perUnit = priceRange.min;
    final baseTotal = perUnit * quantity;
    final displayTotal = (numDates != null && numDates > 1)
        ? baseTotal * numDates
        : baseTotal;
    final isAny = label.toLowerCase() == 'any';
    final isRange = !priceRange.isSingle;

    return Container(
      margin: isGrouped ? const EdgeInsets.only(bottom: 10) : EdgeInsets.zero,
      padding: isGrouped
          ? const EdgeInsets.fromLTRB(16, 10, 12, 10)
          : EdgeInsets.zero,
      decoration: isGrouped
          ? BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            )
          : null,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isGrouped) ...[
                Icon(
                  Icons.link_rounded,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (form != null && form.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        form,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onTertiary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Price-lock checkbox moved into the price column below
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (onPriceLockChanged != null) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (priceLock && !_isPlan) ...[
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 11,
                            color: theme.colorScheme.tertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Price locked',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.tertiary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          'LOCK',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w900,
                            fontSize: 8,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 4),
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: priceLock,
                            onChanged: (val) =>
                                onPriceLockChanged(val ?? false),
                            activeColor: theme.colorScheme.tertiary,
                            side: BorderSide(
                              color: theme.colorScheme.onSurfaceVariant,
                              width: 2,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      () {
                        if (isAny && !priceRange.isSingle) {
                          final maxTotal = priceRange.max * quantity;
                          final displayMaxTotal =
                              (numDates != null && numDates > 1)
                              ? maxTotal * numDates
                              : maxTotal;
                          return '${DuruhaFormatter.formatCurrency(displayTotal)}–${DuruhaFormatter.formatCurrency(displayMaxTotal)}';
                        }

                        return isAny || isRange
                            ? DuruhaFormatter.formatCurrency(displayTotal)
                            : DuruhaFormatter.formatCurrency(displayTotal);
                      }(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _buildPriceDetailLine(
                      quantity,
                      unit,
                      priceRange,
                      numDates,
                      isAny,
                    ),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ],
          ),
          if (!_isPlan && dateNeeded != null) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  'Needed ${DuruhaFormatter.formatDate(dateNeeded)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _buildPriceDetailLine(
    double qty,
    String unit,
    _PriceRange price,
    int? numDates,
    bool isAny,
  ) {
    final qtyStr = '${DuruhaFormatter.formatCompactNumber(qty)} $unit';
    // price.label already formats as 'min–max' for ranges, so use it directly
    final priceStr = isAny && price.isSingle ? price.label : price.label;
    if (numDates != null && numDates > 1) {
      return '$qtyStr × $priceStr × $numDates dates';
    }
    return '$qtyStr × $priceStr';
  }

  Widget _buildPricingSummary(
    ThemeData theme,
    Produce produce,
    CropSelectionState state,
    double subtotal,
    double totalAmt,
  ) {
    if (_isPlan) {
      // Re-calculate the Plan Min & Max Subtotal by looping over breakdown targets.
      // Group: take min/max of the shared targets * group qty.
      // Solo:  take min/max of targets * solo qty.
      double estMin = 0.0;
      double estMax = 0.0;
      final breakdown = <String, double>{};
      for (final key in state.varietyQuantityControllers.keys) {
        breakdown[key] =
            double.tryParse(state.varietyQuantityControllers[key]!.text) ?? 0;
      }

      for (final group in state.varietyGroups) {
        final selected = group.where((v) => breakdown.containsKey(v)).toList();
        if (selected.isEmpty) continue;

        double groupMinTotal = double.infinity;
        double groupMaxTotal = 0.0;
        final groupQty = breakdown[selected.first] ?? 0.0;

        for (final key in selected) {
          final isAny = key.toLowerCase() == 'any';
          final targets = isAny
              ? produce.varieties
              : produce.varieties.where((v) => v.name == key).toList();

          final range = _computePriceRange(
            targets,
            state.varietySelectedFormId,
          );

          final qty = groupQty;
          final currentMinTotal = range.min * qty;
          final currentMaxTotal = range.max * qty;

          if (currentMinTotal < groupMinTotal) groupMinTotal = currentMinTotal;
          if (currentMaxTotal > groupMaxTotal) groupMaxTotal = currentMaxTotal;
        }

        if (groupMinTotal == double.infinity) groupMinTotal = 0.0;

        estMin += groupMinTotal;
        estMax += groupMaxTotal;
      }

      // Solo totals
      for (final entry in breakdown.entries) {
        if (entry.key.startsWith('group_')) continue;
        if (state.varietyGroups.any((g) => g.contains(entry.key))) continue;

        final key = entry.key;
        final isAny = key.toLowerCase() == 'any';
        final resolvedTargets = isAny
            ? produce.varieties
            : produce.varieties.where((v) => v.name == key).toList();

        final range = _computePriceRange(
          resolvedTargets,
          state.varietySelectedFormId,
        );
        estMin += range.min * entry.value;
        estMax += range.max * entry.value;
      }

      final isRange = estMin != estMax;

      String fmt(double val) => DuruhaFormatter.formatCurrency(val);

      final totalStr = isRange
          ? '${fmt(estMin)} - ${fmt(estMax)}'
          : fmt(estMin);

      return Column(
        children: [
          _pricingRow(
            theme,
            label: 'Total (per delivery)',
            value: totalStr,
            isMain: true,
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Actual prices are set by the farmer at fulfillment time. '
                    'The amounts shown are estimates based on current listings.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // ORDER MODE
    // Check whether 'Any' variety is in the breakdown (ungrouped or in a group).
    // If so, we must show a min–max range for subtotal/fee/total.
    final breakdown2 = <String, double>{};
    for (final key in state.varietyQuantityControllers.keys) {
      breakdown2[key] =
          double.tryParse(state.varietyQuantityControllers[key]!.text) ?? 0;
    }
    final hasAny =
        breakdown2.keys.any((k) => k.toLowerCase() == 'any') ||
        state.varietyGroups.isNotEmpty;

    if (hasAny) {
      // Re-compute min/max like Plan Mode
      double estMin = 0.0;
      double estMax = 0.0;
      for (final group in state.varietyGroups) {
        final selected = group.where((v) => breakdown2.containsKey(v)).toList();
        if (selected.isEmpty) continue;
        double gMin = double.infinity;
        double gMax = 0.0;
        final groupQty = breakdown2[selected.first] ?? 0.0;

        for (final key in selected) {
          final isAny = key.toLowerCase() == 'any';
          final targets = isAny
              ? produce.varieties.toList()
              : produce.varieties.where((v) => v.name == key).toList();
          final r = _computePriceRange(targets, state.varietySelectedFormId);
          final qty = groupQty;
          final mn = r.min * qty;
          final mx = r.max * qty;
          if (mn < gMin) gMin = mn;
          if (mx > gMax) gMax = mx;
        }
        if (gMin == double.infinity) gMin = 0.0;
        estMin += gMin;
        estMax += gMax;
      }
      for (final entry in breakdown2.entries) {
        if (entry.key.startsWith('group_')) continue;
        if (state.varietyGroups.any((g) => g.contains(entry.key))) continue;
        final key = entry.key;
        final isAny = key.toLowerCase() == 'any';
        final targets = isAny
            ? produce.varieties.toList()
            : produce.varieties.where((v) => v.name == key).toList();
        final r = _computePriceRange(targets, state.varietySelectedFormId);
        estMin += r.min * entry.value;
        estMax += r.max * entry.value;
      }

      final isRange = estMin != estMax;
      String fmt(double v) => DuruhaFormatter.formatCurrency(v);
      final totalStr = isRange ? '${fmt(estMin)}–${fmt(estMax)}' : fmt(estMin);

      return Column(
        children: [
          _pricingRow(
            theme,
            label: 'Total Price',
            value: totalStr,
            isMain: true,
          ),
        ],
      );
    }

    return Column(
      children: [
        _pricingRow(
          theme,
          label: 'Total Price',
          value: DuruhaFormatter.formatCurrency(subtotal),
          isMain: true,
        ),
      ],
    );
  }

  Widget _pricingRow(
    ThemeData theme, {
    required String label,
    required String value,
    Color? valueColor,
    bool isMain = false,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: isMain
              ? theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                )
              : theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
        ),
        Text(
          value,
          style: isMain
              ? theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onPrimary,
                )
              : theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? theme.colorScheme.onSurface,
                ),
        ),
      ],
    );
  }

  // ─── Price Lock Banner (Order Mode) ──────────────────────────────────────

  Widget _buildPriceLockSummaryBanner(
    ThemeData theme, {
    bool showChangeButton = true,
  }) {
    if (_activeSubscription == null) {
      return const SizedBox.shrink();
    }

    final sub = _activeSubscription!;
    final totalLocked = _calculateTotalLockedCredits();
    final totalUnlocked = _calculateTotalUnlockedCredits();
    final newRemaining = sub.remainingCredits - totalLocked;
    final isOver = _isOverLimit;
    final baseColor = isOver
        ? theme.colorScheme.errorContainer
        : theme.colorScheme.tertiaryContainer;
    final onColor = isOver
        ? theme.colorScheme.error
        : theme.colorScheme.onTertiaryContainer;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOver ? theme.colorScheme.error : theme.colorScheme.tertiary,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security_rounded, color: onColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Price Lock Active',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: onColor,
                  ),
                ),
              ),
              if (showChangeButton)
                TextButton.icon(
                  onPressed: () => _showPriceLockPicker(context, theme),
                  icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
                  label: const Text('Change'),
                  style: TextButton.styleFrom(
                    foregroundColor: onColor,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'CPLS ID: ${sub.cplsId.substring(0, 8)}…',
            style: theme.textTheme.bodySmall?.copyWith(
              color: onColor.withValues(alpha: 0.8),
            ),
          ),
          // Price-lock note
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: onColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: onColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '⚠️ Price Lock Note: Final price lock is determined after the transaction. '
                    'You will only pay the locked amount if the available price '
                    'meets or exceeds it. Price might change anytime.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: onColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: onColor.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 12),
          _creditRow(
            theme,
            'Locked Total (max):',
            DuruhaFormatter.formatCurrency(totalLocked),
            onColor,
          ),
          const SizedBox(height: 4),
          _creditRow(
            theme,
            'Remaining Credits:',
            DuruhaFormatter.formatCurrency(newRemaining),
            onColor,
            bold: true,
          ),
          const SizedBox(height: 4),
          Divider(color: onColor.withValues(alpha: 0.2), height: 1),
          _creditRow(
            theme,
            'Unlocked Total:',
            DuruhaFormatter.formatCurrency(totalUnlocked),
            onColor.withValues(alpha: 0.7),
          ),
          if (isOver) ...[
            const SizedBox(height: 8),
            Text(
              'You have exceeded your price lock credit limit. Please uncheck some items.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _creditRow(
    ThemeData theme,
    String label,
    String value,
    Color color, {
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: color)),
        Text(
          value,
          style:
              (bold ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium)
                  ?.copyWith(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  void _showPriceLockPicker(BuildContext context, ThemeData theme) {
    if (_subscriptions.isEmpty) {
      DuruhaSnackBar.showInfo(
        context,
        'No active Price Lock subscriptions found.',
      );
      return;
    }

    DuruhaBottomSheet.show(
      context: context,
      title: 'Select Price Lock',
      icon: Icons.security_rounded,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPriceLockSummaryBanner(theme, showChangeButton: false),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: _subscriptions.length + 1,
            itemBuilder: (_, index) {
              if (index == 0) {
                final isSel = _activeSubscription == null;
                return ListTile(
                  leading: const Icon(Icons.cancel_outlined),
                  title: const Text('No Price Lock'),
                  trailing: isSel
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: theme.colorScheme.primary,
                        )
                      : null,
                  selected: isSel,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    setState(() => _activeSubscription = null);
                    Navigator.pop(context);
                  },
                );
              }

              final sub = _subscriptions[index - 1];
              final isSel = _activeSubscription?.cplsId == sub.cplsId;
              final isActive = sub.status == 'active';

              return Container(
                margin: const EdgeInsets.only(top: 8),
                child: ListTile(
                  leading: Icon(
                    Icons.security_rounded,
                    color: isActive
                        ? theme.colorScheme.tertiary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  title: Text('CPLS: ${sub.cplsId.substring(0, 8)}…'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Remaining: ${DuruhaFormatter.formatCurrency(sub.remainingCredits.toDouble())}',
                        style: TextStyle(
                          color: isActive ? theme.colorScheme.tertiary : null,
                          fontWeight: isActive ? FontWeight.bold : null,
                        ),
                      ),
                      Text(
                        'Expires: ${DateFormat('MMM dd, yyyy').format(sub.endsAt)}',
                      ),
                    ],
                  ),
                  trailing: isSel
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: theme.colorScheme.tertiary,
                        )
                      : null,
                  enabled: isActive && sub.remainingCredits > 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onTap: () {
                    if (!isActive || sub.remainingCredits <= 0) return;
                    setState(() => _activeSubscription = sub);
                    Navigator.pop(context);
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _saveDraft(String cropId) async {
    final state = widget.cropStates[cropId];
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

  Widget _buildQualitySubscriptionBanner(ThemeData theme) {
    if (_qualitySubscription == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No active quality subscription. Items will be delivered at "Saver" quality tier.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final sub = _qualitySubscription!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Active Quality: ${sub.tierName}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'ACTIVE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            sub.description ??
                'Your subscription unlocks premium quality for all produce.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
