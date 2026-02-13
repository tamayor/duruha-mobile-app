import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_inkwell.dart';
import 'package:duruha/core/widgets/duruha_progress_bar.dart';
import 'package:duruha/core/widgets/duruha_section_container.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OfferCard extends StatelessWidget {
  final HarvestOffer offer;
  final bool isActive;

  const OfferCard({super.key, required this.offer, required this.isActive});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    // Calculate Progress (Time-based for active, or just a state)
    final totalDuration = offer.disposalDate
        .difference(offer.startDate)
        .inHours;
    final elapsed = now.difference(offer.startDate).inHours;

    double timeProgress = 0.0;
    if (totalDuration > 0) {
      timeProgress = (elapsed / totalDuration).clamp(0.0, 1.0);
    } else {
      timeProgress = 1.0;
    }

    // Reservation Progress
    final double reserveProgress = offer.totalHarvestQty > 0
        ? (offer.reservedQty / offer.totalHarvestQty).clamp(0.0, 1.0)
        : 0.0;

    return DuruhaInkwell(
      onTap: () {
        // Future navigation to offer detail
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DuruhaSectionContainer(
          backgroundColor: theme.colorScheme.tertiaryContainer.withValues(
            alpha: 0.1,
          ),
          padding: const EdgeInsets.all(16),
          children: [
            // Header: ID and Dates
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "ID: ${offer.id}",
                  style: TextStyle(
                    fontFamily: 'Courier',
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  isActive ? "ACTIVE" : "EXPIRED",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Main Content: Name and Reservation Info
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(offer.imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.cropName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _buildVariantsWrap(offer, theme),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${DuruhaFormatter.formatNumber(offer.totalHarvestQty)} kg",
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const Text(
                      "Target Harvest",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Reservation Progress Bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Reservations: ${DuruhaFormatter.formatNumber(offer.reservedQty)} / ${DuruhaFormatter.formatNumber(offer.totalHarvestQty)} kg",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                    Text(
                      "${(reserveProgress * 100).toInt()}%",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                DuruhaProgressBar(
                  value: reserveProgress,
                  height: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Timeline (Start to Disposal)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDatePoint(context, "Start", offer.startDate),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        "Offer Availability",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      DuruhaProgressBar(
                        value: timeProgress,
                        height: 4,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildDatePoint(context, "Disposal", offer.disposalDate),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePoint(BuildContext context, String label, DateTime date) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          DateFormat('MMM d').format(date),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildVariantsWrap(HarvestOffer offer, ThemeData theme) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: offer.variants.map((variant) {
        final double qty = offer.varietyQuantities[variant] ?? 0.0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: theme.colorScheme.onSecondary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: theme.colorScheme.onSecondary.withValues(alpha: 0.1),
            ),
          ),
          child: Text(
            "$variant (${DuruhaFormatter.formatNumber(qty)} kg)",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSecondaryContainer,
            ),
          ),
        );
      }).toList(),
    );
  }
}
