import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/consumer/features/tx/presentation/widgets/faq_customer_order_note.dart';

import 'package:duruha/shared/produce/data/produce_repository.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'crop_selection_state.dart';
// import '../data/transaction_demand_repository.dart';
import 'widgets/order_form.dart';
import '../data/transaction_draft_service.dart';
import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/features/consumer/features/profile/data/profile_repository.dart';
import 'transaction_review_screen.dart';
import 'package:duruha/core/faq/faq.dart';

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
  final _profileRepository = ConsumerProfileRepositoryImpl();

  bool _isLoading = true;
  bool _isAllCompact = false;
  List<Produce> _selectedProduce = [];

  // Per-crop form state
  final Map<String, CropSelectionState> _cropStates = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      debugPrint(
        "🔍 [TX CREATE] Loading data for IDs: ${widget.selectedCropIds}",
      );
      if (widget.selectedCropIds.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final filtered = await _produceRepository.fetchProduceByIds(
        widget.selectedCropIds,
        mode: 'for_consumer',
      );
      debugPrint(
        "🎯 [TX CREATE] Fetched ${filtered.length} matches from master view",
      );

      // Determine default quality from user profile
      List<String> defaultQualities = ['Select', 'Regular'];
      double defaultQualityFee = 0.05;

      try {
        final userId = await SessionService.getUserId();
        if (userId != null) {
          final profile = await _profileRepository.getConsumerProfile(userId);
          final prefs = profile.qualityPreferences;

          if (prefs.isNotEmpty) {
            // Map profile preferences to our 3 hierarchical states
            if (prefs.contains('Saver') || prefs.length >= 3) {
              defaultQualities = ['Select', 'Regular', 'Saver'];
              defaultQualityFee = 0.0;
            } else if (prefs.contains('Regular') ||
                (prefs.contains('Select') && prefs.length == 2)) {
              defaultQualities = ['Select', 'Regular'];
              defaultQualityFee = 0.05;
            } else {
              defaultQualities = ['Select'];
              defaultQualityFee = 0.15;
            }
          }
        }
      } catch (e) {
        debugPrint("⚠️ [TX CREATE] Failed to fetch profile preferences: $e");
      }

      if (filtered.isEmpty) {
        debugPrint(
          "⚠️ [TX CREATE] MISMATCH! Selected IDs not found in master view.",
        );
        if (mounted) {
          DuruhaSnackBar.showError(
            context,
            "Could not load crop details. Please try again or re-select crops.",
          );
        }
      }

      if (mounted) {
        setState(() {
          _selectedProduce = filtered;
        });

        for (var produce in filtered) {
          // Load draft if exists
          final draft = await TransactionDraftService.getDraft(produce.id);

          final state = CropSelectionState(
            dateController: TextEditingController(),
            selectedUnit: draft?.selectedUnit ?? produce.unitOfMeasure,
            selectedVariants: [],
            varietyQuantityControllers: {},
            varietySelectedFormId: {},
            varietyPriceLock: {},
          );

          // Apply profile-based quality defaulting if no draft quality exists
          // Note: TransactionDraftData doesn't have quality yet, but for now we set it here.
          state.qualityPreferences = List.from(defaultQualities);
          state.qualityFee = defaultQualityFee;

          if (draft != null) {
            state.varietyAvailableDates = Map.from(draft.varietyAvailableDates);
            state.varietyDisposalDates = Map.from(draft.varietyDisposalDates);
            state.varietyDateNeeded = Map.from(draft.varietyDateNeeded);

            if (draft.qualityPreferences != null &&
                draft.qualityPreferences!.isNotEmpty) {
              state.qualityPreferences = List.from(draft.qualityPreferences!);
              state.qualityFee = draft.qualityFee ?? 0.0;
            }

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
              state.selectedHarvestDates = List.from(
                draft.selectedHarvestDates,
              );
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
              state.perDatePledges.addAll(List.from(draft.perDatePledges));
              // Also restore the demand map if present
              if (draft.dateSpecificDemand.isNotEmpty) {
                state.dateSpecificDemand.addAll(
                  Map.from(draft.dateSpecificDemand),
                );
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
            } else if (draft.varietyQuantities.isNotEmpty) {
              // Restoration for Order/Offer mode (not per-date)
              state.selectedVariants = draft.varietyQuantities.keys.toList();
              for (var entry in draft.varietyQuantities.entries) {
                state.varietyQuantityControllers[entry.key] =
                    TextEditingController(
                      text: entry.value
                          .toStringAsFixed(2)
                          .replaceAll(RegExp(r'\.00$'), ''),
                    );
              }
            }

            // Restore form selections
            state.varietySelectedFormId = Map.from(draft.varietySelectedFormId);
            state.varietyPriceLock = Map.from(draft.varietyPriceLock);

            // Restore variety groups
            state.varietyGroups = draft.varietyGroups
                .map((g) => Set<String>.from(g))
                .toList();

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
      varietyDateNeeded: state.varietyDateNeeded,
      varietyGroups: state.varietyGroups,
      simulatedDemand: state.simulatedDemand,
      perDatePledges: state.perDatePledges,
      dateSpecificDemand: state.dateSpecificDemand,
      qualityPreferences: state.qualityPreferences,
      qualityFee: state.qualityFee,
      varietySelectedFormId: state.varietySelectedFormId,
    );

    await TransactionDraftService.saveDraft(cropId, draft);
  }

  Future<void> _clearAll() async {
    await TransactionDraftService.clearAll();

    if (mounted) {
      DuruhaSnackBar.showSuccess(context, "Drafts cleared");
      // Navigate to sales screen
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil('/consumer/shop', (route) => false);
    }
  }

  Future<void> _removeProduce(String produceId) async {
    await TransactionDraftService.clearDraft(produceId);
    setState(() {
      _selectedProduce.removeWhere((p) => p.id == produceId);
      _cropStates.remove(produceId);
    });

    if (_selectedProduce.isEmpty) {
      // If no items left, maybe go back? Or just show empty state.
      // For now, staying on screen with empty message is fine,
      // effectively forcing user to go back or select more via other means if implemented.
      if (mounted) Navigator.of(context).pop();
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

  void _goToReview() {
    // Basic validation
    for (var produce in _selectedProduce) {
      final state = _cropStates[produce.id]!;

      if (state.validationErrors.isNotEmpty) {
        DuruhaSnackBar.showWarning(
          context,
          "Please fix quantity errors for ${produce.nameEnglish}. Some items exceed available stock.",
        );
        return;
      }

      // Calculate total quantity from ALL controllers (for Offer) OR per-date (for Pledge)
      double total = 0;

      if (widget.mode == 'plan') {
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
          return;
        }

        // Re-calculate total based on filtered dates
        total = 0;
        for (var date in state.selectedHarvestDates) {
          final normalized = DateTime(date.year, date.month, date.day);
          final breakdown = state.perDatePledgesMap[normalized];
          if (breakdown != null) {
            total += breakdown.values.fold(0.0, (sum, val) => sum + val);
          }
        }
      } else if (widget.mode == 'offer') {
        // Offer mode validation
        bool allDatesSet = true;
        for (var entry in state.varietyQuantityControllers.entries) {
          final qty = double.tryParse(entry.value.text) ?? 0;
          if (qty > 0) {
            total += qty;
            final vName = entry.key;
            if (state.varietyAvailableDates[vName] == null ||
                state.varietyDisposalDates[vName] == null) {
              allDatesSet = false;
              break;
            }
          }
        }

        if (total <= 0) {
          DuruhaSnackBar.showWarning(
            context,
            "Please set quantity for selected varieties of ${produce.nameEnglish}",
          );
          return;
        }

        if (!allDatesSet) {
          DuruhaSnackBar.showWarning(
            context,
            "Please set availability dates for all varieties with quantities in ${produce.nameEnglish}",
          );
          return;
        }
      } else if (widget.mode == 'order') {
        // Order mode validation: check variety-level quantities and delivery dates
        bool anyQuantity = false;
        bool allDatesSet = true;

        for (var entry in state.varietyQuantityControllers.entries) {
          final qty = double.tryParse(entry.value.text) ?? 0;
          if (qty > 0) {
            anyQuantity = true;
            final key = entry.key;
            if (state.varietyDateNeeded[key] == null) {
              allDatesSet = false;
              break;
            }
          }
        }

        if (!anyQuantity) {
          DuruhaSnackBar.showWarning(
            context,
            "Please enter a quantity for at least one variety of ${produce.nameEnglish}",
          );
          return;
        }

        if (!allDatesSet) {
          DuruhaSnackBar.showWarning(
            context,
            "Please set delivery dates for all items in your ${produce.nameEnglish} order",
          );
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

    final modeTitle = (widget.mode == 'pledge' || widget.mode == 'plan')
        ? 'Plan Order' // Changed from 'Create Pledge' to generic 'Plan Order' or keep specific?
        // User asked for 'Plan Mode', so 'Plan Order' or 'Create Pledge' (backend term).
        // Let's use 'Plan Order' as per UI toggle.
        : (widget.mode == 'order' ? 'Create Order' : 'Create Offer');
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
          IconButton(
            icon: Icon(_isAllCompact ? Icons.unfold_more : Icons.unfold_less),
            onPressed: () {
              setState(() {
                _isAllCompact = !_isAllCompact;
              });
            },
            tooltip: _isAllCompact ? 'Expand All' : 'Collapse All',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'How Orders Work',
            onPressed: () => DuruhaFaqModal.show(context, faqCustomerOrderNote),
          ),
          if (_selectedProduce.isNotEmpty && !_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Clear Draft',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Clear Drafts?"),
                    content: const Text(
                      "This will clear all entered data for these crops.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          "Cancel",
                          style: TextStyle(color: theme.colorScheme.onPrimary),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(
                          "Clear",
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                  ),
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
      title: Text(produce.nameEnglish),
      subtitle:
          (produce.nameScientific != null && produce.nameScientific!.isNotEmpty)
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
        tooltip: "Remove Crop",
      ),
      content: DuruhaSectionContainer(
        title: (widget.mode == 'pledge' || widget.mode == 'plan')
            ? "Plan Details"
            : (widget.mode == 'order' ? "Order Details" : "Offer Details"),
        subtitle: (widget.mode == 'pledge' || widget.mode == 'plan')
            ? "Enter harvest date and quantities"
            : (widget.mode == 'order'
                  ? "Enter needed date and quantities"
                  : "Enter availability and quantities"),
        children: [
          OrderForm(
            produce: produce,
            state: state,
            onAvailableDatePicked: (date) => _saveDraft(produce.id),
            onDisposalDatePicked: (date) => _saveDraft(produce.id),
            onStateChanged: () => _saveDraft(produce.id),
          ),
        ],
      ),
    );
  }
}
