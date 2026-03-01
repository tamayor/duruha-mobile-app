import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_section_container.dart';
import 'package:duruha/core/widgets/duruha_selection_card.dart';

class PledgeHarvestSchedule extends StatelessWidget {
  final HarvestPledge pledge;
  final DateTime harvestDate;
  final String currentStatus;
  final Function(HarvestEntry entry, bool newStatus) onToggleHarvest;
  final VoidCallback onShowDatePicker;

  const PledgeHarvestSchedule({
    super.key,
    required this.pledge,
    required this.harvestDate,
    required this.currentStatus,
    required this.onToggleHarvest,
    required this.onShowDatePicker,
  });

  bool get isFinalized => currentStatus == 'Sold' || currentStatus == 'Done';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasPerDatePledges = pledge.perDatePledges?.isNotEmpty ?? false;

    return DuruhaSectionContainer(
      title: "Harvest Schedule",
      subtitle: hasPerDatePledges
          ? "${pledge.perDatePledges!.length} entries planned"
          : "1 date planned",
      children: [
        if (hasPerDatePledges) ...[
          ..._buildHarvestEntries(context),
          if (isFinalized && (pledge.sellingPrice ?? 0) > 0)
            _buildGrandTotalCard(theme),
        ] else
          _buildSingleDateFallback(theme),
      ],
    );
  }

  List<Widget> _buildHarvestEntries(BuildContext context) {
    final theme = Theme.of(context);
    final entries = pledge.perDatePledges ?? [];

    // Sort entries by date
    final sortedEntries = List<HarvestEntry>.from(entries)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Calculate base price per unit if earnings are missing
    final double baseUnitPrice =
        (pledge.sellingPrice ?? 0) /
        (pledge.quantity > 0 ? pledge.quantity : 1);

    return sortedEntries.map((e) {
      final isCompleted = e.isCompleted == true;

      final double earnings = e.earnings ?? (e.quantity * baseUnitPrice);
      final bool showPrice =
          (currentStatus == 'Sold' || currentStatus == 'Done') && earnings > 0;

      return DuruhaSelectionCard(
        title: DuruhaFormatter.formatDate(e.date),
        subtitle: "${e.variety} • ${e.quantity} ${pledge.unit}",
        isSelected: isCompleted,
        isList: true,
        icon: Icons.calendar_today_rounded,
        onTap: () => onToggleHarvest(e, !isCompleted),
        trailing: showPrice
            ? Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withAlpha(50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  DuruhaFormatter.formatCurrency(earnings),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              )
            : null,
      );
    }).toList();
  }

  Widget _buildGrandTotalCard(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              Icons.payments_rounded,
              color: theme.colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Total Earnings", style: theme.textTheme.labelSmall),
                Text(
                  DuruhaFormatter.formatCurrency(pledge.sellingPrice ?? 0),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleDateFallback(ThemeData theme) {
    return DuruhaSelectionCard(
      title: DateFormat('MMMM d, yyyy').format(harvestDate),
      subtitle:
          "${pledge.cropName} • ${DuruhaFormatter.formatCompactNumber(pledge.quantity)} ${pledge.unit}",
      subtitleWidget: isFinalized && (pledge.sellingPrice ?? 0) > 0
          ? Text(
              "Price: ${DuruhaFormatter.formatCurrency(pledge.sellingPrice ?? 0)}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onPrimary,
              ),
            )
          : null,
      isSelected: false,
      isList: true,
      onTap: onShowDatePicker,
    );
  }
}
