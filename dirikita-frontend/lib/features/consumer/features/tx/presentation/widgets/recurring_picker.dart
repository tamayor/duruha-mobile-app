import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Recurrence string format: "freq:interval:days:startDate:endDate"
/// Examples:
///   "weekly:1:MON,WED:2026-03-10:2026-06-10"
///   "monthly:1:15:2026-03-01:2026-09-01"
///   "daily:3:::2026-03-10:2026-06-10"   (no day spec needed for daily)
class RecurringPickerUtil {
  static const daily = 'daily';
  static const weekly = 'weekly';
  static const monthly = 'monthly';

  static const _allWeekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _weekdayLabels = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
  // Dart weekday numbers (1=Mon ... 7=Sun)
  static const _weekdayNumbers = [1, 2, 3, 4, 5, 6, 7];

  static String encode({
    required String frequency,
    required int interval,
    List<String>? weekdays, // for weekly: ['MON','WED']
    int? monthDay, // for monthly: 1-28 or -1 for last
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final daysStr = frequency == weekly
        ? (weekdays ?? []).join(',')
        : frequency == monthly
        ? '${monthDay ?? 1}'
        : '';
    final startStr = startDate != null
        ? DateFormat('yyyy-MM-dd').format(startDate)
        : '';
    final endStr = endDate != null
        ? DateFormat('yyyy-MM-dd').format(endDate)
        : '';
    return '$frequency:$interval:$daysStr:$startStr:$endStr';
  }

  static ({
    String frequency,
    int interval,
    List<String> weekdays,
    int monthDay,
    DateTime? startDate,
    DateTime? endDate,
  })
  decode(String value) {
    final parts = value.split(':');
    // Handle old format "freq:interval" gracefully
    if (parts.length < 3) {
      return (
        frequency: parts.isNotEmpty ? parts[0] : weekly,
        interval: parts.length > 1 ? (int.tryParse(parts[1]) ?? 1) : 1,
        weekdays: [],
        monthDay: 1,
        startDate: null,
        endDate: null,
      );
    }

    final freq = parts[0];
    final interval = int.tryParse(parts[1]) ?? 1;
    final daysStr = parts.length > 2 ? parts[2] : '';
    // dates may contain '-' so we stored as yyyy-MM-dd parts 3 and 4
    // but join back in case split by ':' hit date colons (no colon in yyyy-MM-dd)
    final startStr = parts.length > 3 ? parts[3] : '';
    final endStr = parts.length > 4 ? parts[4] : '';

    List<String> weekdays = [];
    int monthDay = 1;

    if (freq == weekly && daysStr.isNotEmpty) {
      weekdays = daysStr.split(',').where((d) => d.isNotEmpty).toList();
    } else if (freq == monthly && daysStr.isNotEmpty) {
      monthDay = int.tryParse(daysStr) ?? 1;
    }

    return (
      frequency: freq,
      interval: interval,
      weekdays: weekdays,
      monthDay: monthDay,
      startDate: startStr.isNotEmpty ? DateTime.tryParse(startStr) : null,
      endDate: endStr.isNotEmpty ? DateTime.tryParse(endStr) : null,
    );
  }

  /// Short label for the button chip
  static String toLabel(String? value) {
    if (value == null || value.isEmpty) return 'Set Recurring';
    final d = decode(value);
    final n = d.interval;
    switch (d.frequency) {
      case daily:
        return n == 1 ? 'Every Day' : 'Every $n Days';
      case weekly:
        if (d.weekdays.isNotEmpty) {
          final dayLabels = d.weekdays
              .map((w) {
                final idx = _allWeekdays.indexOf(w);
                return idx >= 0 ? _weekdayLabels[idx] : w;
              })
              .join('/');
          return n == 1 ? 'Weekly · $dayLabels' : 'Every $n Wks · $dayLabels';
        }
        return n == 1 ? 'Every Week' : 'Every $n Wks';
      case monthly:
        final suffix = _daySuffix(d.monthDay);
        return n == 1
            ? 'Monthly · ${d.monthDay}$suffix'
            : 'Every $n Months · ${d.monthDay}$suffix';
      default:
        return 'Recurring';
    }
  }

  /// Computes all occurrence dates within the range
  static List<DateTime> computeDates(String value) {
    if (value.isEmpty) return [];
    final d = decode(value);
    if (d.startDate == null || d.endDate == null) return [];

    final dates = <DateTime>[];
    final end = d.endDate!;
    DateTime cursor = d.startDate!;

    // Safety cap
    const maxDates = 200;

    switch (d.frequency) {
      case daily:
        while (!cursor.isAfter(end) && dates.length < maxDates) {
          dates.add(cursor);
          cursor = cursor.add(Duration(days: d.interval));
        }
        break;

      case weekly:
        final targetWeekdays = d.weekdays.isEmpty
            ? [
                _allWeekdays[cursor.weekday - 1],
              ] // default to startDate's weekday
            : d.weekdays;
        // Expand weekdays to dart weekday numbers
        final targetNums = targetWeekdays.map((w) {
          final idx = _allWeekdays.indexOf(w);
          return idx >= 0 ? _weekdayNumbers[idx] : 1;
        }).toSet();

        // Walk week by week (every `interval` weeks), collecting matching days
        // Find the Monday of the start week
        final startMonday = cursor.subtract(Duration(days: cursor.weekday - 1));
        DateTime weekStart = startMonday;

        while (weekStart.isBefore(end.add(const Duration(days: 7))) &&
            dates.length < maxDates) {
          for (int offset = 0; offset < 7; offset++) {
            final day = weekStart.add(Duration(days: offset));
            if (targetNums.contains(day.weekday) &&
                !day.isBefore(cursor) &&
                !day.isAfter(end)) {
              dates.add(DateTime(day.year, day.month, day.day));
            }
          }
          weekStart = weekStart.add(Duration(days: 7 * d.interval));
        }
        break;

      case monthly:
        int month = cursor.month;
        int year = cursor.year;

        while (dates.length < maxDates) {
          final daysInMonth = DateUtils.getDaysInMonth(year, month);
          final targetDay = d.monthDay == -1
              ? daysInMonth
              : d.monthDay.clamp(1, daysInMonth);
          final candidate = DateTime(year, month, targetDay);

          if (candidate.isAfter(end)) break;
          if (!candidate.isBefore(cursor)) {
            dates.add(candidate);
          }

          month += d.interval;
          while (month > 12) {
            month -= 12;
            year++;
          }
        }
        break;
    }

    return dates;
  }

  static String _daySuffix(int day) {
    if (day == -1) return 'th (last)';
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  static List<String> get allWeekdays => _allWeekdays;
  static List<String> get weekdayLabels => _weekdayLabels;
}

// ─────────────────────────────────────────────────────────────────────────────

/// Recurring Picker Sheet — multi-section scrollable form.
class RecurringPickerSheet extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String?> onChanged;
  final DateTime? planStartDate;
  final DateTime? planEndDate;

  const RecurringPickerSheet({
    super.key,
    this.initialValue,
    required this.onChanged,
    this.planStartDate,
    this.planEndDate,
  });

  @override
  State<RecurringPickerSheet> createState() => _RecurringPickerSheetState();
}

class _RecurringPickerSheetState extends State<RecurringPickerSheet> {
  late String _frequency;
  late int _interval;
  late List<String> _weekdays;
  late int _monthDay;
  late DateTime? _startDate;
  late DateTime? _endDate;

  final _dateFormat = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    _initFromValue(widget.initialValue);
  }

  void _initFromValue(String? value) {
    if (value != null && value.isNotEmpty) {
      final d = RecurringPickerUtil.decode(value);
      _frequency = d.frequency;
      _interval = d.interval;
      _weekdays = List.from(d.weekdays);
      _monthDay = d.monthDay;
      _startDate = d.startDate;
      _endDate = d.endDate;
    } else {
      _frequency = RecurringPickerUtil.weekly;
      _interval = 1;
      _weekdays = [];
      _monthDay = 1;
      _startDate = null;
      _endDate = null;
    }
  }

  String get _encoded => RecurringPickerUtil.encode(
    frequency: _frequency,
    interval: _interval,
    weekdays: _weekdays,
    monthDay: _monthDay,
    startDate: _startDate,
    endDate: _endDate,
  );

  String get _unitLabel {
    switch (_frequency) {
      case RecurringPickerUtil.daily:
        return _interval == 1 ? 'day' : 'days';
      case RecurringPickerUtil.weekly:
        return _interval == 1 ? 'week' : 'weeks';
      case RecurringPickerUtil.monthly:
        return _interval == 1 ? 'month' : 'months';
      default:
        return 'weeks';
    }
  }

  List<DateTime> get _computedDates {
    if (_startDate == null || _endDate == null) return [];
    return RecurringPickerUtil.computeDates(_encoded);
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final defaultStart =
        widget.planStartDate ?? now.add(const Duration(days: 21));
    final defaultEnd = widget.planEndDate ?? now.add(const Duration(days: 366));

    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_startDate ?? defaultStart)
          : (_endDate ??
                (_startDate?.add(const Duration(days: 60)) ?? defaultEnd)),
      firstDate: widget.planStartDate ?? now.add(const Duration(days: 21)),
      lastDate: widget.planEndDate ?? now.add(const Duration(days: 366)),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          // If end is before new start, push end out
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = picked.add(const Duration(days: 30));
          }
        } else {
          _endDate = picked;
        }
      });
      widget.onChanged(_encoded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasRule =
        widget.initialValue != null && widget.initialValue!.isNotEmpty;
    final dates = _computedDates;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
        ),
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 16, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.sync_rounded,
                  size: 20,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set Recurrence',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Schedule repeating order dates',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasRule)
                TextButton.icon(
                  onPressed: () {
                    widget.onChanged(null);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Scrollable content
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Section 1: Frequency ──────────────────────────────
                _SectionLabel(
                  label: 'Repeats',
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
                const SizedBox(height: 10),
                Row(
                  children:
                      [
                        {
                          RecurringPickerUtil.daily: (
                            label: 'Daily',
                            icon: Icons.wb_sunny_outlined,
                          ),
                        },
                        {
                          RecurringPickerUtil.weekly: (
                            label: 'Weekly',
                            icon: Icons.view_week_outlined,
                          ),
                        },
                        {
                          RecurringPickerUtil.monthly: (
                            label: 'Monthly',
                            icon: Icons.calendar_month_outlined,
                          ),
                        },
                      ].expand((m) => m.entries).toList().asMap().entries.map((
                        e,
                      ) {
                        final entry = e.value;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(right: e.key < 2 ? 8 : 0),
                            child: _FrequencyChip(
                              label: entry.value.label,
                              icon: entry.value.icon,
                              selected: _frequency == entry.key,
                              onTap: () => setState(() {
                                _frequency = entry.key;
                                _weekdays = [];
                                widget.onChanged(_encoded);
                              }),
                            ),
                          ),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 20),
                // ── Section 2: Interval ───────────────────────────────
                _SectionLabel(
                  label: 'Every',
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
                const SizedBox(height: 10),
                _IntervalStepper(
                  value: _interval,
                  unit: _unitLabel,
                  onChanged: (val) => setState(() {
                    _interval = val;
                    widget.onChanged(_encoded);
                  }),
                ),
                const SizedBox(height: 20),
                // ── Section 3: Day Selection ──────────────────────────
                if (_frequency == RecurringPickerUtil.weekly) ...[
                  _SectionLabel(
                    label: 'On days',
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  const SizedBox(height: 10),
                  _WeekdaySelector(
                    selected: _weekdays,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                    onChanged: (days) => setState(() {
                      _weekdays = days;
                      widget.onChanged(_encoded);
                    }),
                  ),
                  const SizedBox(height: 20),
                ] else if (_frequency == RecurringPickerUtil.monthly) ...[
                  _SectionLabel(
                    label: 'On day of month',
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                  ),
                  const SizedBox(height: 10),
                  _MonthDaySelector(
                    selected: _monthDay,
                    colorScheme: colorScheme,
                    textTheme: textTheme,
                    onChanged: (day) => setState(() {
                      _monthDay = day;
                      widget.onChanged(_encoded);
                    }),
                  ),
                  const SizedBox(height: 20),
                ],
                // ── Section 4: Date Range ─────────────────────────────
                _SectionLabel(
                  label: 'Date range',
                  colorScheme: colorScheme,
                  textTheme: textTheme,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _DatePickerButton(
                        label: 'Start',
                        date: _startDate,
                        dateFormat: _dateFormat,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                        onTap: () => _pickDate(isStart: true),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: colorScheme.onSurfaceVariant,
                        size: 18,
                      ),
                    ),
                    Expanded(
                      child: _DatePickerButton(
                        label: 'End',
                        date: _endDate,
                        dateFormat: _dateFormat,
                        colorScheme: colorScheme,
                        textTheme: textTheme,
                        onTap: _startDate != null
                            ? () => _pickDate(isStart: false)
                            : null,
                      ),
                    ),
                  ],
                ),
                // ── Section 5: Preview ────────────────────────────────
                if (_startDate != null && _endDate != null) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Icon(
                        Icons.event_note_rounded,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Preview · ${dates.length} date${dates.length == 1 ? '' : 's'}',
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (dates.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'No dates match the criteria.\nTry adjusting the days or date range.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: colorScheme.outlineVariant),
                      ),
                      child: Column(
                        children: dates
                            .asMap()
                            .entries
                            .map(
                              (e) => _DatePreviewRow(
                                date: e.value,
                                index: e.key,
                                total: dates.length,
                                colorScheme: colorScheme,
                                textTheme: textTheme,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                ],
                // Bottom spacing for footer
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        // ── Footer ────────────────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            MediaQuery.paddingOf(context).bottom + 16,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
          ),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                widget.onChanged(_encoded);
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                dates.isNotEmpty ? 'Confirm ${dates.length} Dates' : 'Done',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub widgets

class _SectionLabel extends StatelessWidget {
  final String label;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _SectionLabel({
    required this.label,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: textTheme.labelSmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _FrequencyChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _FrequencyChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? c.primary : c.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? c.primary : c.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? c.onPrimary : c.onSurfaceVariant,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? c.onPrimary : c.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntervalStepper extends StatelessWidget {
  final int value;
  final String unit;
  final ValueChanged<int> onChanged;

  const _IntervalStepper({
    required this.value,
    required this.unit,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: c.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.outlineVariant),
      ),
      child: Row(
        children: [
          _Step(
            icon: Icons.remove_rounded,
            onTap: value > 1 ? () => onChanged(value - 1) : null,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '$value',
                  style: t.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  unit,
                  style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                ),
              ],
            ),
          ),
          _Step(
            icon: Icons.add_rounded,
            onTap: value < 12 ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _Step({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return Material(
      color: enabled ? c.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            size: 22,
            color: enabled ? c.primary : c.outlineVariant,
          ),
        ),
      ),
    );
  }
}

class _WeekdaySelector extends StatelessWidget {
  final List<String> selected;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final ValueChanged<List<String>> onChanged;

  const _WeekdaySelector({
    required this.selected,
    required this.colorScheme,
    required this.textTheme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final days = RecurringPickerUtil.weekdayLabels;
    final keys = RecurringPickerUtil.allWeekdays;
    return Row(
      children: days.asMap().entries.map((e) {
        final key = keys[e.key];
        final isSelected = selected.contains(key);
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: e.key < days.length - 1 ? 4 : 0),
            child: GestureDetector(
              onTap: () {
                final updated = List<String>.from(selected);
                if (isSelected) {
                  updated.remove(key);
                } else {
                  updated.add(key);
                }
                onChanged(updated);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.outlineVariant,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MonthDaySelector extends StatelessWidget {
  final int selected;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final ValueChanged<int> onChanged;

  const _MonthDaySelector({
    required this.selected,
    required this.colorScheme,
    required this.textTheme,
    required this.onChanged,
  });

  String _suffix(int day) {
    if (day == -1) return 'Last';
    if (day >= 11 && day <= 13) return '${day}th';
    switch (day % 10) {
      case 1:
        return '${day}st';
      case 2:
        return '${day}nd';
      case 3:
        return '${day}rd';
      default:
        return '${day}th';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show 1-28 + Last day
    final days = [...List.generate(28, (i) => i + 1), -1];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: days.map((day) {
        final isSelected = selected == day;
        return GestureDetector(
          onTap: () => onChanged(day),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Text(
              _suffix(day),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _DatePickerButton extends StatelessWidget {
  final String label;
  final DateTime? date;
  final DateFormat dateFormat;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback? onTap;

  const _DatePickerButton({
    required this.label,
    required this.date,
    required this.dateFormat,
    required this.colorScheme,
    required this.textTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasDate = date != null;
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: hasDate
              ? colorScheme.primaryContainer.withValues(alpha: 0.5)
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasDate
                ? colorScheme.primary.withValues(alpha: 0.5)
                : colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: hasDate
                      ? colorScheme.primary
                      : (enabled
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.outlineVariant),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    hasDate ? dateFormat.format(date!) : 'Pick date',
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: hasDate ? FontWeight.w600 : FontWeight.normal,
                      color: hasDate
                          ? colorScheme.onSurface
                          : (enabled
                                ? colorScheme.onSurfaceVariant
                                : colorScheme.outlineVariant),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DatePreviewRow extends StatelessWidget {
  final DateTime date;
  final int index;
  final int total;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _DatePreviewRow({
    required this.date,
    required this.index,
    required this.total,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = index == total - 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE').format(date),
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                Text(
                  DateFormat('MMM d, yyyy').format(date),
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.local_shipping_outlined,
            size: 16,
            color: colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Shows the recurring picker as a modal bottom sheet.
Future<void> showRecurringPicker({
  required BuildContext context,
  String? initialValue,
  required ValueChanged<String?> onChanged,
  DateTime? planStartDate,
  DateTime? planEndDate,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.92,
    ),
    builder: (_) => RecurringPickerSheet(
      initialValue: initialValue,
      onChanged: onChanged,
      planStartDate: planStartDate,
      planEndDate: planEndDate,
    ),
  );
}
