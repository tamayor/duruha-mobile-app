import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_selection_chip_group.dart';
import 'package:duruha/core/widgets/duruha_text_field.dart';
import 'package:duruha/features/consumer/features/market/domain/market_order_model.dart';
import 'package:duruha/features/consumer/features/market/presentation/market_state.dart';
import 'package:flutter/material.dart';

class OrderItemCard extends StatefulWidget {
  final OrderItemBuilder builder;
  final Function(OrderItemBuilder) onUpdate;
  final VoidCallback onRemove;
  final bool isOrderMode;

  const OrderItemCard({
    super.key,
    required this.builder,
    required this.onUpdate,
    required this.onRemove,
    this.isOrderMode = false,
  });

  @override
  State<OrderItemCard> createState() => _OrderItemCardState();
}

class _OrderItemCardState extends State<OrderItemCard> {
  bool _isExpanded = false;
  late TextEditingController _quantityController;
  late Map<String, Map<String, double>> _mockInventory;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: widget.builder.quantityKg > 0
          ? widget.builder.quantityKg.toString()
          : '',
    );
    _generateMockInventory();
  }

  void _generateMockInventory() {
    _mockInventory = {};
    if (!widget.isOrderMode) return;

    final produce = widget.builder.produce;
    for (var variety in produce.availableVarieties) {
      // Deterministic mock based on variety name hash
      final hash = variety.name.hashCode;
      final totalQty = 20.0 + (hash % 100); // 20 - 119 kg

      // Split into classes (approximate distribution)
      final classAQty = (totalQty * 0.5).floorToDouble();
      final classBQty = (totalQty * 0.3).floorToDouble();
      final classCQty = totalQty - classAQty - classBQty;

      _mockInventory[variety.name] = {
        'A': classAQty,
        'B': classBQty,
        'C': classCQty,
      };
    }
  }

  @override
  void didUpdateWidget(OrderItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync controller with external changes, but only if they are substantive
    // and not just formatting differences from typing (e.g. 5 vs 5.0)
    final double? currentVal = double.tryParse(_quantityController.text);
    if (widget.builder.quantityKg != oldWidget.builder.quantityKg &&
        widget.builder.quantityKg != currentVal) {
      _quantityController.text = widget.builder.quantityKg > 0
          ? widget.builder.quantityKg.toString()
          : '';
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  double _getAvailableQuantityForClass(String classCode) {
    if (!widget.isOrderMode) return 0;

    double total = 0;
    for (var varietyName in widget.builder.selectedVarieties) {
      if (_mockInventory.containsKey(varietyName)) {
        total += _mockInventory[varietyName]?[classCode] ?? 0;
      }
    }
    return total;
  }

  double _getMaxAvailableQuantity() {
    if (!widget.isOrderMode) return double.infinity;

    double total = 0;
    for (var varietyName in widget.builder.selectedVarieties) {
      if (_mockInventory.containsKey(varietyName)) {
        for (var classObj in widget.builder.selectedClasses) {
          total += _mockInventory[varietyName]?[classObj.code] ?? 0;
        }
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final produce = widget.builder.produce;
    final isComplete = widget.builder.isComplete;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isComplete
            ? BorderSide(color: theme.colorScheme.outlineVariant, width: 2)
            : BorderSide(
                color: theme.colorScheme.outline.withAlpha(100),
                width: 1,
              ),
      ),
      child: Column(
        children: [
          // Header (always visible)
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Produce image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      produce.imageThumbnailUrl,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 60,
                          height: 60,
                          color: theme.colorScheme.surfaceContainer,
                          child: Icon(
                            Icons.image_not_supported,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Produce name and status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          produce.namesByDialect['hiligaynon'] ??
                              produce.nameEnglish,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isComplete) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${widget.builder.selectedVarieties.join(', ')} • Class ${widget.builder.selectedClasses.map((c) => c.code).join(', ')}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '${widget.builder.quantityKg} ${produce.unitOfMeasure}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF4CAF50),
                            ),
                          ),
                        ] else
                          Row(
                            children: [
                              Icon(
                                Icons.radio_button_unchecked,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Incomplete',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // Remove button
                  IconButton(
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: theme.colorScheme.error.withAlpha(150),
                      size: 20,
                    ),
                    onPressed: widget.onRemove,
                    tooltip: 'Remove from order',
                  ),

                  // Expand icon
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Variety selection - Converted to chips with "Any" toggle
                  DuruhaSelectionChipGroup(
                    title: 'Select Variety',
                    action: TextButton.icon(
                      onPressed: () {
                        final allVarieties = produce.availableVarieties
                            .map((v) => v.name)
                            .toList();
                        final allSelected =
                            widget.builder.selectedVarieties.length ==
                            allVarieties.length;

                        widget.onUpdate(
                          widget.builder.copyWith(
                            selectedVarieties: allSelected
                                ? <String>[]
                                : allVarieties,
                          ),
                        );
                      },
                      icon: Icon(
                        widget.builder.selectedVarieties.length ==
                                produce.availableVarieties.length
                            ? Icons.deselect
                            : Icons.select_all,
                        size: 16,
                      ),
                      label: Text(
                        widget.builder.selectedVarieties.length ==
                                produce.availableVarieties.length
                            ? 'Unselect All'
                            : 'Any',
                      ),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                    ),
                    options: produce.availableVarieties
                        .map((v) => v.name)
                        .toList(),
                    selectedValues: widget.builder.selectedVarieties,
                    optionTitles: Map.fromEntries(
                      produce.availableVarieties.map(
                        (v) => MapEntry(v.name, v.name),
                      ),
                    ),
                    optionSubtitles: Map.fromEntries(
                      produce.availableVarieties.map((v) {
                        final basePrice =
                            produce.pricingEconomics.duruhaConsumerPrice;
                        final varietyPrice = basePrice + v.priceModifier;
                        String subtitle =
                            "${DuruhaFormatter.formatCurrency(varietyPrice)}/${produce.unitOfMeasure}";

                        return MapEntry(v.name, subtitle);
                      }),
                    ),
                    optionTrailingText: Map.fromEntries(
                      produce.availableVarieties.map((v) {
                        String trailing = "";
                        if (widget.isOrderMode &&
                            _mockInventory.containsKey(v.name)) {
                          final inv = _mockInventory[v.name]!;
                          final total = inv.values.reduce((a, b) => a + b);
                          trailing = "${total.toInt()}kg";
                        }
                        return MapEntry(v.name, trailing);
                      }),
                    ),
                    onToggle: (String value) {
                      final newVarieties = List<String>.from(
                        widget.builder.selectedVarieties,
                      );
                      if (newVarieties.contains(value)) {
                        newVarieties.remove(value);
                      } else {
                        newVarieties.add(value);
                      }
                      widget.onUpdate(
                        widget.builder.copyWith(
                          selectedVarieties: newVarieties,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // SECTION: Class/Grade Selection with Dynamic Pricing
                  () {
                    // 1. Calculate the price context based on selected varieties
                    double minBase =
                        produce.pricingEconomics.duruhaConsumerPrice;
                    double maxBase =
                        produce.pricingEconomics.duruhaConsumerPrice;

                    if (widget.builder.selectedVarieties.isNotEmpty) {
                      final basePrice =
                          produce.pricingEconomics.duruhaConsumerPrice;
                      final selectedPrices = produce.availableVarieties
                          .where(
                            (v) => widget.builder.selectedVarieties.contains(
                              v.name,
                            ),
                          )
                          .map((v) => basePrice + v.priceModifier)
                          .toList();

                      if (selectedPrices.isNotEmpty) {
                        minBase = selectedPrices.reduce(
                          (a, b) => a < b ? a : b,
                        );
                        maxBase = selectedPrices.reduce(
                          (a, b) => a > b ? a : b,
                        );
                      }
                    }

                    // 2. Helpers for class info
                    String getPriceString(ProduceClass cls) {
                      final low = minBase * cls.multiplier;
                      final high = maxBase * cls.multiplier;

                      if (low == high) {
                        return DuruhaFormatter.formatCurrency(low);
                      }
                      return "${DuruhaFormatter.formatCurrency(low)} - ${DuruhaFormatter.formatCurrency(high)}";
                    }

                    return DuruhaSelectionChipGroup(
                      title: 'Select Class',
                      layout: SelectionLayout.column,
                      action: TextButton.icon(
                        onPressed: () {
                          final allClasses = ProduceClass.values;
                          final allSelected =
                              widget.builder.selectedClasses.length ==
                              allClasses.length;

                          widget.onUpdate(
                            widget.builder.copyWith(
                              selectedClasses: allSelected ? [] : allClasses,
                            ),
                          );
                        },
                        icon: Icon(
                          widget.builder.selectedClasses.length ==
                                  ProduceClass.values.length
                              ? Icons.deselect
                              : Icons.select_all,
                          size: 16,
                        ),
                        label: Text(
                          widget.builder.selectedClasses.length ==
                                  ProduceClass.values.length
                              ? 'Unselect All'
                              : 'Any',
                        ),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: theme.colorScheme.onPrimary,
                        ),
                      ),
                      options: ProduceClass.values.map((c) => c.code).toList(),
                      selectedValues: widget.builder.selectedClasses
                          .map((c) => c.code)
                          .toList(),
                      optionIcons: Map.fromEntries(
                        ProduceClass.values.map(
                          (cls) => MapEntry(
                            cls.code,
                            cls.code == 'A'
                                ? Icons.verified_rounded
                                : (cls.code == 'B'
                                      ? Icons.check_circle_outline
                                      : Icons.remove_circle_outline),
                          ),
                        ),
                      ),
                      optionTitles: Map.fromEntries(
                        ProduceClass.values.map(
                          (cls) =>
                              MapEntry(cls.code, "${cls.code} - ${cls.label}"),
                        ),
                      ),
                      optionSubtitles: Map.fromEntries(
                        ProduceClass.values.map((cls) {
                          return MapEntry(
                            cls.code,
                            "${getPriceString(cls)}/${produce.unitOfMeasure}",
                          );
                        }),
                      ),
                      optionTrailingText: Map.fromEntries(
                        ProduceClass.values.map((cls) {
                          String trailing = "";
                          if (widget.isOrderMode) {
                            final available = _getAvailableQuantityForClass(
                              cls.code,
                            );
                            trailing = "${available.toInt()}kg";
                          }
                          return MapEntry(cls.code, trailing);
                        }),
                      ),
                      onToggle: (String code) {
                        final toggledClass = ProduceClass.values.firstWhere(
                          (cls) => cls.code == code,
                        );

                        final newClasses = List<ProduceClass>.from(
                          widget.builder.selectedClasses,
                        );
                        if (newClasses.contains(toggledClass)) {
                          newClasses.remove(toggledClass);
                        } else {
                          newClasses.add(toggledClass);
                        }

                        // When selection changes, validate quantity
                        final newBuilder = widget.builder.copyWith(
                          selectedClasses: newClasses,
                        );

                        // We need to trigger an update so the max quantity calculation for the text field refreshes
                        widget.onUpdate(newBuilder);
                      },
                    );
                  }(),
                  const SizedBox(height: 12),
                  () {
                    final maxQty = _getMaxAvailableQuantity();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DuruhaTextField(
                          controller: _quantityController,
                          label: 'Enter quantity',
                          icon: Icons.numbers,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          isRequired: false,
                          onChanged: (value) {
                            // Trim and handle empty/invalid input gracefully
                            final cleanValue = value.trim();
                            if (cleanValue.isEmpty) {
                              widget.onUpdate(
                                widget.builder.copyWith(quantityKg: 0.0),
                              );
                              return;
                            }

                            // Don't update state for intermediate inputs (like a lonely '.')
                            // This prevents "zeroing" when the user is midway through typing.
                            final quantity = double.tryParse(cleanValue);
                            if (quantity == null) {
                              return;
                            }

                            double finalQuantity = quantity;

                            // Enforce max quantity
                            if (widget.isOrderMode && finalQuantity > maxQty) {
                              finalQuantity = maxQty;
                              // Update controller text to max
                              _quantityController.text = finalQuantity
                                  .toString();
                              // Keep cursor at end
                              _quantityController.selection =
                                  TextSelection.fromPosition(
                                    TextPosition(
                                      offset: _quantityController.text.length,
                                    ),
                                  );
                            }

                            widget.onUpdate(
                              widget.builder.copyWith(
                                quantityKg: finalQuantity,
                              ),
                            );
                          },
                          validator: (value) {
                            if (widget.builder.selectedClasses.isEmpty) {
                              return 'Please select a class';
                            }
                            if (value == null || value.isEmpty) {
                              return 'Please enter a quantity';
                            }
                            final quantity = double.tryParse(value);
                            if (quantity == null || quantity <= 0) {
                              return 'Please enter a valid quantity';
                            }
                            if (widget.isOrderMode && quantity > maxQty) {
                              return 'Quantity exceeds available stock';
                            }
                            return null;
                          },
                        ),
                        if (widget.isOrderMode && maxQty != double.infinity)
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              'Max available: ${maxQty.toInt()} kg',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSecondary,
                              ),
                            ),
                          ),
                      ],
                    );
                  }(),

                  // Estimated cost with Range and Solving
                  if (widget.builder.quantityKg > 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(
                            alpha: 0.1,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Estimated Total:',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              () {
                                final min = widget.builder.minTotalPrice;
                                final max = widget.builder.maxTotalPrice;
                                if (min == max) {
                                  return Text(
                                    DuruhaFormatter.formatCurrency(max),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF4CAF50),
                                        ),
                                  );
                                }
                                return Text(
                                  "${DuruhaFormatter.formatCurrency(min)} - ${DuruhaFormatter.formatCurrency(max)}",
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.outlineVariant,
                                  ),
                                );
                              }(),
                            ],
                          ),
                          const Divider(height: 24),
                          // "Solving" / Breakdown section
                          Row(
                            children: [
                              Icon(
                                Icons.calculate_outlined,
                                size: 14,
                                color: theme.colorScheme.onPrimary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'ESTIMATION BREAKDOWN',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          () {
                            // Extract min/max bases and multipliers for the solving string
                            final basePrice =
                                produce.pricingEconomics.duruhaConsumerPrice;
                            double minBase = basePrice;
                            double maxBase = basePrice;
                            if (widget.builder.selectedVarieties.isNotEmpty) {
                              final prices = produce.availableVarieties
                                  .where(
                                    (v) => widget.builder.selectedVarieties
                                        .contains(v.name),
                                  )
                                  .map((v) => basePrice + v.priceModifier)
                                  .toList();
                              if (prices.isNotEmpty) {
                                minBase = prices.reduce(
                                  (a, b) => a < b ? a : b,
                                );
                                maxBase = prices.reduce(
                                  (a, b) => a > b ? a : b,
                                );
                              }
                            }

                            double minMult = 1.0;
                            double maxMult = 1.0;
                            if (widget.builder.selectedClasses.isNotEmpty) {
                              minMult = widget.builder.selectedClasses
                                  .map((c) => c.multiplier)
                                  .reduce((a, b) => a < b ? a : b);
                              maxMult = widget.builder.selectedClasses
                                  .map((c) => c.multiplier)
                                  .reduce((a, b) => a > b ? a : b);
                            }

                            String formatRange(double low, double high) {
                              if (low == high)
                                return DuruhaFormatter.formatCurrency(low);
                              return "(${DuruhaFormatter.formatCurrency(low)} - ${DuruhaFormatter.formatCurrency(high)})";
                            }

                            return Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${widget.builder.quantityKg} ${produce.unitOfMeasure} × ${formatRange(minBase, maxBase)} × ${formatRange(minMult, maxMult)} Multiplier',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontFamily:
                                      'Courier', // Monospace for calculation feel
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            );
                          }(),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem(ThemeData theme, String label, double amount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          '${amount.toInt()} kg',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
