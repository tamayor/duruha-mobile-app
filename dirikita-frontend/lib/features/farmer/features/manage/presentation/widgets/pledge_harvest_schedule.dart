import 'package:flutter/material.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:intl/intl.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_section_container.dart';
import 'package:duruha/core/widgets/duruha_selection_card.dart';

class PledgeHarvestSchedule extends StatelessWidget {
  final HarvestPledge pledge;
  final DateTime harvestDate;
  final List<DateTime> completedDates;
  final String currentStatus;
  final Function(DateTime date, bool newStatus) onToggleHarvest;
  final VoidCallback onShowDatePicker;

  const PledgeHarvestSchedule({
    super.key,
    required this.pledge,
    required this.harvestDate,
    required this.completedDates,
    required this.currentStatus,
    required this.onToggleHarvest,
    required this.onShowDatePicker,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DuruhaSectionContainer(
      title: "Harvest Schedule",
      subtitle:
          pledge.perDatePledges != null && pledge.perDatePledges!.isNotEmpty
          ? "${pledge.perDatePledges!.map((e) => e.date).toSet().length} dates planned"
          : "1 date planned",
      action: (pledge.perDatePledges == null || pledge.perDatePledges!.isEmpty)
          ? TextButton.icon(
              onPressed: onShowDatePicker,
              icon: Icon(
                Icons.edit_calendar_rounded,
                size: 18,
                color: theme.colorScheme.onPrimary,
              ),
              label: Text(
                "Change",
                style: TextStyle(
                  color: theme.colorScheme.onPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            )
          : null,
      children: [
        if (pledge.perDatePledges != null &&
            pledge.perDatePledges!.isNotEmpty) ...[
          ...() {
            // Group by date
            final Map<DateTime, List<HarvestEntry>> grouped = {};
            for (var entry in pledge.perDatePledges!) {
              final d = DateTime(
                entry.date.year,
                entry.date.month,
                entry.date.day,
              );
              grouped.putIfAbsent(d, () => []);
              grouped[d]!.add(entry);
            }

            final sortedDates = grouped.keys.toList()..sort();

            return sortedDates.map((date) {
              final sessionEntries = grouped[date]!;
              final isDateCompleted = completedDates.any(
                (d) =>
                    d.year == date.year &&
                    d.month == date.month &&
                    d.day == date.day,
              );

              final double dateTotalQty = sessionEntries.fold(
                0.0,
                (sum, e) => sum + e.quantity,
              );

              // Use explicit earnings if available, else calculate
              double dateEarnings = sessionEntries.fold(
                0.0,
                (sum, e) => sum + (e.earnings ?? 0.0),
              );

              if (dateEarnings == 0 && (pledge.sellingPrice ?? 0) > 0) {
                final double pricePerUnit =
                    (pledge.sellingPrice ?? 0) /
                    (pledge.quantity > 0 ? pledge.quantity : 1);
                dateEarnings = dateTotalQty * pricePerUnit;
              }

              return DuruhaSelectionCard(
                title: DateFormat('MMMM d, yyyy').format(date),
                subtitle: "", // Base subtitle not used with subtitleWidget
                subtitleWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...sessionEntries.map((e) {
                      final double pricePerUnit =
                          (pledge.sellingPrice ?? 0) /
                          (pledge.quantity > 0 ? pledge.quantity : 1);
                      final double entryEarnings =
                          e.earnings ?? (e.quantity * pricePerUnit);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${e.variety} • ${DuruhaFormatter.formatCompactNumber(e.quantity)} ${pledge.unit}",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSecondary,
                                decoration: isDateCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            if ((currentStatus == 'Sold' ||
                                    currentStatus == 'Done') &&
                                entryEarnings > 0)
                              Text(
                                DuruhaFormatter.formatCurrency(entryEarnings),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                    if ((currentStatus == 'Sold' || currentStatus == 'Done') &&
                        dateEarnings > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary.withAlpha(40),
                              theme.colorScheme.primary.withAlpha(20),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.onPrimary.withAlpha(100),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.payments_rounded,
                              size: 14,
                              color: theme.colorScheme.onPrimary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Total Date Earnings: ${DuruhaFormatter.formatCurrency(dateEarnings)}",
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: theme.colorScheme.onPrimary,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                isSelected: isDateCompleted,
                isList: true,
                icon: Icons.calendar_today_rounded,
                onTap: () => onToggleHarvest(date, !isDateCompleted),
                trailing: IconButton(
                  onPressed: () => onToggleHarvest(date, !isDateCompleted),
                  icon: Icon(
                    isDateCompleted
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: currentStatus == 'Harvest'
                        ? (isDateCompleted
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurfaceVariant.withAlpha(
                                  128,
                                ))
                        : theme.colorScheme.onSurface.withAlpha(25),
                  ),
                ),
              );
            }).toList();
          }(),
          if ((currentStatus == 'Sold' || currentStatus == 'Done') &&
              (pledge.sellingPrice ?? 0) > 0) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.onPrimary,
                      theme.colorScheme.primaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.onPrimary.withAlpha(60),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.payments_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Total Earnings",
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white.withAlpha(200),
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          Text(
                            DuruhaFormatter.formatCurrency(
                              pledge.sellingPrice ?? 0,
                            ),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 26,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ] else
          DuruhaSelectionCard(
            title: DateFormat('MMMM d, yyyy').format(harvestDate),
            subtitle:
                "Primary Harvest Date • ${DuruhaFormatter.formatCompactNumber(pledge.quantity)} ${pledge.unit}",
            subtitleWidget:
                ((currentStatus == 'Sold' || currentStatus == 'Done') &&
                    (pledge.sellingPrice ?? 0) > 0)
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "Earnings: ${DuruhaFormatter.formatCurrency(pledge.sellingPrice ?? 0)}",
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                  )
                : null,
            isSelected: false,
            isList: true,
            icon: Icons.calendar_today_rounded,
            onTap: onShowDatePicker,
          ),
      ],
    );
  }
}
