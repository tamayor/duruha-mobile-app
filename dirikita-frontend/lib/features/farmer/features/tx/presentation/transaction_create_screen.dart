import 'package:duruha/core/widgets/duruha_widgets.dart';

import 'package:duruha/shared/produce/data/produce_repository.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../shared/domain/pledge_model.dart';
import 'crop_selection_state.dart';
import 'widgets/pledge_form.dart';
// import '../data/transaction_demand_repository.dart';
import 'widgets/offer_form.dart';
import '../data/transaction_draft_service.dart';
import 'transaction_review_screen.dart';

class TransactionCreateScreen extends StatefulWidget {
  final List<String> selectedCropIds;
  final String mode; // 'pledge' or 'offer'

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
  // final _demandRepository = TransactionDemandRepository();
  final _produceRepository = ProduceRepository();

  bool _isLoading = true;
  List<Produce> _selectedProduce = [];

  // Per-crop form state
  final Map<String, CropSelectionState> _cropStates = {};

  // Keys for scrolling to errors
  final Map<String, GlobalKey> _cropKeys = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      //debugPrint(
      //  "🔍 [TX CREATE] Loading data for IDs: ${widget.selectedCropIds}",
      //);
      if (widget.selectedCropIds.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final produce = await _produceRepository.fetchProduceByIds(
        widget.selectedCropIds,
        mode: "for_farmer",
      );
      debugPrint(
        "🎯 [TX CREATE] Fetched ${widget.selectedCropIds} matches from master view",
      );

      if (produce.isEmpty) {
        //debugPrint(
        //  "⚠️ [TX CREATE] MISMATCH! Selected IDs not found in master view.",
        //);
        if (mounted) {
          DuruhaSnackBar.showError(
            context,
            "Could not load crop details. Please try again or re-select crops.",
          );
        }
      }

      if (mounted) {
        setState(() {
          _selectedProduce = produce;
        });

        for (var produce in produce) {
          // Load draft if exists
          final draft = await TransactionDraftService.getDraft(produce.id);
          if (!mounted) return;

          final state = CropSelectionState(
            dateController: TextEditingController(),
            selectedUnit: draft?.selectedUnit ?? produce.unitOfMeasure,
            selectedVariants: [],
            varietyQuantityControllers: {},
          );

          if (draft != null) {
            state.varietyAvailableDates = draft.varietyAvailableDates;
            state.varietyDisposalDates = draft.varietyDisposalDates;

            // Migration: If old global dates exist, apply to all varieties
            if (state.varietyAvailableDates.isEmpty &&
                draft.availableDate != null) {
              for (var v in produce.availableVarieties) {
                state.varietyAvailableDates[v.name] = draft.availableDate;
              }
            }
            if (state.varietyDisposalDates.isEmpty &&
                draft.disposalDate != null) {
              for (var v in produce.availableVarieties) {
                state.varietyDisposalDates[v.name] = draft.disposalDate;
              }
            }

            if (draft.selectedHarvestDates.isNotEmpty) {
              state.selectedHarvestDates = draft.selectedHarvestDates;
              // Set text to summary
              final dates = state.selectedHarvestDates..sort();
              if (dates.length == 1) {
                state.dateController.text = DateFormat(
                  'MMM dd, yyyy',
                ).format(dates.first);
              } else {
                state.dateController.text = "${dates.length} dates selected";
              }
            }

            // Restore selected variants and controllers
            // MIGRATION: If we have perDatePledges in draft, load them.
            // If we have old varietyQuantities (from old draft format), maybe try to migrate or ignore?
            // Assuming we prefer perDatePledges now.
            if (draft.perDatePledges.isNotEmpty) {
              state.perDatePledges.addAll(draft.perDatePledges);
              // Also restore the demand map if present
              if (draft.dateSpecificDemand.isNotEmpty) {
                state.dateSpecificDemand.addAll(draft.dateSpecificDemand);
              }
            } else if (draft.varietyQuantities.isNotEmpty &&
                draft.selectedHarvestDates.isNotEmpty) {
              // Migration: Distribute old total across dates? Or just put on first date?
              // Let's put on first date to be safe.
              final firstDate = draft.selectedHarvestDates.first;
              draft.varietyQuantities.forEach((variety, qty) {
                state.perDatePledges.add(
                  HarvestEntry(
                    date: firstDate,
                    variety: variety,
                    quantity: qty,
                  ),
                );
              });
            }

            // Re-fetch demand if harvest dates are set (for pledge)
            if (widget.mode == 'pledge' &&
                state.selectedHarvestDates.isNotEmpty) {
              if (draft.simulatedDemand != null &&
                  draft.simulatedDemand!.isNotEmpty) {
                state.simulatedDemand = draft.simulatedDemand;
                state.isLoadingDemand = false;
                // Optionally fetch in background to update
                // _fetchAggregateDemand(produce.id, state.selectedHarvestDates);
              } else {
                // _fetchAggregateDemand(produce.id, state.selectedHarvestDates);
              }
            }
          }

          _cropStates[produce.id] = state;
          _cropKeys[produce.id] = GlobalKey();
        }

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ [TX CREATE] Error: $e");
      if (mounted) {
        DuruhaSnackBar.showError(
          context,
          "Error loading data: ${e.toString()}",
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // Save current state to draft
  Future<void> _saveDraft(String cropId) async {
    final state = _cropStates[cropId];
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
      simulatedDemand: state.simulatedDemand,
      perDatePledges: state.perDatePledges,
      dateSpecificDemand: state.dateSpecificDemand,
    );

    await TransactionDraftService.saveDraft(cropId, draft);
    if (!mounted) return;
  }

  Future<void> _clearAll() async {
    await TransactionDraftService.clearAll();

    if (mounted) {
      DuruhaSnackBar.showSuccess(context, "Drafts cleared");
      // Navigate to sales screen
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/farmer/sales', (route) => false);
    }
  }

  Future<void> _removeProduce(String produceId) async {
    await TransactionDraftService.clearDraft(produceId);
    if (!mounted) return;
    setState(() {
      _selectedProduce.removeWhere((p) => p.id == produceId);
      _cropStates.remove(produceId);
    });

    if (_selectedProduce.isEmpty) {
      // If no items left, maybe go back? Or just show empty state.
      // For now, staying on screen with empty message is fine,
      // effectively forcing user to go back or select more via other means if implemented.
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    for (var state in _cropStates.values) {
      state.dateController.dispose();
      for (var controller in state.varietyQuantityControllers.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  // _fetchAggregateDemand removed as we now use per-date DateDemandData logic
  // embedded in the repository and state.

  void _scrollToCrop(String cropId) {
    final key = _cropKeys[cropId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        alignment: 0.1, // Near the top
      );
    }
  }

  void _goToReview() {
    // Basic validation
    for (var produce in _selectedProduce) {
      final state = _cropStates[produce.id]!;

      if (widget.mode == 'pledge') {
        // 1. Filter out dates that don't have any pledges
        final validDates = state.selectedHarvestDates.where((date) {
          final normalized = DateTime(date.year, date.month, date.day);
          final breakdown = state.perDatePledgesMap[normalized];
          if (breakdown == null || breakdown.isEmpty) return false;
          final dateTotal = breakdown.values.fold(0.0, (sum, val) => sum + val);
          return dateTotal > 0;
        }).toList();

        // 2. Update the state with ONLY valid dates
        state.selectedHarvestDates = validDates;
        // Also filter perDatePledges list to match validDates
        state.perDatePledges.removeWhere(
          (e) => !validDates.any(
            (d) =>
                d.year == e.date.year &&
                d.month == e.date.month &&
                d.day == e.date.day,
          ),
        );

        // 3. Validation
        if (state.selectedHarvestDates.isEmpty) {
          DuruhaSnackBar.showWarning(
            context,
            "Please select harvest dates and enter pledge quantities for ${produce.nameEnglish}",
          );
          _scrollToCrop(produce.id);
          return;
        }
      } else {
        // Offer mode validation — based on the new offerEntries structure
        final entries = state.offerEntries;

        final hasAnyQty = entries.any((e) => e.quantity > 0);
        if (!hasAnyQty) {
          DuruhaSnackBar.showWarning(
            context,
            'Please select at least one form and enter a quantity for ${produce.nameEnglish}',
          );
          _scrollToCrop(produce.id);
          return;
        }

        // Check for missing dates when quantity is set
        final qtyMissingDate = entries.any((e) => e.quantity > 0 && !e.hasDate);
        if (qtyMissingDate) {
          DuruhaSnackBar.showWarning(
            context,
            'You entered a quantity but missing dates for ${produce.nameEnglish}. Please set them.',
          );
          _scrollToCrop(produce.id);
          return;
        }

        // Check for missing quantity when date is set
        final dateMissingQty = entries.any((e) => e.quantity == 0 && e.hasDate);
        if (dateMissingQty) {
          DuruhaSnackBar.showWarning(
            context,
            'You set dates but no quantity for a variety in ${produce.nameEnglish}.',
          );
          _scrollToCrop(produce.id);
          return;
        }
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

  @override
  Widget build(BuildContext context) {
    // Slivers list
    List<Widget> slivers = [];

    if (!_isLoading) {
      for (var p in _selectedProduce) {
        slivers.add(_buildStructuredCropSlivers(p));
      }
      // Add padding at bottom for FAB
      slivers.add(const SliverPadding(padding: EdgeInsets.only(bottom: 120)));
    }

    final modeTitle = widget.mode == 'pledge'
        ? 'Create Pledge'
        : 'Create Offer';
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_selectedProduce.map((p) => p.id).toList());
      },
      child: DuruhaScaffold(
        appBarTitle: modeTitle,
        onBackPressed: () {
          Navigator.of(context).pop(_selectedProduce.map((p) => p.id).toList());
        },
        appBarActions: [
          if (_selectedProduce.isNotEmpty && !_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Clear Draft',
              onPressed: () async {
                final confirm = await DuruhaDialog.show(
                  context: context,
                  title: "Clear Drafts?",
                  message: "This will clear all entered data for these crops.",
                  confirmText: "CLEAR",
                  isDanger: true,
                  icon: Icons.delete_sweep_rounded,
                );

                if (confirm == true) {
                  _clearAll();
                }
              },
            ),
        ],
        isLoading: _isLoading,
        body: _selectedProduce.isEmpty && !_isLoading
            ? const Center(child: Text("No crops selected"))
            : CustomScrollView(slivers: slivers),
        floatingActionButton: _selectedProduce.isNotEmpty && !_isLoading
            ? FloatingActionButton.extended(
                onPressed: _goToReview,
                backgroundColor: theme.colorScheme.tertiary,
                foregroundColor: theme.colorScheme.onTertiary,
                elevation: 8,
                label: _selectedProduce.isNotEmpty
                    ? Text("Continue")
                    : Text("Complete the Pledge"),
                icon: const Icon(Icons.chevron_right_rounded),
              )
            : null,
      ),
    );
  }

  // Returns a list of slivers for a single produce item:
  // 1. Sticky Header
  // 2. Form Content (Dates, Forecast)
  Widget _buildStructuredCropSlivers(Produce produce) {
    final theme = Theme.of(context);

    // Using SliverMainAxisGroup to keep the header sticky only within this group
    return SliverMainAxisGroup(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _ProduceHeaderDelegate(
            produce: produce,
            minHeight: 80,
            maxHeight: 80,
            theme: theme,
            onRemove: () => _removeProduce(produce.id),
          ),
        ),
        SliverToBoxAdapter(
          key: _cropKeys[produce.id],
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: DuruhaSectionContainer(
              isShrinkable: true,
              initialShrunk: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              title: widget.mode == 'pledge'
                  ? "Pledge Details"
                  : "Offer Details",
              subtitle: widget.mode == 'pledge'
                  ? "Enter harvest date and quantities"
                  : "Enter availability and quantities",
              children: [
                if (widget.mode == 'pledge')
                  PledgeForm(
                    produce: produce,
                    state: _cropStates[produce.id]!,
                    onDatesChanged: (dates, demandMap) {
                      final state = _cropStates[produce.id]!;
                      setState(() {
                        state.selectedHarvestDates = dates;
                        state.dateSpecificDemand =
                            demandMap; // Preserve the demand map!
                        // Update controller for simple display if needed, though PledgeForm handles its own input now
                        if (dates.length == 1) {
                          state.dateController.text = DateFormat(
                            'MMM dd, yyyy',
                          ).format(dates.first);
                        } else {
                          state.dateController.text =
                              "${dates.length} dates selected";
                        }
                      });
                      // _fetchAggregateDemand(produce.id, dates); // Removed
                      _saveDraft(produce.id);
                    },
                    onStateChanged: () => _saveDraft(produce.id),
                  )
                else
                  OfferForm(
                    produce: produce,
                    state: _cropStates[produce.id]!,
                    onAvailableDatePicked: (date) {
                      // Deprecated, OfferForm handles its own variety dates
                      _saveDraft(produce.id);
                    },
                    onDisposalDatePicked: (date) {
                      // Deprecated
                      _saveDraft(produce.id);
                    },
                    onStateChanged: () => _saveDraft(produce.id),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProduceHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Produce produce;
  final double minHeight;
  final double maxHeight;
  final ThemeData theme;
  final VoidCallback onRemove;

  _ProduceHeaderDelegate({
    required this.produce,
    required this.minHeight,
    required this.maxHeight,
    required this.theme,
    required this.onRemove,
  });

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: maxHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(
          alpha: 0.95,
        ), // Glassy effect
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              produce.imageThumbnailUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 48,
                height: 48,
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.eco_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  produce.nameEnglish,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (produce.nameScientific != null &&
                    produce.nameScientific!.isNotEmpty)
                  Text(
                    produce.nameScientific!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: Icon(
              Icons.remove_circle_outline_rounded,
              color: theme.colorScheme.error,
            ),
            tooltip: "Remove Crop",
          ),
        ],
      ),
    );
  }

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(covariant _ProduceHeaderDelegate oldDelegate) {
    return oldDelegate.produce != produce || oldDelegate.theme != theme;
  }
}
