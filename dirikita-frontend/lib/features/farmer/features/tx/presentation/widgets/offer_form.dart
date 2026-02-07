import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:flutter/material.dart';
import '../crop_selection_state.dart';

class OfferForm extends StatefulWidget {
  final Produce produce;
  final CropSelectionState state;
  final Function(DateTime) onAvailableDatePicked;
  final Function(DateTime) onDisposalDatePicked;
  final VoidCallback onStateChanged;

  const OfferForm({
    super.key,
    required this.produce,
    required this.state,
    required this.onAvailableDatePicked,
    required this.onDisposalDatePicked,
    required this.onStateChanged,
  });

  @override
  State<OfferForm> createState() => _OfferFormState();
}

class _OfferFormState extends State<OfferForm> {
  final Set<String> _expandedVarieties = {};

  @override
  Widget build(BuildContext context) {
    widget.produce;
    final state = widget.state;

    return Column(
      children: [
        // Date Range
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DuruhaDateRangePicker(
            label: "Availability Period",
            startDate: state.availableDate,
            endDate: state.disposalDate,
            startPlaceholder: "Available From",
            endPlaceholder: "Disposal Date",
            onDateRangePicked: (range) {
              widget.onAvailableDatePicked(range.start);
              widget.onDisposalDatePicked(range.end);
            },
          ),
        ),
        const SizedBox(height: 16),

        // Quantity Inputs for ALL varieties
        ...widget.produce.availableVarieties.map((varietyItem) {
          final variant = varietyItem.name;
          final controller = state.varietyQuantityControllers.putIfAbsent(
            variant,
            () => TextEditingController(),
          );

          // Dummy pricing simulation logic
          final basePrice = widget.produce.pricingEconomics.duruhaFarmerPayout;
          final dummyPrice = basePrice + varietyItem.priceModifier;

          return ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              final isExpanded = _expandedVarieties.contains(variant);
              final bool hasInput =
                  value.text.trim().isNotEmpty &&
                  (double.tryParse(value.text.trim()) ?? 0) > 0;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: hasInput
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: hasInput
                        ? Theme.of(context).colorScheme.onPrimary
                        : Colors.transparent,
                    width: hasInput ? 2.0 : 0.0,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedVarieties.remove(variant);
                        } else {
                          _expandedVarieties.add(variant);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  variant,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: hasInput
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.onPrimary
                                            : Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                      ),
                                ),
                              ),
                              if (hasInput && !isExpanded)
                                Text(
                                  "${controller.text} ${state.selectedUnit}",
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimary,
                                      ),
                                ),
                            ],
                          ),

                          if (isExpanded) ...[
                            const SizedBox(height: 16),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                "${DuruhaFormatter.formatCurrency(dummyPrice)} / ${state.selectedUnit}",
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(
                                      color: hasInput
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.onPrimary
                                          : Theme.of(context)
                                                .colorScheme
                                                .onPrimary
                                                .withValues(alpha: 0.5),
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Input Field
                            DuruhaTextField(
                              isRequired: false,
                              controller: controller,
                              label: "Quantity",
                              icon: Icons.scale_rounded,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              suffix: state.selectedUnit,
                              onChanged: (val) {
                                final qty = double.tryParse(val) ?? 0;
                                if (qty > 0) {
                                  if (!state.selectedVariants.contains(
                                    variant,
                                  )) {
                                    state.selectedVariants.add(variant);
                                  }
                                } else {
                                  state.selectedVariants.remove(variant);
                                }
                                widget.onStateChanged();
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ],
    );
  }
}
