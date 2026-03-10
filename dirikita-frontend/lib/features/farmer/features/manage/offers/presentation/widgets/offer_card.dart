import 'package:duruha/core/constants/color_marker.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/farmer/features/manage/offers/domain/offer_model.dart';
import 'package:duruha/features/farmer/features/manage/offers/presentation/offer_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OfferCard extends StatelessWidget {
  final HarvestOffer offer;
  final ProduceOfferGroup produceGroup;
  final bool isActive;
  final int index;
  final VoidCallback? onRefresh;

  const OfferCard({
    super.key,
    required this.offer,
    required this.produceGroup,
    required this.isActive,
    required this.index,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final offerColor = colorMarker[index % colorMarker.length];

    final pendingOrdersCount = offer.orders
        .where((o) => !o.farmerIsPaid)
        .length;

    final totalDuration = offer.availableTo
        .difference(offer.availableFrom)
        .inHours;
    final elapsed = now.difference(offer.availableFrom).inHours;
    final double timeProgress = totalDuration > 0
        ? (elapsed / totalDuration).clamp(0.0, 1.0)
        : 1.0;

    final double reserveProgress = offer.quantity > 0
        ? (offer.reservedQty / offer.quantity).clamp(0.0, 1.0)
        : 0.0;

    final isInfinityEnd = offer.availableTo.year >= 2100;

    return Stack(
      children: [
        DuruhaInkwell(
          variation: InkwellVariation.brand,
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OfferDetailScreen(
                  offer: offer,
                  produce: produceGroup,
                  isActive: isActive,
                ),
              ),
            );
            if (result == true && onRefresh != null) {
              onRefresh!();
            }
          },
          child: DuruhaSectionContainer(
            backgroundColor: offerColor.withValues(alpha: 0.05),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            children: [
              // ── Row 1: variety name + badges ──────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (produceGroup.produceLocalName.isNotEmpty)
                          Text(
                            produceGroup.produceLocalName.toUpperCase(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurfaceVariant,
                              letterSpacing: 0.5,
                              fontSize: 8,
                            ),
                          ),
                        Text(
                          offer.varietyName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (pendingOrdersCount > 0) ...[
                    _badge(
                      context,
                      '$pendingOrdersCount pending',
                      theme.colorScheme.error,
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (offer.isPriceLocked) ...[_priceLockBadge(theme)],
                ],
              ),
              const SizedBox(height: 8),

              // ── Row 2: reservation ring + quantities + timeline ────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Small circular reservation indicator
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: reserveProgress,
                          strokeWidth: 3,
                          backgroundColor: theme.colorScheme.onTertiary
                              .withValues(alpha: 0.1),
                          color: theme.colorScheme.onTertiary,
                        ),
                        Text(
                          '${(reserveProgress * 100).toInt()}%',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Quantities
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${DuruhaFormatter.formatNumber(offer.quantity)} kg total'
                          '  ·  ${DuruhaFormatter.formatNumber(offer.reservedQty)} kg reserved',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Timeline bar
                        Row(
                          children: [
                            Text(
                              DateFormat('MMM d').format(offer.availableFrom),
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.grey,
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: DuruhaProgressBar(
                                  value: timeProgress,
                                  height: 3,
                                  backgroundColor: theme.colorScheme.onSecondary
                                      .withValues(alpha: 0.2),
                                  color: theme.colorScheme.onSecondary,
                                ),
                              ),
                            ),
                            Text(
                              isInfinityEnd
                                  ? '∞'
                                  : DateFormat(
                                      'MMM d',
                                    ).format(offer.availableTo),
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Left accent bar
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width: 4,
            decoration: BoxDecoration(
              color: offerColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _priceLockBadge(ThemeData theme) {
    final isLocked = offer.fplsStatus == 'ACTIVE';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: isLocked
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.colorScheme.tertiary, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLocked ? Icons.lock : Icons.lock_open,
            size: 8,
            color: isLocked
                ? theme.colorScheme.onTertiaryContainer
                : theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 2),
          Text(
            isLocked ? 'LOCKED' : 'UNLOCKED',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: isLocked
                  ? theme.colorScheme.onTertiaryContainer
                  : theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String take(int n) => length > n ? substring(0, n) : this;
}
