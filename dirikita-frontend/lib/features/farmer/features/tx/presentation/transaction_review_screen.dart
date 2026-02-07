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

  Future<void> _submitAll() async {
    setState(() => _isSubmitting = true);
    HapticFeedback.heavyImpact();

    try {
      final List<HarvestPledge> allPledges = [];

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

        // Collect only valid quantities
        for (var entry in state.varietyQuantityControllers.entries) {
          double q = double.tryParse(entry.value.text) ?? 0;
          if (q > 0) {
            varietyQuantities[entry.key] = q;
            finalVariants.add(entry.key);
            totalQuantity += q;
          }
        }

        if (widget.mode == 'pledge') {
          // CREATE PLEDGE for ALL DATES
          final pledges = state.perDatePledges;

          if (pledges.isNotEmpty) {
            // Use first date as primary harvestDate, or just rely on perDatePledges list
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
              availableDate: state.availableDate,
              disposalDate: state.disposalDate,
              varietyQuantities: overallVarietyQuantities,
              perDatePledges: pledges,
              quantity: totalPledged,
              unit: state.selectedUnit,
              farmerId: 'farmer-001',
              targetMarket: targetMarket,
              currentStatus: 'Set',
            );
            allPledges.add(pledge);
          }
        } else {
          // OFFER MODE (Single available range usually, handled as is?)
          // Offer usually uses availableDate. If logic uses harvestDate fallback:
          final date = state.availableDate ?? DateTime.now();

          final pledge = HarvestPledge(
            cropId: produce.id,
            cropName: produce.nameEnglish,
            variants: finalVariants,
            harvestDate: date, // Logic dictates availableDate is key
            availableDate: state.availableDate,
            disposalDate: state.disposalDate,
            varietyQuantities: varietyQuantities,
            quantity: totalQuantity,
            unit: state.selectedUnit,
            farmerId: 'farmer-001',
            targetMarket: targetMarket,
            currentStatus: 'Harvest', // Offer -> Harvest/Ready
          );
          allPledges.add(pledge);
        }
      }

      if (allPledges.isNotEmpty) {
        final request = TransactionRequest(
          mode: widget.mode,
          pledges: allPledges,
        );
        final success = await _txRepository.submitTransaction(request);
        if (!success) throw Exception("Transaction failed");
      }

      await TransactionDraftService.clearAll();

      if (mounted) {
        DuruhaSnackBar.showSuccess(
          context,
          "${widget.mode == 'pledge' ? 'Pledges' : 'Offers'} submitted successfully!",
        );
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/farmer/biz', (route) => false);
      }
    } catch (e) {
      if (mounted)
        DuruhaSnackBar.showError(
          context,
          "Submission failed. Please try again.",
        );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.mode == 'pledge' ? 'Review Pledge' : 'Review Offer';

    return DuruhaScaffold(
      appBarTitle: title,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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
        backgroundColor: theme.colorScheme.secondary,
        foregroundColor: theme.colorScheme.onPrimary,
        elevation: 4,
        label: _isSubmitting
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: theme.colorScheme.onPrimary,
                  strokeWidth: 2.5,
                ),
              )
            : Text(widget.mode == 'pledge' ? 'Pledge Now' : 'Offer Now'),
        icon: _isSubmitting ? null : const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  Widget _buildReviewCard(
    ThemeData theme,
    Produce produce,
    CropSelectionState state,
  ) {
    double total = 0;
    final breakdown = <Widget>[];
    final Map<String, double> varietyBreakdown = {};

    if (widget.mode == 'pledge') {
      state.perDatePledgesMap.forEach((date, dailyBreakdown) {
        dailyBreakdown.forEach((v, qty) {
          total += qty;
          varietyBreakdown[v] = (varietyBreakdown[v] ?? 0) + qty;
        });
      });
    } else {
      state.varietyQuantityControllers.forEach((variant, controller) {
        final qty = double.tryParse(controller.text) ?? 0;
        if (qty > 0) {
          total += qty;
          varietyBreakdown[variant] = qty;
        }
      });
    }

    String dateText = "";
    if (widget.mode == 'pledge') {
      final dates = state.selectedHarvestDates..sort();
      if (dates.isNotEmpty) {
        if (dates.length == 1) {
          dateText =
              "Harvest: ${DateFormat('MMM dd, yyyy').format(dates.first)}";
        } else {
          // Display range or list count
          dateText = "Harvest: ${dates.length} dates selected";
        }
      } else {
        dateText = "Harvest: Not Set";
      }
    } else {
      if (state.availableDate != null && state.disposalDate != null) {
        dateText =
            "${DateFormat('MMM dd').format(state.availableDate!)} - ${DateFormat('MMM dd, yyyy').format(state.disposalDate!)}";
      }
    }

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
                      widget.mode == 'pledge' &&
                              state.selectedHarvestDates.isNotEmpty
                          ? "${state.selectedHarvestDates.length} harvest dates"
                          : dateText,
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
          if (widget.mode == 'pledge')
            Divider(color: Theme.of(context).colorScheme.onPrimaryContainer),
          const SizedBox(height: 8),

          // PLEDGE MODE: Show Per-Date Breakdown
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
                              "${DuruhaFormatter.formatCompactNumber(v.value)} ${state.selectedUnit}",
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
          else
            // OFFER MODE: Show Flat List
            ...breakdown,

          if (widget.mode == "pledge") ...[
            const SizedBox(height: 8),
            Divider(color: Theme.of(context).colorScheme.onSecondaryContainer),
            const SizedBox(height: 8),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total Quantity",
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "${DuruhaFormatter.formatCompactNumber(total)} ${state.selectedUnit}",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ],
          ),
          if (varietyBreakdown.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(
                height: 1,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.2,
                ),
              ),
            ),
            Text(
              "By Variety",
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...varietyBreakdown.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      e.key,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      "${DuruhaFormatter.formatCompactNumber(e.value)} ${state.selectedUnit}",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
