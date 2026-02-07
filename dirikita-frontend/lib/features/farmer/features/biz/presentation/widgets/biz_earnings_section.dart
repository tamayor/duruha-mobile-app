import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BizEarningsSection extends StatelessWidget {
  final Map<String, List<HarvestPledge>> groupedByCrop;

  const BizEarningsSection({super.key, required this.groupedByCrop});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (groupedByCrop.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Text(
            "No sales found in this period.",
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Column(
      children: groupedByCrop.entries
          .map((entry) => _buildCropGroup(context, entry.key, entry.value))
          .toList(),
    );
  }

  Widget _buildCropGroup(
    BuildContext context,
    String cropName,
    List<HarvestPledge> pledges,
  ) {
    final theme = Theme.of(context);

    final cropTotalRevenue = pledges.fold(
      0.0,
      (sum, p) => sum + (p.quantity * (p.sellingPrice ?? 0)),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: DuruhaSectionContainer(
        title: cropName,
        action: Text(
          DuruhaFormatter.formatCurrency(cropTotalRevenue),
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.green.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [...pledges.map((p) => _buildTransactionTile(context, p))],
      ),
    );
  }

  Widget _buildTransactionTile(BuildContext context, HarvestPledge p) {
    final theme = Theme.of(context);
    final revenue = p.quantity * (p.sellingPrice ?? 0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${DuruhaFormatter.formatNumber(p.quantity)} ${p.unit} • ${p.variants.join(', ')}",
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  DateFormat('MMM d, yyyy').format(p.harvestDate),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                DuruhaFormatter.formatCurrency(revenue),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                "₱${DuruhaFormatter.formatNumber(p.sellingPrice ?? 0)}/unit",
                style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
