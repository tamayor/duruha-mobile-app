import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:flutter/material.dart';

import 'package:duruha/features/consumer/features/tx/data/transaction_draft_service.dart';

import '../crop_selection_state.dart';
import 'package:intl/intl.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';

class PledgeForm extends StatefulWidget {
  final Produce produce;
  final CropSelectionState state;
  final Function(List<DateTime>, Map<DateTime, DateDemandData>) onDatesChanged;
  final VoidCallback onStateChanged;

  const PledgeForm({
    super.key,
    required this.produce,
    required this.state,
    required this.onDatesChanged,
    required this.onStateChanged,
  });

  @override
  State<PledgeForm> createState() => _PledgeFormState();
}

class _PledgeFormState extends State<PledgeForm> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // --- HARVEST DATE INPUT ---
        // Multi-Date Selection
        Builder(
          builder: (context) {
            final dates = widget.state.selectedHarvestDates;
            String placeholder = "Select Harvest Dates";
            if (dates.isNotEmpty) {
              dates.sort();
              if (dates.length == 1) {
                placeholder = DateFormat('MMM d').format(dates.first);
              } else {
                placeholder = "${dates.length} dates selected";
              }
            }

            return DuruhaDateInput(
              label: "Harvest Dates",
              value: null,
              placeholder: placeholder,
              onTap: () {},
            );
          },
        ),

        const SizedBox(height: 16),

        // Show selected dates list with remove/edit options
        if (widget.state.selectedHarvestDates.isNotEmpty)
          _buildSelectedDatesList(context),

        const SizedBox(height: 16),

        // Show summary of total pledged across all dates
        if (widget.state.selectedHarvestDates.isNotEmpty)
          _buildPledgeSummary(context),
      ],
    );
  }

  Widget _buildSelectedDatesList(BuildContext context) {
    final dates = widget.state.selectedHarvestDates..sort();
    final pledgeMap = widget.state.perDatePledgesMap;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          "Selected Harvest Dates (Tap to edit):",
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        ...dates.map((date) {
          final normalized = DateTime(date.year, date.month, date.day);
          final demand = widget.state.dateSpecificDemand[normalized];
          final datePledges = pledgeMap[normalized];

          double totalPledgedOnDate = 0;
          if (datePledges != null) {
            totalPledgedOnDate = datePledges.values.fold(
              0,
              (sum, val) => sum + val,
            );
          }

          final isPledged = totalPledgedOnDate > 0;

          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 12, left: 12),
                child: GestureDetector(
                  onTap: () => _showPerDateDialog(context, normalized, demand),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isPledged
                          ? Theme.of(
                              context,
                            ).colorScheme.secondary.withValues(alpha: 0.3)
                          : Theme.of(context).colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPledged
                            ? Theme.of(context).colorScheme.outlineVariant
                            : Theme.of(
                                context,
                              ).colorScheme.onSecondary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('MMMM d, yyyy').format(date),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (demand != null) ...[
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "Demand: ${DuruhaFormatter.formatCompactNumber(demand.totalDemand)} ${widget.state.selectedUnit}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    "Fulfilled: ${DuruhaFormatter.formatCompactNumber(demand.totalFulfilled)} ${widget.state.selectedUnit}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                        if (isPledged && datePledges != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ...datePledges.entries.map(
                                  (e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          e.key,
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        Text(
                                          "${DuruhaFormatter.formatCompactNumber(e.value)} ${widget.state.selectedUnit}",
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (!isPledged)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              "Tap to add pledge quantity",
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onPrimary,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      widget.state.selectedHarvestDates.remove(date);
                      widget.state.perDatePledges.removeWhere(
                        (e) =>
                            e.date.year == normalized.year &&
                            e.date.month == normalized.month &&
                            e.date.day == normalized.day,
                      );
                    });
                    widget.onDatesChanged(
                      widget.state.selectedHarvestDates,
                      widget.state.dateSpecificDemand,
                    );
                    widget.onStateChanged();
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.remove,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildPledgeSummary(BuildContext context) {
    double totalPledged = 0;
    final varietyTotals = <String, double>{};

    for (var entry in widget.state.perDatePledges) {
      totalPledged += entry.quantity;
      varietyTotals[entry.variety] =
          (varietyTotals[entry.variety] ?? 0) + entry.quantity;
    }

    if (totalPledged == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Total ${widget.produce.nameEnglish} Pledged",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                "${DuruhaFormatter.formatCompactNumber(totalPledged)} ${widget.state.selectedUnit}",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (varietyTotals.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(
                height: 1,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.2),
              ),
            ),
            Text(
              "By Variety",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...varietyTotals.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: const TextStyle(fontSize: 14)),
                    Text(
                      "${DuruhaFormatter.formatCompactNumber(e.value)} ${widget.state.selectedUnit}",
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
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

  Future<void> _showPerDateDialog(
    BuildContext context,
    DateTime date,
    DateDemandData? demandData,
  ) async {
    // 1. Get breakdown. Prefer stored if available, else fetch deterministic.
    List<Map<String, dynamic>> demandList = [];
    // if (demandData != null && demandData.varietyBreakdown.isNotEmpty) {
    //   demandList = demandData.varietyBreakdown;
    // } else {
    //   // Fetch fresh

    //   try {
    //     final freshData = await repo.getDetailedDemand(widget.produce.id, date);
    //     demandList = freshData.varietyBreakdown;
    //   } catch (e) {
    //     // Fallback or error handling
    //   }
    // }

    // 2. Setup existing values
    final existingPledges = widget.state.perDatePledgesMap[date] ?? {};
    final tempControllers = <String, TextEditingController>{};
    for (var variety in widget.produce.availableVarieties) {
      tempControllers[variety.name] = TextEditingController(
        text:
            existingPledges[variety.name] != null &&
                existingPledges[variety.name]! > 0
            ? existingPledges[variety.name].toString()
            : '',
      );
    }

    // 3. Show Duruha Modal
    if (!context.mounted) return;

    await DuruhaBottomSheet.show(
      context: context,
      title: "Pledge for ${DateFormat('MMM d').format(date)}",
      subtitle: "Enter pledge quantities for each variety",
      icon: Icons.edit_calendar_rounded,
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final formKey = GlobalKey<FormState>();

          return Form(
            key: formKey,
            child: ListView(
              controller: ScrollController(),
              shrinkWrap: true,
              children: [
                if (demandData != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.onSecondary.withValues(
                          alpha: 0.5,
                        ),
                        width: .5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.insights,
                          size: 20,
                          color: theme.colorScheme.onSecondary,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Total Demand: ${DuruhaFormatter.formatCompactNumber(demandData.totalDemand)} ${widget.state.selectedUnit}",
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Fulfilled: ${DuruhaFormatter.formatCompactNumber(demandData.totalFulfilled)} ${widget.state.selectedUnit}",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                ...widget.produce.availableVarieties.map((variety) {
                  final controller = tempControllers[variety.name]!;

                  // Find demand for this specific variety
                  Map<String, dynamic> demandItem = {};
                  if (demandList.isNotEmpty) {
                    demandItem = demandList.firstWhere(
                      (d) => d['variant'] == variety.name,
                      orElse: () => {},
                    );
                  }

                  final varietyDemand = (demandItem['demand_kg'] as num? ?? 0)
                      .toDouble();
                  final varietyFulfilled =
                      (demandItem['fulfilled_kg'] as num? ?? 0).toDouble();
                  final price = (demandItem['price'] as num? ?? 0).toDouble();

                  final remainingDemand = varietyDemand - varietyFulfilled;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              variety.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (demandItem.isNotEmpty)
                              Text(
                                "${DuruhaFormatter.formatCompactNumber(remainingDemand)} left",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (varietyDemand > 0)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Demand: ${DuruhaFormatter.formatCompactNumber(varietyDemand)} ${widget.state.selectedUnit}",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                "Fulfilled: ${DuruhaFormatter.formatCompactNumber(varietyFulfilled)} ${widget.state.selectedUnit}",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            "No demand data",
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),

                        if (price > 0)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              "@ ${DuruhaFormatter.formatCurrency(price)}",
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSecondary,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),

                        DuruhaTextField(
                          // icon: Icons.eco,
                          icon: Icons.eco,
                          isRequired: false,
                          enabled: varietyFulfilled != varietyDemand,
                          controller: controller,
                          label: varietyFulfilled != varietyDemand
                              ? "Quantity"
                              : "Fulfilled",
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          suffix: widget.state.selectedUnit,
                          validator: (value) {
                            if (value == null || value.isEmpty) return null;
                            final val = double.tryParse(value);
                            if (val == null) return "Invalid number";
                            if (val > varietyDemand - varietyFulfilled) {
                              return "Max ${DuruhaFormatter.formatCompactNumber(varietyDemand - varietyFulfilled)} ${widget.state.selectedUnit}";
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),

                DuruhaButton(
                  text: "Save Pledge",
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;

                    final newPledges = <String, double>{};
                    tempControllers.forEach((key, ctrl) {
                      final val = double.tryParse(ctrl.text);
                      if (val != null && val > 0) newPledges[key] = val;
                    });

                    // Update the list in state
                    widget.state.perDatePledges.removeWhere(
                      (e) =>
                          e.date.year == date.year &&
                          e.date.month == date.month &&
                          e.date.day == date.day,
                    );
                    if (newPledges.isNotEmpty) {
                      for (var entry in newPledges.entries) {
                        widget.state.perDatePledges.add(
                          HarvestEntry(
                            date: date,
                            variety: entry.key,
                            quantity: entry.value,
                          ),
                        );
                      }
                    }

                    widget.onStateChanged();
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );

    if (context.mounted) {
      setState(() {});
    }
  }
}
