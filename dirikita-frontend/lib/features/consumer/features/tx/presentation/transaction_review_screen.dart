import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/consumer/features/manage/domain/order_details_model.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:duruha/supabase_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'crop_selection_state.dart';
import '../data/transaction_draft_service.dart';
import '../data/transaction_repository.dart';
import 'transaction_message_screen.dart';

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
  final _noteController = TextEditingController();
  bool _isSubmitting = false;
  PlaceOrderResult? _matchResult;

  bool get _isPlan => widget.mode == 'plan';

  double get _grandTotal {
    double total = 0;
    for (var produce in widget.selectedProduce) {
      final state = widget.cropStates[produce.id]!;
      double itemSubtotal = 0;

      // Extract quantity per variety
      final Map<String, double> varietyBreakdown = {};
      if (_isPlan) {
        state.perDatePledgesMap.forEach((date, dailyBreakdown) {
          dailyBreakdown.forEach((v, qty) {
            varietyBreakdown[v] = (varietyBreakdown[v] ?? 0) + qty;
          });
        });
      } else {
        state.varietyQuantityControllers.forEach((variant, controller) {
          final qty = double.tryParse(controller.text) ?? 0;
          if (qty > 0) varietyBreakdown[variant] = qty;
        });
      }

      // Calculate subtotal
      for (var entry in varietyBreakdown.entries) {
        final vName = entry.key;
        final variety = produce.varieties.firstWhere(
          (v) => v.name == vName,
          orElse: () => produce.varieties.first,
        );
        final selectedFormId = state.varietySelectedFormId[vName];
        final listing =
            variety.listings
                .where((l) => l.listingId == selectedFormId)
                .firstOrNull ??
            (variety.listings.isNotEmpty ? variety.listings.first : null);
        final price = listing?.duruhaToConsumerPrice ?? 0.0;
        itemSubtotal += price * entry.value;
      }

      // Add quality fee
      total += itemSubtotal * (1 + state.qualityFee);
    }
    return total;
  }

  Future<void> _submitAll() async {
    setState(() => _isSubmitting = true);
    HapticFeedback.heavyImpact();

    try {
      final List<HarvestPledge> allPledges = [];
      final consumerId = await SessionService.getRoleId() ?? 'unknown-consumer';

      final Map<String, Map<String, double>> cropQuantities = {};
      final Map<String, Map<String, DateTime?>> cropVarietyAvailableDates = {};
      final Map<String, Map<String, DateTime?>> cropVarietyDisposalDates = {};
      final Map<String, Map<String, DateTime?>> cropVarietyDateNeeded = {};
      final Map<String, Map<String, String?>> cropFormSelections = {};
      final Map<String, Map<String, bool>> cropPriceLocks = {};

      for (var produce in widget.selectedProduce) {
        final state = widget.cropStates[produce.id]!;

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

        for (var entry in state.varietyQuantityControllers.entries) {
          double q = double.tryParse(entry.value.text) ?? 0;
          if (q > 0) {
            varietyQuantities[entry.key] = q;
            finalVariants.add(entry.key);
            totalQuantity += q;
          }
        }

        if (!_isPlan) {
          cropQuantities[produce.id] = varietyQuantities;
          cropVarietyAvailableDates[produce.id] = state.varietyAvailableDates;
          cropVarietyDisposalDates[produce.id] = state.varietyDisposalDates;
          cropVarietyDateNeeded[produce.id] = state.varietyDateNeeded;

          // Convert listingId to form name for the backend
          final Map<String, String?> formNames = {};
          for (var entry in state.varietySelectedFormId.entries) {
            final vName = entry.key;
            final selectedFormId = entry.value;

            if (selectedFormId != null) {
              if (vName == "Any") {
                // For "Any", the selectedFormId is already the form string
                formNames[vName] = selectedFormId;
              } else {
                final variety = produce.varieties.firstWhere(
                  (v) => v.name == vName,
                  orElse: () => produce.varieties.first,
                );
                final listing = variety.listings.firstWhere(
                  (l) => l.listingId == selectedFormId,
                  orElse: () => variety.listings.first,
                );
                formNames[vName] = listing.produceForm;
              }
            } else {
              formNames[vName] = null;
            }
          }
          cropFormSelections[produce.id] = formNames;
          cropPriceLocks[produce.id] = state.varietyPriceLock;
        }

        if (_isPlan) {
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

            allPledges.add(
              HarvestPledge(
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
                farmerId: consumerId,
                targetMarket: targetMarket,
                currentStatus: 'Set',
              ),
            );
          }
        } else {
          allPledges.add(
            HarvestPledge(
              cropId: produce.id,
              cropName: produce.nameEnglish,
              variants: finalVariants,
              harvestDate: DateTime.now(),
              varietyAvailableDates: state.varietyAvailableDates,
              varietyDisposalDates: state.varietyDisposalDates,
              varietyQuantities: varietyQuantities,
              quantity: totalQuantity,
              unit: state.selectedUnit,
              farmerId: consumerId,
              targetMarket: targetMarket,
              currentStatus: 'Harvest',
            ),
          );
        }
      }

      if (!_isPlan) {
        final Map<String, List<Set<String>>> varietyGroups = {};
        for (var produce in widget.selectedProduce) {
          varietyGroups[produce.id] =
              widget.cropStates[produce.id]!.varietyGroups;
        }

        final Map<String, String> cropQualities = {};
        for (var produce in widget.selectedProduce) {
          final state = widget.cropStates[produce.id]!;
          // Use the lowest selected tier as the primary preference
          cropQualities[produce.id] = state.qualityPreferences.last;
        }

        final userId = supabase.auth.currentUser?.id;
        if (userId == null) {
          throw Exception("You must be logged in to create an order.");
        }

        _matchResult = await _txRepository.txCreateOrder(
          selectedProduce: widget.selectedProduce,
          cropQuantities: cropQuantities,
          cropQualities: cropQualities,
          varietyDateNeeded: cropVarietyDateNeeded,
          varietyGroups: varietyGroups,
          varietySelectedFormId: cropFormSelections,
          varietyPriceLock: cropPriceLocks,
          note: _noteController.text.trim().isNotEmpty
              ? _noteController.text.trim()
              : null,
        );

        if (_matchResult == null) {
          throw Exception(
            "The order could not be completed at this time. Please try again.",
          );
        }
      }

      await TransactionDraftService.clearAll();
      if (mounted) {
        if (_isPlan) {
          DuruhaSnackBar.showSuccess(context, "Plan created successfully!");
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/consumer/manage/order', (route) => true);
        } else if (_matchResult != null) {
          DuruhaSnackBar.showSuccess(context, _matchResult!.message);
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) =>
                  TransactionMessageScreen(result: _matchResult!),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        DuruhaSnackBar.showError(context, "Submission failed: ${e.toString()}");
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DuruhaScaffold(
      appBarTitle: _isPlan ? 'Review Plan' : 'Review Order',
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            child: Column(
              children: [
                if (!_isPlan) ...[
                  // Grand Total Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.tertiary,
                          theme.colorScheme.tertiary.withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.tertiary.withValues(
                            alpha: 0.3,
                          ),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          "Order Grand Total",
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onTertiary.withValues(
                              alpha: 0.8,
                            ),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          DuruhaFormatter.formatCurrency(_grandTotal),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: theme.colorScheme.onTertiary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  DuruhaTextField(
                    label: "Order Notes",
                    icon: Icons.notes_rounded,
                    controller: _noteController,
                    maxLines: 2,
                    isRequired: false,
                  ),
                  const SizedBox(height: 16),
                ],
                ...widget.selectedProduce.map((produce) {
                  final state = widget.cropStates[produce.id]!;
                  return _buildReviewCard(theme, produce, state);
                }),
              ],
            ),
          ),
          _buildSubmitBar(theme),
        ],
      ),
    );
  }

  // ─── Bottom Submit Bar ───────────────────────────────────────────────────────

  Widget _buildSubmitBar(ThemeData theme) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        child: DuruhaButton(
          icon: _isSubmitting ? null : Icon(Icons.check_outlined),
          isLoading: _isSubmitting,
          backgroundColor: _isSubmitting
              ? theme.colorScheme.secondary
              : theme.colorScheme.tertiaryContainer,
          text: _isSubmitting
              ? 'Submitting...'
              : (_isPlan ? 'Confirm Plan' : 'Confirm Order'),
          onPressed: _submitAll,
        ),
      ),
    );
  }

  // ─── Review Card ─────────────────────────────────────────────────────────────

  Widget _buildReviewCard(
    ThemeData theme,
    Produce produce,
    CropSelectionState state,
  ) {
    // Quantity totals
    double total = 0;
    final Map<String, double> varietyBreakdown = {};

    if (_isPlan) {
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

    // Pricing
    double subtotal = 0;
    for (var varietyName in varietyBreakdown.keys) {
      final variety = produce.varieties.firstWhere(
        (v) => v.name == varietyName,
        orElse: () => produce.varieties.first,
      );
      final selectedFormId = state.varietySelectedFormId[varietyName];
      final listing =
          variety.listings
              .where((l) => l.listingId == selectedFormId)
              .firstOrNull ??
          (variety.listings.isNotEmpty ? variety.listings.first : null);
      final price = listing?.duruhaToConsumerPrice ?? 0.0;
      subtotal += price * (varietyBreakdown[varietyName] ?? 0);
    }
    final qualityFeeAmount = subtotal * state.qualityFee;
    final totalAmount = subtotal + qualityFeeAmount;

    // Date label
    String dateLabel = '';
    if (_isPlan) {
      final dates = state.selectedHarvestDates..sort();
      if (dates.isEmpty) {
        dateLabel = 'No harvest date set';
      } else if (dates.length == 1) {
        dateLabel = 'Harvest ${DateFormat('MMM dd, yyyy').format(dates.first)}';
      } else {
        dateLabel = '${dates.length} harvest dates';
      }
    } else {
      dateLabel = 'Variable delivery';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Crop image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    produce.imageThumbnailUrl,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.eco_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        produce.nameEnglish,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            _isPlan
                                ? Icons.calendar_today_rounded
                                : Icons.local_shipping_outlined,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            dateLabel,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Total quantity chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        DuruhaFormatter.formatCompactNumber(total),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      Text(
                        state.selectedUnit,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Quality selector (order mode) ────────────────────────────
          if (!_isPlan) ...[
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: DuruhaSelectionChipGroup(
                title: "Quality Preference",
                titleAction: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => _showQualityPreferenceNote(
                        context,
                        state.qualityPreferences,
                      ),
                      child: Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _applyQualityToAll(
                        state.qualityPreferences,
                        state.qualityFee,
                      ),
                      child: Icon(
                        Icons.copy_all_rounded,
                        size: 14,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
                options: const ['Select', 'Regular', 'Saver'],
                showChipBox: false,
                titleSize: 10,
                selectedValues: state.qualityPreferences,
                onToggle: (val) {
                  setState(() {
                    if (val == 'Saver') {
                      if (state.qualityPreferences.contains('Saver')) {
                        state.qualityPreferences = ['Select', 'Regular'];
                      } else {
                        state.qualityPreferences = [
                          'Select',
                          'Regular',
                          'Saver',
                        ];
                      }
                    } else if (val == 'Regular') {
                      if (state.qualityPreferences.contains('Regular')) {
                        state.qualityPreferences = ['Select'];
                      } else {
                        state.qualityPreferences = ['Select', 'Regular'];
                      }
                    } else if (val == 'Select') {
                      state.qualityPreferences = ['Select'];
                    }

                    // Update fees based on selection patterns
                    final prefs = state.qualityPreferences;
                    if (prefs.contains('Saver')) {
                      // Mode 1: All three
                      state.qualityFee = 0.0;
                    } else if (prefs.contains('Regular')) {
                      // Mode 2: Select + Regular
                      state.qualityFee = 0.05;
                    } else {
                      // Mode 3: Select only
                      state.qualityFee = 0.15;
                    }
                  });
                  _saveDraft(produce.id);

                  final qStr = state.qualityPreferences.join(', ');
                  DuruhaSnackBar.showInfo(context, "Quality updated to $qStr.");
                },
              ),
            ),
            const SizedBox(height: 8),
          ],

          // ── Per-date breakdown (plan mode) ───────────────────────────
          if (_isPlan && state.perDatePledgesMap.isNotEmpty) ...[
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                'Harvest Schedule',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.4,
                ),
              ),
            ),
            ...state.perDatePledgesMap.entries.map((entry) {
              final date = entry.key;
              final varieties = entry.value;
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('MMMM dd, yyyy').format(date),
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...varieties.entries.map(
                      (v) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              v.key,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              "${DuruhaFormatter.formatCompactNumber(v.value)} ${state.selectedUnit}",
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          // ── Variety breakdown ────────────────────────────────────────
          if (varietyBreakdown.isNotEmpty) ...[
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
                children: [
                  if (!_isPlan)
                    ...state.varietyGroups.map((group) {
                      final selectedInGroup = group
                          .where((v) => varietyBreakdown.containsKey(v))
                          .toList();
                      if (selectedInGroup.isEmpty) return const SizedBox();

                      final groupLabel = selectedInGroup.join(' || ');
                      final groupQty = selectedInGroup.fold(
                        0.0,
                        (sum, v) => sum + (varietyBreakdown[v] ?? 0),
                      );
                      final dDate =
                          state.varietyDateNeeded[selectedInGroup.first];
                      final vVariety = produce.varieties.firstWhere(
                        (v) => v.name == selectedInGroup.first,
                        orElse: () => produce.varieties.first,
                      );
                      final selectedFormId =
                          state.varietySelectedFormId[vVariety.name];
                      final listing =
                          vVariety.listings
                              .where((l) => l.listingId == selectedFormId)
                              .firstOrNull ??
                          (vVariety.listings.isNotEmpty
                              ? vVariety.listings.first
                              : null);
                      final vPrice = listing?.duruhaToConsumerPrice ?? 0.0;

                      // Determine if all selected varieties in the group have the same form name
                      String? commonFormName;
                      bool isCommon = true;
                      for (var vName in selectedInGroup) {
                        final v = produce.varieties.firstWhere(
                          (varie) => varie.name == vName,
                        );
                        final sfid = state.varietySelectedFormId[v.name];
                        final l =
                            v.listings
                                .where((list) => list.listingId == sfid)
                                .firstOrNull ??
                            (v.listings.isNotEmpty ? v.listings.first : null);
                        final fn = l?.produceForm ?? 'Raw';
                        if (commonFormName == null) {
                          commonFormName = fn;
                        } else if (commonFormName != fn) {
                          isCommon = false;
                          break;
                        }
                      }

                      return _buildVarietyRow(
                        theme,
                        state,
                        groupLabel,
                        groupQty,
                        dateNeeded: dDate,
                        pricePerUnit: vPrice,
                        formName: isCommon ? commonFormName : null,
                        priceLock:
                            state.varietyPriceLock[selectedInGroup.first] ??
                            false,
                        onPriceLockChanged: (val) {
                          setState(() {
                            state.varietyPriceLock[selectedInGroup.first] = val;
                          });
                          _saveDraft(produce.id);
                        },
                      );
                    }),
                  if (!_isPlan)
                    ...varietyBreakdown.entries
                        .where(
                          (e) => !state.varietyGroups.any(
                            (g) => g.contains(e.key),
                          ),
                        )
                        .map((e) {
                          final varietyKey = e.key;
                          final variety = produce.varieties.firstWhere(
                            (v) => v.name == varietyKey,
                            orElse: () => produce.varieties.first,
                          );
                          final selectedFormId =
                              state.varietySelectedFormId[varietyKey];
                          final listing =
                              variety.listings
                                  .where((l) => l.listingId == selectedFormId)
                                  .firstOrNull ??
                              (variety.listings.isNotEmpty
                                  ? variety.listings.first
                                  : null);
                          final vPrice = listing?.duruhaToConsumerPrice ?? 0.0;
                          final formName = listing?.produceForm ?? 'Raw';

                          return _buildVarietyRow(
                            theme,
                            state,
                            varietyKey,
                            e.value,
                            dateNeeded: state.varietyDateNeeded[varietyKey],
                            pricePerUnit: vPrice,
                            formName: formName,
                            priceLock:
                                state.varietyPriceLock[varietyKey] ?? false,
                            onPriceLockChanged: (val) {
                              setState(() {
                                state.varietyPriceLock[varietyKey] = val;
                              });
                              _saveDraft(produce.id);
                            },
                          );
                        }),
                  if (_isPlan)
                    ...varietyBreakdown.entries.map((e) {
                      final varietyKey = e.key;
                      final variety = produce.varieties.firstWhere(
                        (v) => v.name == varietyKey,
                        orElse: () => produce.varieties.first,
                      );
                      // In plan mode, we might not have form selection yet, but if we do...
                      final selectedFormId =
                          state.varietySelectedFormId[varietyKey];
                      final listing =
                          variety.listings
                              .where((l) => l.listingId == selectedFormId)
                              .firstOrNull ??
                          (variety.listings.isNotEmpty
                              ? variety.listings.first
                              : null);
                      final vPrice = listing?.duruhaToConsumerPrice ?? 0.0;
                      final formName = listing?.produceForm ?? 'Raw';

                      return _buildVarietyRow(
                        theme,
                        state,
                        varietyKey,
                        e.value,
                        dateNeeded: state.varietyDateNeeded[varietyKey],
                        pricePerUnit: vPrice,
                        formName: formName,
                        priceLock: state.varietyPriceLock[varietyKey] ?? false,
                        onPriceLockChanged: (val) {
                          setState(() {
                            state.varietyPriceLock[varietyKey] = val;
                          });
                          _saveDraft(produce.id);
                        },
                      );
                    }),
                ],
              ),
            ),
          ],

          // ── Pricing summary ──────────────────────────────────────────
          Divider(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildPricingRow(
                  theme,
                  label: 'Subtotal',
                  value: DuruhaFormatter.formatCurrency(subtotal),
                  isMain: false,
                ),
                const SizedBox(height: 6),
                _buildPricingRow(
                  theme,
                  label: 'Quality Fee (${(state.qualityFee * 100).toInt()}%)',
                  value:
                      '+ ${DuruhaFormatter.formatCurrency(qualityFeeAmount)}',
                  valueColor: theme.colorScheme.onTertiary,
                  isMain: false,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Divider(
                    height: 1,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.5,
                    ),
                  ),
                ),
                _buildPricingRow(
                  theme,
                  label: 'Total Price',
                  value: DuruhaFormatter.formatCurrency(totalAmount),
                  isMain: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Pricing Row ─────────────────────────────────────────────────────────────

  Widget _buildPricingRow(
    ThemeData theme, {
    required String label,
    required String value,
    Color? valueColor,
    required bool isMain,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

  // ─── Variety Row ─────────────────────────────────────────────────────────────

  Widget _buildVarietyRow(
    ThemeData theme,
    CropSelectionState state,
    String label,
    double quantity, {
    DateTime? dateNeeded,
    double? pricePerUnit,
    String? formName,
    bool priceLock = false,
    ValueChanged<bool>? onPriceLockChanged,
  }) {
    final double varietyTotal = (pricePerUnit ?? 0) * quantity;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (formName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    formName,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onTertiary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),

                if (!_isPlan && dateNeeded != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Needed ${DuruhaFormatter.formatDate(dateNeeded)}",
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
          if (!_isPlan && onPriceLockChanged != null) ...[
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 24,
                  width: 24,
                  child: Checkbox(
                    value: priceLock,
                    onChanged: (val) => onPriceLockChanged(val ?? false),
                    activeColor: theme.colorScheme.tertiary,
                    side: BorderSide(
                      color: theme.colorScheme.onTertiary,
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                Text(
                  "LOCK",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onTertiary,
                    fontWeight: FontWeight.w900,
                    fontSize: 8,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                label == "Any"
                    ? "${DuruhaFormatter.formatCurrency(varietyTotal)} est."
                    : DuruhaFormatter.formatCurrency(varietyTotal),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (pricePerUnit != null && pricePerUnit > 0)
                Text(
                  label == "Any"
                      ? "${DuruhaFormatter.formatCompactNumber(quantity)} ${state.selectedUnit} × ${DuruhaFormatter.formatCurrency(pricePerUnit)} est."
                      : "${DuruhaFormatter.formatCompactNumber(quantity)} ${state.selectedUnit} × ${DuruhaFormatter.formatCurrency(pricePerUnit)}",
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _applyQualityToAll(List<String> prefs, double fee) {
    setState(() {
      for (var entry in widget.cropStates.entries) {
        entry.value.qualityPreferences = List.from(prefs);
        entry.value.qualityFee = fee;
        _saveDraft(entry.key);
      }
    });
    DuruhaSnackBar.showInfo(
      context,
      "Applied ${prefs.join(', ')} quality to all items.",
    );
  }

  Future<void> _saveDraft(String cropId) async {
    final state = widget.cropStates[cropId];
    if (state == null) return;

    final Map<String, double> quantities = {};
    for (var entry in state.varietyQuantityControllers.entries) {
      final val = double.tryParse(entry.value.text);
      if (val != null && val > 0) {
        quantities[entry.key] = val;
      }
    }

    final draft = CropDraftData(
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
      qualityPreferences: state.qualityPreferences,
      qualityFee: state.qualityFee,
      varietySelectedFormId: state.varietySelectedFormId,
      varietyPriceLock: state.varietyPriceLock,
    );

    await TransactionDraftService.saveDraft(cropId, draft);
  }

  // ─── Quality Preference Note Dialog ────────────────────────────────++++++++

  void _showQualityPreferenceNote(BuildContext context, List<String> prefs) {
    final theme = Theme.of(context);
    String message = "";
    String title = "Quality Note";

    if (prefs.contains('Select') &&
        prefs.contains('Regular') &&
        prefs.contains('Saver')) {
      message =
          "Enjoy the full harvest! Including all qualities maximizes yield and saves sorting time. No extra fees apply.";
    } else if (prefs.contains('Select') && prefs.contains('Regular')) {
      title = "Premium Quality";
      message =
          "We will exclude 'Saver' items to provide a more consistent, high-quality batch. A 5% service fee applies.";
    } else if (prefs.contains('Select') && prefs.length == 1) {
      title = "Elite Selection";
      message =
          "Strictly the best of the best. Our team will hand-pick only top-tier produce for you. A 15% service fee applies.";
    } else {
      message =
          "We're tailoring your harvest based on your preferences to balance quality and cost.";
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.info_outline_rounded,
                color: theme.colorScheme.onPrimaryContainer,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Got it",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }
}
