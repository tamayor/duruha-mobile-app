import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'crop_selection_state.dart';

import '../data/transaction_draft_service.dart';
import '../data/transaction_repository.dart';
import '../../../shared/domain/farmer_price_lock_subscription_model.dart';
import 'package:duruha/features/farmer/shared/presentation/farmer_loading_screen.dart';

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
  bool _isSubmitting = false;

  List<FarmerPriceLockSubscription> _subscriptions = [];
  FarmerPriceLockSubscription? _activeSubscription;
  bool _isLoadingSubscription = true;

  @override
  void initState() {
    super.initState();
    _fetchSubscriptions();
  }

  Future<void> _fetchSubscriptions() async {
    final farmerId = await SessionService.getRoleId();
    if (farmerId != null) {
      final subs = await _txRepository.fetchAllPriceLockSubscriptions(farmerId);

      // Sort logic: active first, then most remaining credits, then latest end date
      subs.sort((a, b) {
        if (a.status == 'active' && b.status != 'active') return -1;
        if (a.status != 'active' && b.status == 'active') return 1;

        // both same status
        if (a.remainingCredits != b.remainingCredits) {
          return b.remainingCredits.compareTo(a.remainingCredits);
        }

        return b.endsAt.compareTo(a.endsAt);
      });

      if (mounted) {
        setState(() {
          _subscriptions = subs;
          // default to the best one if it's active and has credits
          if (subs.isNotEmpty &&
              subs.first.status == 'active' &&
              subs.first.remainingCredits > 0) {
            _activeSubscription = subs.first;
          }
          _isLoadingSubscription = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoadingSubscription = false);
      }
    }
  }

  Future<void> _submitAll() async {
    if (_activeSubscription != null) {
      // Gather all price locked offers to show in the confirmation
      final List<String> lockedNames = [];
      for (var produce in widget.selectedProduce) {
        final state = widget.cropStates[produce.id]!;
        for (var entry in state.offerEntries) {
          if (entry.isPriceLock) {
            lockedNames.add(
              "${produce.nameEnglish} - ${entry.varietyName} (${entry.produceForm})",
            );
          }
        }
      }

      // If they selected a subscription but checked NOTHING, warn them
      if (lockedNames.isEmpty) {
        DuruhaSnackBar.showError(
          context,
          "You didn't price lock any offer. Removing price lock selection.",
        );
        setState(() {
          _activeSubscription = null;
          _recomputePriceLockStates();
        });
        return;
      }

      // If they DID check items, show the confirmation dialog
      final confirm = await DuruhaDialog.show(
        context: context,
        title: "Confirm Price Lock",
        message:
            "You are locking the price for the following items:\n\n• ${lockedNames.join('\n• ')}\n\nDo you want to proceed with this offer?",
        confirmText: "PROCEED",
        cancelText: "CANCEL",
        icon: Icons.lock_rounded,
      );

      if (confirm != true) return;
    }

    setState(() => _isSubmitting = true);
    HapticFeedback.heavyImpact();
    String successMessage = widget.mode == 'pledge'
        ? 'Pledges submitted successfully!'
        : 'Offers submitted successfully!';

    try {
      final List<HarvestPledge> allPledges = [];
      final farmerId = await SessionService.getRoleId() ?? 'unknown-farmer';

      // For Offer Mode: Prepare data for repository
      final Map<String, Map<String, double>> cropQuantities = {};
      final Map<String, Map<String, DateTime?>> cropVarietyAvailableDates = {};
      final Map<String, Map<String, DateTime?>> cropVarietyDisposalDates = {};

      for (var produce in widget.selectedProduce) {
        final state = widget.cropStates[produce.id]!;

        // Determine market based on demand if pledge
        String targetMarket = 'Local';
        if (state.simulatedDemand != null) {
          double totalDemand = 0;
          double totalFulfilled = 0;

          for (var item in state.simulatedDemand!) {
            totalDemand += (item['demand_kg'] as num).toDouble();
            totalFulfilled += (item['fulfilled_kg'] as num).toDouble();
          }

          if (totalFulfilled >= totalDemand) targetMarket = 'National';
        }

        final Map<String, double> varietyQuantities = {};
        final List<String> finalVariants = [];
        double totalQuantity = 0;

        // Collect quantities for the repository/pledge
        for (var entry in state.varietyQuantityControllers.entries) {
          double q = double.tryParse(entry.value.text) ?? 0;
          if (q > 0) {
            varietyQuantities[entry.key] = q;
            finalVariants.add(entry.key);
            totalQuantity += q;
          }
        }

        if (widget.mode == 'offer') {
          cropQuantities[produce.id] = varietyQuantities;
          cropVarietyAvailableDates[produce.id] = state.varietyAvailableDates;
          cropVarietyDisposalDates[produce.id] = state.varietyDisposalDates;
        }

        if (widget.mode == 'pledge') {
          // CREATE PLEDGE for ALL DATES
          final pledges = state.perDatePledges;

          if (pledges.isNotEmpty) {
            final firstDate = state.selectedHarvestDates.first;
            double totalPledged = 0;
            final allVariants = <String>{};
            final overallVarietyQuantities = <String, double>{};

            for (var entry in pledges) {
              totalPledged += entry.quantity;
              allVariants.add(entry.variety);
              overallVarietyQuantities[entry.variety] =
                  (overallVarietyQuantities[entry.variety] ?? 0) +
                  entry.quantity;
            }

            final pledge = HarvestPledge(
              cropId: produce.id,
              cropName: produce.nameEnglish,
              variants: allVariants.toList(),
              harvestDate: firstDate,
              varietyAvailableDates: state.varietyAvailableDates,
              varietyDisposalDates: state.varietyDisposalDates,
              varietyQuantities: overallVarietyQuantities,
              perDatePledges: pledges,
              quantity: totalPledged,
              unit: state.selectedUnit,
              farmerId: farmerId,
              targetMarket: targetMarket,
              currentStatus: 'Set',
            );
            allPledges.add(pledge);
          }
        } else {
          final pledge = HarvestPledge(
            cropId: produce.id,
            cropName: produce.nameEnglish,
            variants: finalVariants,
            harvestDate: DateTime.now(),
            varietyAvailableDates: state.varietyAvailableDates,
            varietyDisposalDates: state.varietyDisposalDates,
            varietyQuantities: varietyQuantities,
            quantity: totalQuantity,
            unit: state.selectedUnit,
            farmerId: farmerId,
            targetMarket: targetMarket,
            currentStatus: 'Harvest',
          );
          allPledges.add(pledge);
        }
      }

      if (widget.mode == 'offer') {
        // Build produceId -> List<OfferFormEntry> map
        final Map<String, List<OfferFormEntry>> produceOfferEntries = {};
        for (final produce in widget.selectedProduce) {
          final entries = widget.cropStates[produce.id]?.offerEntries ?? [];
          if (entries.any((e) => e.quantity > 0)) {
            produceOfferEntries[produce.id] = entries;
          }
        }

        if (produceOfferEntries.isNotEmpty) {
          final (success, message) = await _txRepository.submitOffers(
            selectedProduce: widget.selectedProduce,
            produceOfferEntries: produceOfferEntries,
          );
          if (!success) throw Exception(message);
          successMessage = message;
        }
      }
      await TransactionDraftService.clearAll();

      if (mounted) {
        DuruhaSnackBar.showSuccess(context, successMessage);
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/farmer/manage', (route) => false);
      }
    } catch (e) {
      //debugPrint("❌ [SUBMISSION ERROR]: $e");
      if (mounted) {
        DuruhaSnackBar.showError(context, "Submission failed: ${e.toString()}");
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  double _calculateTotalLockedCredits() {
    if (_activeSubscription == null) return 0;
    double total = 0;
    for (final produce in widget.selectedProduce) {
      final state = widget.cropStates[produce.id];
      if (state == null) continue;
      for (final e in state.offerEntries) {
        if (e.isPriceLock) {
          total += (e.quantity * e.pricePerUnit);
        }
      }
    }
    return total;
  }

  double _calculateTotalUnlockedCredits() {
    double total = 0;
    for (final produce in widget.selectedProduce) {
      final state = widget.cropStates[produce.id];
      if (state == null) continue;
      for (final e in state.offerEntries) {
        if (!e.isPriceLock) {
          total += (e.quantity * e.pricePerUnit);
        }
      }
    }
    return total;
  }

  void _recomputePriceLockStates() {
    // Ensuring no entry is price locked if it exceeds the remaining credits
    if (_activeSubscription == null) return;

    // A simple guard: if over limit, optionally auto-disable the last one,
    // but typically we block checking it in the UI before it happens.
    // For now, it's just a passive check, we rely on the UI toggle to prevent overflow.
    setState(() {}); // trigger rebuild to update FPLS banner
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.mode == 'pledge' ? 'Review Pledge' : 'Review Offer';

    return DuruhaScaffold(
      appBarTitle: title,
      appBarActions: [
        if (widget.mode == 'offer' && _subscriptions.isNotEmpty) ...[
          IconButton(
            icon: const Icon(Icons.security_rounded),
            tooltip: 'Select Price Lock',
            onPressed: () => _showPriceLockPicker(context, theme),
          ),
          const SizedBox(width: 8),
        ],
      ],
      body: _isLoadingSubscription
          ? const FarmerLoadingScreen()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildPriceLockSummaryBanner(theme),
                  const SizedBox(height: 16),
                  ...widget.selectedProduce.map((produce) {
                    final state = widget.cropStates[produce.id]!;
                    return _buildReviewCard(theme, produce, state);
                  }),
                  const SizedBox(height: 100),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSubmitting ? null : _submitAll,
        backgroundColor: theme.colorScheme.tertiary,
        foregroundColor: theme.colorScheme.onTertiary,
        elevation: 4,
        label: _isSubmitting
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: theme.colorScheme.onTertiary,
                  strokeWidth: 2.5,
                ),
              )
            : Text(widget.mode == 'pledge' ? 'Pledge Now' : 'Offer Now'),
        icon: _isSubmitting ? null : const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  Widget _buildPriceLockSummaryBanner(ThemeData theme) {
    if (_activeSubscription == null || widget.mode == 'pledge') {
      return const SizedBox.shrink();
    }

    final sub = _activeSubscription!;
    final totalLocked = _calculateTotalLockedCredits();
    final totalUnlocked = _calculateTotalUnlockedCredits();
    final newRemaining = sub.remainingCredits - totalLocked;

    final isOverLimit = newRemaining < 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOverLimit
            ? theme.colorScheme.errorContainer
            : theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOverLimit
              ? theme.colorScheme.error
              : theme.colorScheme.tertiary,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security_rounded,
                color: isOverLimit
                    ? theme.colorScheme.error
                    : theme.colorScheme.onTertiaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Price Lock Active",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isOverLimit
                        ? theme.colorScheme.error
                        : theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _showPriceLockPicker(context, theme),
                icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
                label: const Text("Change"),
                style: TextButton.styleFrom(
                  foregroundColor: isOverLimit
                      ? theme.colorScheme.error
                      : theme.colorScheme.onTertiaryContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Secured payment for all offers every sold offer until maxed out. FPLS ID: ${sub.fplsId.substring(0, 8)}...",
            style: theme.textTheme.bodySmall?.copyWith(
              color: isOverLimit
                  ? theme.colorScheme.error.withValues(alpha: 0.8)
                  : theme.colorScheme.onTertiaryContainer.withValues(
                      alpha: 0.8,
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Divider(
            color: isOverLimit
                ? theme.colorScheme.error.withValues(alpha: 0.3)
                : theme.colorScheme.onTertiaryContainer.withValues(alpha: 0.1),
            height: 1,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Locked Total:",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isOverLimit
                      ? theme.colorScheme.error
                      : theme.colorScheme.onTertiaryContainer,
                ),
              ),
              Text(
                DuruhaFormatter.formatCurrency(totalLocked),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isOverLimit
                      ? theme.colorScheme.error
                      : theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Remaining Credits:",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isOverLimit
                      ? theme.colorScheme.error
                      : theme.colorScheme.onTertiaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                DuruhaFormatter.formatCurrency(newRemaining),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isOverLimit
                      ? theme.colorScheme.error
                      : theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            color: isOverLimit
                ? theme.colorScheme.error.withValues(alpha: 0.3)
                : theme.colorScheme.onTertiaryContainer.withValues(alpha: 0.1),
            height: 1,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Unlocked Total:",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isOverLimit
                      ? theme.colorScheme.error.withValues(alpha: 0.8)
                      : theme.colorScheme.onTertiaryContainer.withValues(
                          alpha: 0.8,
                        ),
                ),
              ),
              Text(
                DuruhaFormatter.formatCurrency(totalUnlocked),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isOverLimit
                      ? theme.colorScheme.error.withValues(alpha: 0.8)
                      : theme.colorScheme.onTertiaryContainer.withValues(
                          alpha: 0.8,
                        ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          if (isOverLimit) ...[
            const SizedBox(height: 8),
            Text(
              "You have exceeded your price lock credit limit. Please uncheck some items.",
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

  void _showPriceLockPicker(BuildContext context, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Select Price Lock",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              const Divider(),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _subscriptions.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Option to remove price lock
                      final isSelected = _activeSubscription == null;
                      return ListTile(
                        leading: const Icon(Icons.cancel_outlined),
                        title: const Text("No Price Lock"),
                        trailing: isSelected
                            ? Icon(
                                Icons.check_circle_rounded,
                                color: theme.colorScheme.primary,
                              )
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        tileColor: isSelected
                            ? theme.colorScheme.primaryContainer.withValues(
                                alpha: 0.3,
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _activeSubscription = null;
                            _recomputePriceLockStates();
                          });
                          Navigator.pop(ctx);
                        },
                      );
                    }

                    final sub = _subscriptions[index - 1];
                    final isSelected =
                        _activeSubscription?.fplsId == sub.fplsId;
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
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                "FPLS: ${sub.fplsId.substring(0, 8)}...",
                              ),
                            ),
                            if (isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "ACTIVE",
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color:
                                        theme.colorScheme.onTertiaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              "Credits: ${DuruhaFormatter.formatCurrency(sub.remainingCredits)}",
                              style: TextStyle(
                                color: sub.remainingCredits > 0
                                    ? null
                                    : theme.colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              "${DateFormat('MMM dd').format(sub.startsAt)} - ${DateFormat('MMM dd, yyyy').format(sub.endsAt)}",
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        tileColor: isSelected
                            ? theme.colorScheme.primaryContainer.withValues(
                                alpha: 0.3,
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _activeSubscription = sub;
                            _recomputePriceLockStates();
                          });
                          Navigator.pop(ctx);
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewCard(
    ThemeData theme,
    Produce produce,
    CropSelectionState state,
  ) {
    double total = 0;

    if (widget.mode == 'pledge') {
      state.perDatePledgesMap.forEach((date, dailyBreakdown) {
        dailyBreakdown.forEach((v, qty) {
          total += qty;
        });
      });
    } else {
      for (final e in state.offerEntries) {
        total += e.quantity;
      }
    }

    String dateText = widget.mode == 'pledge'
        ? (state.selectedHarvestDates.isNotEmpty
              ? 'Harvest: ${state.selectedHarvestDates.length} date${state.selectedHarvestDates.length == 1 ? '' : 's'}'
              : 'Harvest: Not Set')
        : 'Offer';

    final sub = _activeSubscription;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Produce header ──
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  produce.imageThumbnailUrl,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 40,
                    height: 40,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.eco_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      produce.nameEnglish,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      dateText,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 8),

          // ── PLEDGE MODE: per-date breakdown ──
          if (widget.mode == 'pledge')
            ...state.perDatePledgesMap.entries.map((entry) {
              final date = entry.key;
              final varieties = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('MMM dd, yyyy').format(date),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...varieties.entries.map(
                      (v) => Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              v.key,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              '${DuruhaFormatter.formatCompactNumber(v.value)} ${state.selectedUnit}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            })
          // ── OFFER MODE: variety → form → qty + dates ──
          else ...[
            // Group entries by variety
            ...() {
              final Map<String, List<OfferFormEntry>> byVariety = {};
              for (final e in state.offerEntries) {
                byVariety.putIfAbsent(e.varietyName, () => []).add(e);
              }
              return byVariety.entries.map((ve) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Variety name
                      Text(
                        ve.key,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...ve.value.asMap().entries.map((entryPair) {
                        final e = entryPair.value;
                        final priceSum = e.quantity * e.pricePerUnit;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Form label chip
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      e.produceForm,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: theme
                                                .colorScheme
                                                .onPrimaryContainer,
                                          ),
                                    ),
                                  ),
                                  const Spacer(),
                                  // Quantity
                                  Text(
                                    '${DuruhaFormatter.formatCompactNumber(e.quantity)} ${state.selectedUnit}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              if (e.hasDate) ...[
                                const SizedBox(height: 4),
                                Text(
                                  e.isInfinite
                                      ? '${DuruhaFormatter.formatDate(e.availableFrom!)} → Supply Lasts'
                                      : '${DuruhaFormatter.formatDate(e.availableFrom!)} – ${DuruhaFormatter.formatDate(e.availableTo!)}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Divider(
                                color: theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.5),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    DuruhaFormatter.formatCurrency(
                                      e.pricePerUnit,
                                    ),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    DuruhaFormatter.formatCurrency(priceSum),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              if (sub != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        checkColor:
                                            theme.colorScheme.onTertiary,
                                        fillColor:
                                            WidgetStateProperty.resolveWith((
                                              states,
                                            ) {
                                              if (states.contains(
                                                WidgetState.selected,
                                              )) {
                                                return theme
                                                    .colorScheme
                                                    .tertiary;
                                              }
                                              return null;
                                            }),
                                        value: e.isPriceLock,
                                        onChanged: (val) {
                                          if (val == null) return;

                                          setState(() {
                                            final updatedEntry = e.copyWith(
                                              isPriceLock: val,
                                              fplsId: val ? sub.fplsId : null,
                                              totalPriceLockCredit: val
                                                  ? priceSum
                                                  : null,
                                            );

                                            // Replace entry in the state list
                                            final idx = state.offerEntries
                                                .indexOf(e);
                                            if (idx != -1) {
                                              state.offerEntries[idx] =
                                                  updatedEntry;
                                            }
                                            _recomputePriceLockStates();
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Price Lock",
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontWeight: e.isPriceLock
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: e.isPriceLock
                                                ? theme
                                                      .colorScheme
                                                      .onTertiaryContainer
                                                : theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              });
            }(),
          ],

          Divider(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 4),

          // ── Total ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Quantity',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${DuruhaFormatter.formatCompactNumber(total)} ${state.selectedUnit}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
