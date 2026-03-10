import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/farmer/features/manage/pledges/domain/pledge_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PledgeCard extends StatelessWidget {
  final FarmerPledgeGroup pledge;
  final int index;

  const PledgeCard({super.key, required this.pledge, required this.index});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Calculate totals
    final totalQty = pledge.pledgesSchedule.fold<double>(
      0.0,
      (sum, item) => sum + item.quantity,
    );
    final upcomingDates = pledge.pledgesSchedule
        .where(
          (e) => e.dateNeeded.isAfter(
            DateTime.now().subtract(const Duration(days: 1)),
          ),
        )
        .toList();

    return DuruhaInkwell(
      variation: InkwellVariation.brand,
      onTap: () {
        // TODO: Navigate to detail screen if needed
      },
      child: DuruhaSectionContainer(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (pledge.produceLocalName.isNotEmpty)
                      Text(
                        pledge.produceLocalName.toUpperCase(),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurfaceVariant,
                          letterSpacing: 0.5,
                          fontSize: 8,
                        ),
                      ),
                    Text(
                      pledge.varietyName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (pledge.produceForm.isNotEmpty)
                      Text(
                        pledge.produceForm,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${DuruhaFormatter.formatNumber(totalQty)} kg',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    '${pledge.pledgesSchedule.length} allocations',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: 10),

          // Show upcoming dates
          if (upcomingDates.isNotEmpty) ...[
            Text(
              'UPCOMING SCHEDULE',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 8,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 6),
            ...upcomingDates
                .take(3)
                .map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 10,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          DateFormat('MMM d, EEEE').format(e.dateNeeded),
                          style: theme.textTheme.labelSmall,
                        ),
                        const Spacer(),
                        Text(
                          '${DuruhaFormatter.formatNumber(e.quantity)} kg',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            if (upcomingDates.length > 3)
              Text(
                '+ ${upcomingDates.length - 3} more dates',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontStyle: FontStyle.italic,
                  fontSize: 7,
                ),
              ),
          ] else
            Text(
              'No upcoming schedules',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}
