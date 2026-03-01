import 'package:duruha/core/constants/produce_colors.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/farmer/features/manage/offers/domain/offer_model.dart';
import 'package:duruha/features/farmer/features/manage/offers/presentation/offer_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OfferCard extends StatelessWidget {
  final HarvestOffer offer;
  final ProduceGroup produce;
  final bool isActive;
  final int index;
  final VoidCallback? onRefresh;

  const OfferCard({
    super.key,
    required this.offer,
    required this.produce,
    required this.isActive,
    required this.index,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final offerColor = produceTints[index % produceTints.length];

    final pendingOrdersCount = offer.orders
        .where((o) => !o.farmerIsPaid)
        .length;

    // Time Progress Calculation
    final totalDuration = offer.availableTo
        .difference(offer.availableFrom)
        .inHours;
    final elapsed = now.difference(offer.availableFrom).inHours;
    double timeProgress = totalDuration > 0
        ? (elapsed / totalDuration).clamp(0.0, 1.0)
        : 1.0;

    // Reservation Progress
    final double reserveProgress = offer.quantity > 0
        ? (offer.reservedQty / offer.quantity).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          DuruhaInkwell(
            variation: InkwellVariation.brand,
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OfferDetailScreen(
                    offer: offer,
                    produce: produce,
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
              padding: const EdgeInsets.all(16),
              children: [
                // --- HEADER: IDs & Status ---
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "OFFER #${offer.offerId.take(8).toUpperCase()}",
                        style: TextStyle(
                          fontFamily: 'Courier',
                          fontSize: 10,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimary.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ),
                    if (pendingOrdersCount > 0)
                      _buildNotificationBadge(context, pendingOrdersCount),
                    const SizedBox(width: 8),
                    if (offer.isPriceLocked) ...[
                      _buildPriceLockBadge(theme),
                      const SizedBox(width: 4),
                    ],
                    _buildStatusChip(isActive),
                  ],
                ),
                const Divider(height: 24, thickness: 0.5),

                // --- TITLE SECTION: Maximize for long names ---
                DuruhaTextEmphasis(
                  text: offer.varietyName,
                  breaker: "()",
                  mainColor: theme.colorScheme.onSurface,
                  subColor: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  mainSize: 16,
                  subSize: 12,
                  mainWeight: FontWeight.bold,
                  subWeight: FontWeight.w600,
                ),
                Text(
                  (produce.produceLocalName.isNotEmpty
                          ? produce.produceLocalName
                          : produce.produceEnglishName)
                      .toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: theme.colorScheme.secondary,
                  ),
                ),
                const SizedBox(height: 16),

                // --- INFO ROW: Image & Quantity ---
                Row(
                  children: [
                    Stack(
                      alignment: Alignment
                          .center, // This ensures all children are centered by default
                      children: [
                        SizedBox(
                          height: 60, // Set a specific size for the container
                          width: 60,
                          child: CircularProgressIndicator(
                            value: reserveProgress,
                            strokeWidth:
                                4, // Slightly thicker for better visibility
                            backgroundColor: theme.colorScheme.onTertiary
                                .withValues(alpha: 0.1),
                            color: theme.colorScheme.onTertiary,
                          ),
                        ),
                        Text(
                          "${(reserveProgress * 100).toInt()}%",
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize:
                                11, // Adjusted for typical circular indicator sizes
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${DuruhaFormatter.formatNumber(offer.quantity)} kg",
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const Text(
                            "Total Supply Target",
                            style: TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface,
                        ),
                        children: [
                          const TextSpan(text: "Reserved: "),
                          TextSpan(
                            text:
                                "${DuruhaFormatter.formatNumber(offer.reservedQty)} kg",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // --- TIMELINE ---
                Row(
                  children: [
                    _buildDatePoint(context, "Start", offer.availableFrom),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DuruhaProgressBar(
                          value: timeProgress,
                          height: 5,
                          backgroundColor: theme.colorScheme.onSecondary
                              .withValues(alpha: 0.2),
                          color: theme.colorScheme.onSecondary,
                        ),
                      ),
                    ),
                    _buildDatePoint(
                      context,
                      "End",
                      offer.availableTo,
                      isEnd: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Left-side color marker for produce differentiation
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
      ),
    );
  }

  Widget _buildStatusChip(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: active
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: active ? Colors.green : Colors.grey,
          width: 0.5,
        ),
      ),
      child: Text(
        active ? "ACTIVE" : "EXPIRED",
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: active ? Colors.green : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildPriceLockBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: offer.fplsStatus == "ACTIVE"
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: theme.colorScheme.tertiary, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          offer.fplsStatus == "ACTIVE"
              ? Icon(
                  Icons.lock,
                  size: 8,
                  color: theme.colorScheme.onTertiaryContainer,
                )
              : Icon(
                  Icons.lock_open,
                  size: 8,
                  color: theme.colorScheme.onSecondaryContainer,
                ),
          const SizedBox(width: 2),
          Text(
            offer.fplsStatus == "ACTIVE" ? "LOCKED" : "EXPIRED",
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: offer.fplsStatus == "ACTIVE"
                  ? theme.colorScheme.onTertiaryContainer
                  : theme.colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBadge(BuildContext context, int count) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      child: Text(
        "$count",
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDatePoint(
    BuildContext context,
    String label,
    DateTime date, {
    bool isEnd = false,
  }) {
    final isInfinity = date.year >= 2100;
    return Column(
      crossAxisAlignment: isEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        Text(
          isInfinity ? "Supply Lasts" : DateFormat('MMM d').format(date),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

extension StringExtension on String {
  String take(int n) => length > n ? substring(0, n) : this;
}
