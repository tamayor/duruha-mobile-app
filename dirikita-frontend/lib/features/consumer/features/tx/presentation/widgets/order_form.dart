import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:flutter/material.dart';
import 'package:duruha/shared/produce/domain/produce_variety.dart';
import '../crop_selection_state.dart';
import 'package:duruha/features/consumer/features/tx/presentation/widgets/recurring_picker.dart';

class OrderForm extends StatefulWidget {
  final Produce produce;
  final CropSelectionState state;
  final Function(DateTime) onAvailableDatePicked;
  final Function(DateTime) onDisposalDatePicked;
  final VoidCallback onStateChanged;
  final VoidCallback? onProduceChanged;
  final String mode;
  final DateTime? planStartDate;
  final DateTime? planEndDate;

  const OrderForm({
    super.key,
    required this.produce,
    required this.state,
    required this.onAvailableDatePicked,
    required this.onDisposalDatePicked,
    required this.onStateChanged,
    this.onProduceChanged,
    this.mode = 'order',
    this.planStartDate,
    this.planEndDate,
  });

  @override
  State<OrderForm> createState() => _OrderFormState();
}

class _OrderFormState extends State<OrderForm> {
  final Set<String> _selectedVarieties = {};
  final List<Set<String>> _groups = [];
  final Map<int, TextEditingController> _groupControllers = {};

  @override
  void initState() {
    super.initState();

    // Initialize state based on passed props if any (e.g. returning to screen)
    if (widget.state.selectedVariants.isNotEmpty) {
      _selectedVarieties.addAll(widget.state.selectedVariants);
    }

    // Restore groups
    if (widget.state.varietyGroups.isNotEmpty) {
      _groups.addAll(
        widget.state.varietyGroups.map((g) => Set<String>.from(g)),
      );
      // Initialize group controllers: the group quantity equals the quantity
      // of any one member (they all share the same value after the fix).
      for (int i = 0; i < _groups.length; i++) {
        final group = _groups[i];
        // Read the qty from the first member — all members store the full qty
        final firstMember = group.isNotEmpty ? group.first : null;
        final firstController = firstMember != null
            ? widget.state.varietyQuantityControllers[firstMember]
            : null;
        final groupQty = double.tryParse(firstController?.text ?? '') ?? 0;

        _groupControllers[i] = TextEditingController(
          text: groupQty > 0
              ? groupQty.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')
              : '',
        );
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _groupControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onVarietyToggled(String variety) {
    setState(() {
      if (variety == "Any") {
        if (_selectedVarieties.contains("Any")) {
          _selectedVarieties.remove("Any");
        } else {
          // Check if there is ANY supply at all (only enforce in non-plan mode)
          if (widget.mode != 'plan') {
            final hasAnySupply = widget.produce.availableVarieties.any(
              (v) => v.total30DaysQuantity > 0,
            );
            if (!hasAnySupply) {
              DuruhaSnackBar.showWarning(
                context,
                "You can't buy this because there is no supply for any variety.",
              );
              return;
            }
          }

          // Selecting "Any" clears everything else
          _selectedVarieties.clear();
          _selectedVarieties.add("Any");
          // Clear groups
          for (var controller in _groupControllers.values) {
            controller.dispose();
          }
          _groups.clear();
          _groupControllers.clear();
        }
      } else {
        if (_selectedVarieties.contains(variety)) {
          _selectedVarieties.remove(variety);
          // Remove from groups if present
          for (var i = 0; i < _groups.length; i++) {
            if (_groups[i].contains(variety)) {
              _groups[i].remove(variety);
              if (_groups[i].length < 2) {
                // Ungroup if only 1 left
                _groups.removeAt(i);
                _groupControllers[i]?.dispose();
                _groupControllers.remove(i);
              }
              break;
            }
          }
        } else {
          // Check for individual variety supply (only enforce in non-plan mode)
          if (widget.mode != 'plan') {
            final varietyObj = widget.produce.availableVarieties.firstWhere(
              (v) => v.name == variety,
              orElse: () => widget.produce.availableVarieties.first,
            );
            if (varietyObj.total30DaysQuantity <= 0) {
              DuruhaSnackBar.showWarning(
                context,
                "You can't buy this because there is no supply for $variety.",
              );
              return;
            }
          }

          // Selecting a specific variety removes "Any"
          _selectedVarieties.remove("Any");
          _selectedVarieties.add(variety);
        }
      }
      _syncToState();
    });
  }

  void _syncToState() {
    // 1. Update state.selectedVariants
    widget.state.selectedVariants = _selectedVarieties.toList();

    // 2. Clear only quantities for varieties that are NO LONGER selected
    // (This avoids ghosts if varieties were removed while keeping inputs alive)
    final existingKeys = widget.state.varietyQuantityControllers.keys.toList();
    for (var v in existingKeys) {
      if (!_selectedVarieties.contains(v) &&
          !_groups.any((g) => g.contains(v))) {
        widget.state.varietyQuantityControllers[v]?.text = "";

        // Also wipe any lingering recurrence data to prevent ghosts
        widget.state.varietyRecurrence.remove(v);
        widget.state.varietyRecurrence.remove('qty_$v');
      }
    }

    // 3. Handle Regular Varieties (not in any group)
    final groupedVarieties = _groups.expand((g) => g).toSet();
    for (var v in _selectedVarieties) {
      if (!groupedVarieties.contains(v)) {
        if (!widget.state.varietyQuantityControllers.containsKey(v)) {
          widget.state.varietyQuantityControllers[v] = TextEditingController();
        }
      }
    }

    final ungroupedVarieties = _selectedVarieties
        .where((v) => !groupedVarieties.contains(v))
        .toList();

    // 4. Handle Grouped Varieties (distribute group qty)
    for (var i = 0; i < _groups.length; i++) {
      final group = _groups[i];
      final controller = _groupControllers[i];
      if (controller == null) continue;

      final totalQty = double.tryParse(controller.text) ?? 0;

      // Validation for group
      double groupMax = 0;
      for (var vName in group) {
        final variety = widget.produce.availableVarieties.firstWhere(
          (av) => av.name == vName,
          orElse: () => widget.produce.availableVarieties.first,
        );
        groupMax += variety.total30DaysQuantity;
      }

      if (totalQty > groupMax) {
        widget.state.validationErrors['group_$i'] =
            "Max available: ${groupMax.toInt()}";
      } else {
        widget.state.validationErrors.remove('group_$i');
      }

      if (totalQty > 0) {
        final groupList = group.toList();

        for (final v in groupList) {
          if (!widget.state.varietyQuantityControllers.containsKey(v)) {
            widget.state.varietyQuantityControllers[v] =
                TextEditingController();
          }
          // Each member gets the FULL group quantity — the group means
          // "any of these varieties, each at this quantity".
          widget.state.varietyQuantityControllers[v]!.text = totalQty
              .toStringAsFixed(2)
              .replaceAll(RegExp(r'\.00$'), '');
        }
      }
    }

    // 4b. Validation for Ungrouped
    for (var v in ungroupedVarieties) {
      final controller = widget.state.varietyQuantityControllers[v];
      if (controller == null) continue;

      final val = double.tryParse(controller.text) ?? 0;
      double maxForThis;

      if (v == "Any") {
        maxForThis = widget.produce.availableVarieties.fold(
          0.0,
          (sum, av) => sum + av.total30DaysQuantity,
        );
      } else {
        final variety = widget.produce.availableVarieties.firstWhere(
          (av) => av.name == v,
          orElse: () => widget.produce.availableVarieties.first,
        );
        maxForThis = variety.total30DaysQuantity;
      }

      if (val > maxForThis) {
        widget.state.validationErrors['qty_$v'] =
            "Exceeds max available (${maxForThis.toInt()})";
      } else {
        widget.state.validationErrors.remove('qty_$v');
      }
    }

    // 5. Ensure dates exist for ALL selected varieties
    for (var v in _selectedVarieties) {
      if (!widget.state.varietyAvailableDates.containsKey(v)) {
        widget.state.varietyAvailableDates[v] = DateTime.now();
      }
      if (!widget.state.varietyDisposalDates.containsKey(v)) {
        widget.state.varietyDisposalDates[v] = DateTime.now().add(
          const Duration(days: 30),
        );
      }
      if (!widget.state.varietyDateNeeded.containsKey(v)) {
        widget.state.varietyDateNeeded[v] = DateTime.now().add(
          Duration(days: widget.mode == 'plan' ? 21 : 7),
        );
      }
    }

    // 6. Update variety groups in state for persistence
    widget.state.varietyGroups = _groups
        .map((g) => Set<String>.from(g))
        .toList();

    widget.onStateChanged();
  }

  Future<void> _selectDeliveryDate(String key) async {
    final now = DateTime.now();
    final threeWeeksFromNow = now.add(const Duration(days: 21));
    final isPlan = widget.mode == 'plan';
    final picked = await showDatePicker(
      context: context,
      initialDate:
          widget.state.varietyDateNeeded[key] ??
          (isPlan ? threeWeeksFromNow : now.add(const Duration(days: 7))),
      firstDate: isPlan ? threeWeeksFromNow : now,
      lastDate: now.add(Duration(days: isPlan ? 180 : 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Theme.of(context).colorScheme.onPrimary,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
            datePickerTheme: DatePickerThemeData(
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.1);
                }
                return null;
              }),
              yearForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) {
                  return Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.1);
                }
                return null;
              }),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (key.startsWith('group_')) {
          // If it's a group, apply to all members for consistency in state
          // but mainly we track by the key used in group input
          widget.state.varietyDateNeeded[key] = picked;
          final groupIndex = int.parse(key.replaceFirst('group_', ''));
          for (var v in _groups[groupIndex]) {
            widget.state.varietyDateNeeded[v] = picked;
          }
        } else {
          final vName = key.replaceFirst('qty_', '');
          widget.state.varietyDateNeeded[vName] = picked;
          widget.state.varietyDateNeeded[key] = picked;
        }
        _syncToState();
      });
    }
  }

  void _applyDateToAll(DateTime picked) {
    setState(() {
      // 1. Apply to all possible varieties
      for (var v in widget.produce.availableVarieties) {
        widget.state.varietyDateNeeded[v.name] = picked;
        widget.state.varietyDateNeeded['qty_${v.name}'] = picked;
      }

      // 2. Apply to all active groups
      for (int i = 0; i < _groups.length; i++) {
        final groupKey = 'group_$i';
        widget.state.varietyDateNeeded[groupKey] = picked;
        for (var member in _groups[i]) {
          widget.state.varietyDateNeeded[member] = picked;
        }
      }

      _syncToState();
    });
    DuruhaSnackBar.showSuccess(
      context,
      "Applied delivery date to all selected items!",
    );
  }

  void _ungroup(int groupIndex) {
    setState(() {
      final prevMembers = _groups[groupIndex];
      _groups.removeAt(groupIndex);
      _groupControllers[groupIndex]?.dispose();
      _groupControllers.remove(groupIndex);

      // Clean up grouping recurrence state
      widget.state.varietyRecurrence.remove('group_$groupIndex');
      for (var v in prevMembers) {
        widget.state.varietyRecurrence.remove(v);
        widget.state.varietyRecurrence.remove('qty_$v');
      }

      _syncToState();
    });
  }

  void _createGroup(String v1, String v2) {
    setState(() {
      final newGroup = {v1, v2};
      _groups.add(newGroup);
      final index = _groups.length - 1;
      _groupControllers[index] = TextEditingController();

      // Clear any individual recurrences as they are now grouped
      for (var v in newGroup) {
        widget.state.varietyRecurrence.remove(v);
        widget.state.varietyRecurrence.remove('qty_$v');
      }

      _syncToState();
    });
  }

  void _addToGroup(int groupIndex, String variety) {
    setState(() {
      _groups[groupIndex].add(variety);

      // Clear individual recurrence as it joined a group
      widget.state.varietyRecurrence.remove(variety);
      widget.state.varietyRecurrence.remove('qty_$variety');

      _syncToState();
    });
  }

  void _removeFromGroup(int groupIndex, String variety) {
    setState(() {
      _groups[groupIndex].remove(variety);

      // Clear its recurrence just in case so it starts fresh
      widget.state.varietyRecurrence.remove(variety);
      widget.state.varietyRecurrence.remove('qty_$variety');

      if (_groups[groupIndex].length < 2) {
        _ungroup(groupIndex);
      } else {
        _syncToState();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final sortedVarieties =
        List<ProduceVariety>.from(widget.produce.availableVarieties)
          ..sort((a, b) {
            // Primary: Most offers (total30DaysQuantity) DESC
            final qtyCompare = b.total30DaysQuantity.compareTo(
              a.total30DaysQuantity,
            );
            if (qtyCompare != 0) return qtyCompare;
            // Secondary: Alphabetical ASC
            return a.name.compareTo(b.name);
          });

    final options = sortedVarieties.map((v) => v.name).toList();

    final Map<String, String> optionSubtitles = {};
    double absoluteMinPrice = double.infinity;
    double absoluteMaxPrice = -double.infinity;

    for (var v in sortedVarieties) {
      double minP = double.infinity;
      double maxP = -double.infinity;
      for (var l in v.listings) {
        if (l.duruhaToConsumerPrice < minP) minP = l.duruhaToConsumerPrice;
        if (l.duruhaToConsumerPrice > maxP) maxP = l.duruhaToConsumerPrice;
      }

      if (minP != double.infinity && minP < absoluteMinPrice) {
        absoluteMinPrice = minP;
      }
      if (maxP != -double.infinity && maxP > absoluteMaxPrice) {
        absoluteMaxPrice = maxP;
      }

      String priceStr = "";
      if (minP != double.infinity && maxP != -double.infinity) {
        priceStr = minP == maxP
            ? "₱${minP.toStringAsFixed(2)} / ${widget.state.selectedUnit}"
            : "₱${minP.toStringAsFixed(2)} - ₱${maxP.toStringAsFixed(2)} / ${widget.state.selectedUnit}";
      }

      if (widget.mode == 'plan') {
        optionSubtitles[v.name] = priceStr;
      } else {
        String stockStr = v.total30DaysQuantity > 0
            ? "${v.total30DaysQuantity.toInt()} ${widget.produce.baseUnit} available"
            : "No offers yet";
        optionSubtitles[v.name] = [
          priceStr,
          stockStr,
        ].where((s) => s.isNotEmpty).join(' • ');
      }
    }

    String anyPriceStr = "";
    if (absoluteMinPrice != double.infinity &&
        absoluteMaxPrice != -double.infinity) {
      anyPriceStr = absoluteMinPrice == absoluteMaxPrice
          ? "₱${absoluteMinPrice.toStringAsFixed(2)} / ${widget.state.selectedUnit}"
          : "₱${absoluteMinPrice.toStringAsFixed(2)} - ₱${absoluteMaxPrice.toStringAsFixed(2)} / ${widget.state.selectedUnit}";
    }

    optionSubtitles["Any"] = [
      anyPriceStr,
      "Any variety",
    ].where((s) => s.isNotEmpty).join(' • ');

    final groupedVarieties = _groups.expand((g) => g).toSet();
    final ungroupedVarieties = _selectedVarieties
        .where((v) => !groupedVarieties.contains(v))
        .toList();

    // Sort ungroupedVarieties based on the sortedVarieties order
    ungroupedVarieties.sort((a, b) {
      final indexA = sortedVarieties.indexWhere((v) => v.name == a);
      final indexB = sortedVarieties.indexWhere((v) => v.name == b);
      return indexA.compareTo(indexB);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Variety Selection
        DuruhaSelectionChipGroup(
          title: "Variety Preference",
          subtitle: "Choose the specific varieties you need.",
          options: ["Any", ...options],
          optionSubtitles: optionSubtitles,
          selectedValues: _selectedVarieties.toList(),
          onToggle: _onVarietyToggled,
          isRequired: true,
          limit: 3,
          isNumbered: true,
          layout: SelectionLayout.wrap,
        ),

        const SizedBox(height: 24),

        // 2. Quantity Inputs
        if (_selectedVarieties.isNotEmpty) ...[
          Text(
            "Specify Quantities",
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),

          // Render Grouped Inputs
          ..._groups.asMap().entries.map((entry) {
            final groupIndex = entry.key;
            final group = entry.value;
            final controller = _groupControllers[groupIndex];
            if (controller == null) return const SizedBox.shrink();

            // Calculate max for group
            double groupMax = 0;
            for (var vName in group) {
              final variety = widget.produce.availableVarieties.firstWhere(
                (av) => av.name == vName,
                orElse: () => widget.produce.availableVarieties.first,
              );
              groupMax += variety.total30DaysQuantity;
            }

            return _buildInputWithMenu(
              key: 'group_$groupIndex',
              controller: controller,
              label: "Group ${groupIndex + 1}",
              subLabels: group.toList(),
              colorScheme: colorScheme,
              maxQuantity: groupMax,
              helperText: "Max: ${groupMax.toInt()} ${widget.produce.baseUnit}",
              errorText: widget.state.validationErrors['group_$groupIndex'],
              menuActions: [
                ...group.map((variety) => 'remove_$variety'),
                'ungroup',
              ],
            );
          }),

          // Render Ungrouped Inputs
          ...ungroupedVarieties.map((vName) {
            final controller = widget.state.varietyQuantityControllers[vName];
            if (controller == null) return const SizedBox.shrink();

            double maxForThis;
            if (vName == "Any") {
              maxForThis = widget.produce.availableVarieties.fold(
                0.0,
                (sum, av) => sum + av.total30DaysQuantity,
              );
            } else {
              final varietyObj = widget.produce.availableVarieties.firstWhere(
                (av) => av.name == vName,
                orElse: () => widget.produce.availableVarieties.first,
              );
              maxForThis = varietyObj.total30DaysQuantity;
            }

            return _buildInputWithMenu(
              key: 'qty_$vName',
              controller: controller,
              label: "$vName Qty.",
              variety: vName == "Any"
                  ? null
                  : widget.produce.availableVarieties.firstWhere(
                      (av) => av.name == vName,
                      orElse: () => widget.produce.availableVarieties.first,
                    ),
              colorScheme: colorScheme,
              maxQuantity: maxForThis,
              helperText:
                  "Max: ${maxForThis.toInt()} ${widget.produce.baseUnit}",
              errorText: widget.state.validationErrors['qty_$vName'],
              menuActions: [
                if (ungroupedVarieties.length > 1)
                  ...ungroupedVarieties
                      .where((v) => v != vName)
                      .map((other) => 'group_with_$other'),
                if (_groups.isNotEmpty)
                  ..._groups.asMap().entries.map(
                    (groupEntry) => 'add_to_group_${groupEntry.key}',
                  ),
                if (ungroupedVarieties.length <= 1 && _groups.isEmpty)
                  'no_options',
              ],
            );
          }),
        ],
      ],
    );
  }

  Widget _buildInputWithMenu({
    required String key,
    required TextEditingController controller,
    required String label,
    required ColorScheme colorScheme,
    required List<String> menuActions,
    ProduceVariety? variety,
    double? maxQuantity,
    String? errorText,
    String? helperText,
    List<String>? subLabels,
  }) {
    final theme = Theme.of(context);
    final dateNeeded =
        widget.state.varietyDateNeeded[key] ??
        DateTime.now().add(const Duration(days: 7));

    // Form Selection Logic
    final vName = variety?.name ?? "Any";
    final listings = variety?.listings ?? [];
    final selectedFormId = widget.state.varietySelectedFormId[vName];

    // Auto-select first in-stock form if none selected and listings exist
    if (selectedFormId == null && listings.isNotEmpty) {
      final availableListing = listings.firstWhere(
        (l) => l.remainingQuantity > 0,
        orElse: () => listings.first,
      );
      widget.state.varietySelectedFormId[vName] = availableListing.listingId;
    }

    // Price Range Calculation
    double minPrice = double.infinity;
    double maxPrice = -double.infinity;

    List<ProduceVariety> targetVarieties = [];
    if (key.startsWith('group_')) {
      final groupIndex = int.parse(key.replaceFirst('group_', ''));
      final groupNames = _groups[groupIndex];
      targetVarieties = widget.produce.availableVarieties
          .where((v) => groupNames.contains(v.name))
          .toList();
    } else if (key == 'qty_Any') {
      targetVarieties = widget.produce.availableVarieties;
    } else if (variety != null) {
      targetVarieties = [variety];
    }

    for (var v in targetVarieties) {
      final selectedId = widget.state.varietySelectedFormId[v.name];
      final currentListings = v.listings;
      double vPrice = 0.0;

      if (currentListings.isNotEmpty) {
        vPrice = (currentListings.firstWhere(
          (l) => l.listingId == selectedId,
          orElse: () => currentListings.first,
        )).duruhaToConsumerPrice;
      } else {
        vPrice = 0.0;
      }

      if (vPrice < minPrice) minPrice = vPrice;
      if (vPrice > maxPrice) maxPrice = vPrice;
    }

    if (targetVarieties.isEmpty) {
      minPrice = 0.0;
      maxPrice = 0.0;
    }

    // Common Forms Logic
    Set<String>? commonForms;
    if (targetVarieties.isNotEmpty) {
      for (var v in targetVarieties) {
        final vForms = v.listings.map((l) => l.produceForm ?? 'Raw').toSet();
        if (commonForms == null) {
          commonForms = vForms;
        } else {
          commonForms = commonForms.intersection(vForms);
        }
      }
    }
    final hasCommonForms = commonForms != null && commonForms.isNotEmpty;

    // Aggregate stock for common forms
    final Map<String, double> commonFormQuantities = {};
    if (hasCommonForms) {
      for (var fName in commonForms) {
        double fStock = 0;
        for (var v in targetVarieties) {
          final listing = v.listings.firstWhere(
            (l) => (l.produceForm ?? 'Raw') == fName,
            orElse: () => v.listings.first,
          );
          fStock += listing.remainingQuantity;
        }
        commonFormQuantities[fName] = fStock;
      }
    }

    final isSelectionGroup = targetVarieties.length > 1;

    // Auto-select first in-stock common form if none selected
    if (hasCommonForms && widget.state.varietySelectedFormId[vName] == null) {
      final availableForm = commonForms.firstWhere(
        (f) => (commonFormQuantities[f] ?? 0) > 0,
        orElse: () => commonForms!.first,
      );

      for (var v in targetVarieties) {
        if (widget.state.varietySelectedFormId[v.name] == null) {
          final matchingListing = v.listings.firstWhere(
            (l) => (l.produceForm ?? 'Raw') == availableForm,
            orElse: () => v.listings.first,
          );
          widget.state.varietySelectedFormId[v.name] =
              matchingListing.listingId;
        }
      }

      if (key == 'qty_Any') {
        widget.state.varietySelectedFormId['Any'] = availableForm;
      }
    }

    // Handle form selection for a group/multi-variety
    void toggleGroupForm(String formName) {
      setState(() {
        for (var v in targetVarieties) {
          final matchingListing = v.listings.firstWhere(
            (l) => (l.produceForm ?? 'Raw') == formName,
            orElse: () => v.listings.first,
          );
          widget.state.varietySelectedFormId[v.name] =
              matchingListing.listingId;
        }

        if (key == 'qty_Any') {
          widget.state.varietySelectedFormId['Any'] = formName;
        }
        _syncToState();
      });
    }

    // Labeling for varieties with no common forms
    String buildSpecificLabeling() {
      if (targetVarieties.length <= 1) return "";
      return targetVarieties
          .map((v) {
            final forms = v.listings
                .map((l) => l.produceForm ?? 'Raw')
                .join(', ');
            return "${v.name}: ($forms)";
          })
          .join("; ");
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: colorScheme.outlineVariant, thickness: 2),
          if (subLabels != null && subLabels.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                Text(
                  "Any in",
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                ...subLabels.map((v) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      v,
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],

          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: DuruhaTextField(
                  label: label,
                  icon: Icons.scale_rounded,
                  suffix: widget.state.selectedUnit,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  key: ValueKey(key),
                  controller: controller,
                  onChanged: (_) => _syncToState(),
                  helperText: (() {
                    // Find stock for selected form
                    double currentStock = 0;
                    if (isSelectionGroup && hasCommonForms) {
                      // Sum of stock for the common form across group
                      final firstV = targetVarieties.first;
                      final sid =
                          widget.state.varietySelectedFormId[firstV.name];
                      final fName =
                          firstV.listings
                              .firstWhere(
                                (l) => l.listingId == sid,
                                orElse: () => firstV.listings.first,
                              )
                              .produceForm ??
                          'Raw';
                      currentStock = commonFormQuantities[fName] ?? 0;
                    } else if (targetVarieties.isNotEmpty) {
                      // Single variety (or Any) stock for its selected form
                      for (var v in targetVarieties) {
                        final sid = widget.state.varietySelectedFormId[v.name];
                        final listing = v.listings.firstWhere(
                          (l) => l.listingId == sid,
                          orElse: () => v.listings.first,
                        );
                        currentStock += listing.remainingQuantity;
                      }
                    }
                    return "₱${minPrice == maxPrice ? minPrice.toStringAsFixed(2) : "${minPrice.toStringAsFixed(2)} - ${maxPrice.toStringAsFixed(2)}"} / ${widget.state.selectedUnit}. "
                            "${widget.mode == 'plan' ? '' : '${currentStock.toInt()} ${widget.produce.baseUnit} available. '}${widget.mode == 'plan' ? '' : helperText ?? ''}"
                        .trimRight();
                  })(),
                  padding: EdgeInsets.zero,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Please enter a quantity";
                    }
                    final qty = double.tryParse(value) ?? 0;
                    if (qty <= 0) {
                      return "Please enter a valid quantity";
                    }
                    if (widget.mode != 'plan' &&
                        maxQuantity != null &&
                        qty > maxQuantity) {
                      return "Max available: ${maxQuantity.toInt()}";
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 4),
              DuruhaPopupMenu<String>(
                items: menuActions,
                icon: Icon(Icons.more_vert, color: colorScheme.onTertiary),
                showLabel: false,
                showBackground: false,
                labelBuilder: (action) {
                  if (action.startsWith('group_with_')) {
                    final other = action.replaceFirst('group_with_', '');
                    return "Group with $other";
                  }
                  if (action.startsWith('add_to_group_')) {
                    final idx = int.parse(
                      action.replaceFirst('add_to_group_', ''),
                    );
                    return "Add to Group ${idx + 1}";
                  }
                  if (action.startsWith('remove_')) {
                    final variety = action.replaceFirst('remove_', '');
                    return "Remove $variety";
                  }
                  if (action == 'ungroup') {
                    return "Ungroup";
                  }
                  return "No options";
                },
                itemIcons: Map.fromIterable(
                  menuActions,
                  key: (e) => e,
                  value: (e) {
                    if (e.startsWith('group_with_')) {
                      return Icons.group_add;
                    }
                    if (e.startsWith('add_to_group_')) {
                      return Icons.add;
                    }
                    if (e.startsWith('remove_')) {
                      return Icons.remove_circle_outline;
                    }
                    if (e == 'ungroup') {
                      return Icons.group_off;
                    }
                    return Icons.block;
                  },
                ),
                onSelected: (action) {
                  final vName = key.replaceFirst('qty_', '');
                  if (action.startsWith('group_with_')) {
                    final other = action.replaceFirst('group_with_', '');
                    _createGroup(vName, other);
                  } else if (action.startsWith('add_to_group_')) {
                    final idx = int.parse(
                      action.replaceFirst('add_to_group_', ''),
                    );
                    _addToGroup(idx, vName);
                  } else if (action.startsWith('remove_')) {
                    final variety = action.replaceFirst('remove_', '');
                    if (key.startsWith('group_')) {
                      final groupIndex = int.parse(
                        key.replaceFirst('group_', ''),
                      );
                      _removeFromGroup(groupIndex, variety);
                    }
                  } else if (action == 'ungroup') {
                    if (key.startsWith('group_')) {
                      final groupIndex = int.parse(
                        key.replaceFirst('group_', ''),
                      );
                      _ungroup(groupIndex);
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (widget.mode == 'plan') ...[
                const SizedBox(width: 8),
                Expanded(child: _buildRecurringButton(key, colorScheme)),
              ] else ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: TextButton(
                    onPressed: () => _applyDateToAll(dateNeeded),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.onTertiary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Icon(Icons.copy_all_rounded, size: 14),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DuruhaDateInput(
                    label: "Date Needed",
                    value: dateNeeded,
                    onTap: () => _selectDeliveryDate(key),
                    icon: Icons.event_available_rounded,
                  ),
                ),
              ],
            ],
          ),
          if (isSelectionGroup && !hasCommonForms) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Different forms available: ${buildSpecificLabeling()}",
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (hasCommonForms) ...[
            const SizedBox(height: 16),
            DuruhaSelectionChipGroup(
              title: isSelectionGroup ? "Common Form" : "Select Form",
              options: commonForms.toList(),
              selectedValues: (() {
                // If all varieties have the same form name selected, highlight it
                final firstV = targetVarieties.first;
                final firstSelectedId =
                    widget.state.varietySelectedFormId[firstV.name];
                final firstSelectedForm =
                    firstV.listings
                        .firstWhere(
                          (l) => l.listingId == firstSelectedId,
                          orElse: () => firstV.listings.first,
                        )
                        .produceForm ??
                    'Raw';

                final allSame = targetVarieties.every((v) {
                  final sid = widget.state.varietySelectedFormId[v.name];
                  final formName =
                      v.listings
                          .firstWhere(
                            (l) => l.listingId == sid,
                            orElse: () => v.listings.first,
                          )
                          .produceForm ??
                      'Raw';
                  return formName == firstSelectedForm;
                });

                return allSame ? [firstSelectedForm] : <String>[];
              })(),
              onToggle: (formName) => toggleGroupForm(formName),
              optionSubtitles: widget.mode == 'plan'
                  ? {}
                  : {
                      for (var fName in commonForms)
                        fName:
                            "${commonFormQuantities[fName]?.toInt() ?? 0} ${widget.produce.baseUnit} available",
                    },
              disabledOptions: widget.mode == 'plan'
                  ? []
                  : [
                      for (var fName in commonForms)
                        if ((commonFormQuantities[fName] ?? 0) <= 0) fName,
                    ],
              layout: SelectionLayout.wrap,
            ),
          ] else if (!isSelectionGroup && listings.length > 1) ...[
            const SizedBox(height: 16),
            DuruhaSelectionChipGroup(
              title: "Select Form",
              options: listings.map((l) => l.listingId).toList(),
              optionTitles: {
                for (var l in listings) l.listingId: l.produceForm ?? 'Raw',
              },
              optionSubtitles: {
                for (var l in listings)
                  l.listingId: widget.mode == 'plan'
                      ? "₱${l.duruhaToConsumerPrice.toStringAsFixed(2)}"
                      : "₱${l.duruhaToConsumerPrice.toStringAsFixed(2)} • ${l.remainingQuantity.toInt()} ${widget.produce.baseUnit} available",
              },
              disabledOptions: widget.mode == 'plan'
                  ? []
                  : [
                      for (var l in listings)
                        if (l.remainingQuantity <= 0) l.listingId,
                    ],
              selectedValues: selectedFormId != null ? [selectedFormId] : [],
              onToggle: (id) {
                setState(() {
                  widget.state.varietySelectedFormId[vName] = id;
                  _syncToState();
                });
              },
              layout: SelectionLayout.wrap,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecurringButton(String key, ColorScheme colorScheme) {
    final currentRule = widget.state.varietyRecurrence[key];
    final hasRule = currentRule != null && currentRule.isNotEmpty;
    final label = RecurringPickerUtil.toLabel(currentRule);

    // Parse date range for subtext when a rule is set
    String? subLabel;
    if (hasRule) {
      final d = RecurringPickerUtil.decode(currentRule);
      if (d.startDate != null && d.endDate != null) {
        final fmt = (DateTime dt) =>
            '${dt.month}/${dt.day}/${dt.year.toString().substring(2)}';
        final dates = RecurringPickerUtil.computeDates(currentRule);
        subLabel =
            '${fmt(d.startDate!)} → ${fmt(d.endDate!)}  ·  ${dates.length} dates';
      }
    }

    return Tooltip(
      message: hasRule ? label : 'Tap to set a recurring schedule',
      child: Material(
        color: hasRule
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showRecurrenceBottomSheet(key),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  hasRule ? Icons.sync_lock_rounded : Icons.sync_rounded,
                  size: 20,
                  color: hasRule
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasRule ? label : 'Set Recurring Schedule',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: hasRule
                              ? colorScheme.onPrimaryContainer
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (subLabel != null)
                        Text(
                          subLabel,
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onPrimaryContainer.withValues(
                              alpha: 0.7,
                            ),
                          ),
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        Text(
                          hasRule ? 'Tap to edit' : 'Daily · Weekly · Monthly',
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: hasRule
                      ? colorScheme.onPrimaryContainer.withValues(alpha: 0.6)
                      : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRecurrenceBottomSheet(String key) {
    showRecurringPicker(
      context: context,
      initialValue: widget.state.varietyRecurrence[key],
      planStartDate: widget.planStartDate,
      planEndDate: widget.planEndDate,
      onChanged: (newValue) {
        setState(() {
          widget.state.varietyRecurrence[key] = newValue;
          if (key.startsWith('qty_')) {
            widget.state.varietyRecurrence[key.replaceFirst('qty_', '')] =
                newValue;
          }
        });
        widget.onStateChanged();
      },
    );
  }
}
