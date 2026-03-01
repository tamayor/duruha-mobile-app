import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DuruhaDateRangePicker extends StatelessWidget {
  final String? label;
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(DateTimeRange) onDateRangePicked;
  final String? startPlaceholder;
  final String? endPlaceholder;

  const DuruhaDateRangePicker({
    super.key,
    this.label,
    required this.startDate,
    required this.endDate,
    required this.onDateRangePicked,
    this.startPlaceholder = 'Start',
    this.endPlaceholder = 'End',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
        ],
        Material(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.3,
          ),
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () async {
              final now = DateTime.now();
              final initialStart = startDate ?? now;
              final initialEnd =
                  endDate ?? initialStart.add(const Duration(days: 1));

              final picked = await showDateRangePicker(
                context: context,
                firstDate: now,
                lastDate: DateTime(2101),
                initialDateRange: DateTimeRange(
                  start: initialStart,
                  end: initialEnd.isBefore(initialStart)
                      ? initialStart
                      : initialEnd,
                ),
                builder: (context, child) {
                  return Theme(
                    data: theme.copyWith(
                      colorScheme: theme.colorScheme.copyWith(
                        surface: theme.colorScheme.surface,
                        onSurface: theme.colorScheme.onSurface,
                      ),
                      datePickerTheme: DatePickerThemeData(
                        dayForegroundColor: WidgetStateProperty.resolveWith((
                          states,
                        ) {
                          if (states.contains(WidgetState.disabled)) {
                            return theme.colorScheme.onSurface.withValues(
                              alpha: 0.1,
                            );
                          }
                          return null; // use default
                        }),
                        yearForegroundColor: WidgetStateProperty.resolveWith((
                          states,
                        ) {
                          if (states.contains(WidgetState.disabled)) {
                            return theme.colorScheme.onSurface.withValues(
                              alpha: 0.1,
                            );
                          }
                          return null; // use default
                        }),
                      ),
                    ),
                    child: child!,
                  );
                },
              );

              if (picked != null) {
                onDateRangePicked(picked);
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.date_range_rounded,
                    size: 18,
                    color: theme.colorScheme.onPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          startDate != null
                              ? dateFormat.format(startDate!)
                              : (startPlaceholder ?? ''),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: startDate != null
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.arrow_right_alt_rounded,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          endDate != null
                              ? (endDate!.year >= 2100
                                    ? 'Infinity'
                                    : dateFormat.format(endDate!))
                              : (endPlaceholder ?? ''),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: endDate != null
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
