import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/features/consumer/features/market/domain/market_order_model.dart';
import 'package:duruha/features/consumer/features/market/presentation/market_state.dart';
import 'package:flutter/material.dart';

class ProduceCard extends StatelessWidget {
  final MarketProduceItem item;
  final bool isSelected;
  final MarketMode marketMode;
  final bool isFavorite;
  final double quantity;
  final VoidCallback onListTap;
  final VoidCallback onFavoriteTap;
  final ValueChanged<double> onQuantityChanged;

  const ProduceCard({
    super.key,
    required this.item,
    required this.isSelected,
    required this.isFavorite,
    required this.marketMode,
    required this.quantity,
    required this.onListTap,
    required this.onFavoriteTap,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final produce = item.produce;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.outline, width: 2)
            : BorderSide.none,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Header
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Image.network(
                  produce.imageHeroUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 160,
                      color: theme.colorScheme.surfaceContainer,
                      child: Icon(
                        Icons.image_not_supported,
                        size: 48,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    );
                  },
                ),
              ),
              // Local availability badge
              if (item.isLocallyAvailable)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Local',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Selected indicator
              if (isSelected)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      size: 20,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              // Favorite button
              Positioned(
                top: 12,
                right: isSelected ? 56 : 12,
                child: GestureDetector(
                  onTap: onFavoriteTap,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withAlpha(200),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(50),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      size: 20,
                      color: isFavorite
                          ? const Color(0xFFFF5252)
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Produce name in local dialect
                Text(
                  produce.namesByDialect['hiligaynon'] ?? produce.nameEnglish,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                // English name
                Text(
                  produce.nameEnglish,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 12),

                // Price and Availability row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Price
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fair Price',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Builder(
                          builder: (context) {
                            if (produce.availableVarieties.isNotEmpty) {
                              final basePrice =
                                  produce.pricingEconomics.duruhaConsumerPrice;
                              final prices = produce.availableVarieties
                                  .map((v) => basePrice + v.priceModifier)
                                  .toList();
                              // Sort to easily get min and max
                              prices.sort();
                              final minPrice = prices.first;
                              final maxPrice = prices.last;

                              if (minPrice != maxPrice) {
                                return Text(
                                  '${DuruhaFormatter.formatCurrency(minPrice)} - ${DuruhaFormatter.formatCurrency(maxPrice)} / ${produce.unitOfMeasure}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF4CAF50),
                                  ),
                                );
                              }
                              // Fallback if all varieties have same price
                              return Text(
                                '${DuruhaFormatter.formatCurrency(minPrice)} / ${produce.unitOfMeasure}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF4CAF50),
                                ),
                              );
                            }

                            // Fallback to guideline if no varieties
                            return Text(
                              '${DuruhaFormatter.formatCurrency(produce.pricingEconomics.duruhaConsumerPrice)} / ${produce.unitOfMeasure}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF4CAF50),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    // Refined Availability Chip
                    if (item.availableQuantityKg != null &&
                        marketMode != MarketMode.plan)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: marketMode == MarketMode.order
                              ? theme.colorScheme.primaryContainer
                              : Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: marketMode == MarketMode.order
                                ? theme.colorScheme.primary.withValues(
                                    alpha: 0.3,
                                  )
                                : Colors.orange.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              marketMode == MarketMode.order
                                  ? Icons.inventory_2_outlined
                                  : Icons.agriculture_outlined,
                              size: 14,
                              color: marketMode == MarketMode.order
                                  ? theme.colorScheme.onPrimary
                                  : Colors.orange.shade800,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${item.availableQuantityKg!.toStringAsFixed(0)} kg ${marketMode == MarketMode.plan ? 'Yield' : 'Avail.'}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: marketMode == MarketMode.order
                                    ? theme.colorScheme.onPrimary
                                    : Colors.orange.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 16),
                // Footer row with Location and Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // List button
                    ElevatedButton.icon(
                      onPressed: onListTap,
                      icon: Icon(
                        isSelected ? Icons.remove : Icons.add,
                        size: 18,
                      ),
                      label: Text(isSelected ? 'Remove' : 'Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected
                            ? theme.colorScheme.surfaceContainer
                            : theme.colorScheme.primaryContainer,
                        foregroundColor: isSelected
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.onPrimaryContainer,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
