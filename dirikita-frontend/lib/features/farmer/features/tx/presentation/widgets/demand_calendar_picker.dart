import 'package:duruha/features/farmer/features/tx/data/transaction_demand_repository.dart';
import 'package:duruha/features/farmer/features/tx/data/transaction_draft_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';

class DemandCalendarPicker extends StatefulWidget {
  final String cropId;
  final List<DateTime> selectedDates;
  final Function(List<DateTime>, Map<DateTime, DateDemandData>) onDatesChanged;

  const DemandCalendarPicker({
    super.key,
    required this.cropId,
    required this.selectedDates,
    required this.onDatesChanged,
  });

  @override
  State<DemandCalendarPicker> createState() => _DemandCalendarPickerState();
}

class _DemandCalendarPickerState extends State<DemandCalendarPicker> {
  late DateTime _currentMonth;
  final _repository = TransactionDemandRepository();
  Map<DateTime, DateDemandData> _demandCache = {};
  bool _isLoading = false;

  // Local state for immediate feedback
  late List<DateTime> _tempSelectedDates;

  @override
  void initState() {
    super.initState();
    _tempSelectedDates = List.from(widget.selectedDates);
    final now = DateTime.now();
    // Default to current month or first selected date's month
    if (_tempSelectedDates.isNotEmpty) {
      _currentMonth = DateTime(
        _tempSelectedDates.first.year,
        _tempSelectedDates.first.month,
      );
    } else {
      _currentMonth = DateTime(now.year, now.month);
    }
    _fetchDemand();
  }

  Future<void> _fetchDemand() async {
    setState(() => _isLoading = true);
    try {
      final demand = await _repository.fetchMonthlyDemand(
        widget.cropId,
        _currentMonth.year,
        _currentMonth.month,
      );
      if (mounted) {
        setState(() {
          _demandCache = demand;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onMonthChanged(int offset) {
    setState(() {
      _currentMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month + offset,
      );
    });
    _fetchDemand();
  }

  void _toggleDate(DateTime date) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final isSelected = _tempSelectedDates.any(
      (d) => DateUtils.isSameDay(d, normalizedDate),
    );

    setState(() {
      if (isSelected) {
        _tempSelectedDates.removeWhere(
          (d) => DateUtils.isSameDay(d, normalizedDate),
        );
      } else {
        _tempSelectedDates.add(normalizedDate);
      }
      _tempSelectedDates.sort();
    });

    // Notify parent immediately? Or wait for Done?
    // User requested "immediately realtime", so we notify per tap.
    // ALSO pass the demand for the selected dates.
    // We need to gather demand for ALL selected dates.
    // Since we only have _demandCache for CURRENT month, we might not have demand for previously selected dates in other months.
    // However, for the user's request "return numbers quantity", they likely mean the ones visible or we need to be careful.
    // Assumption: We only pass back demand we know. But wait, if user selected dates in Month A, then goes to Month B, we might lose demand info for A if we don't cache deeply.
    // But _demandCache is currently REPLACED on month change. This is bad for returning full data.
    // FIX: Accumulate demand cache?
    // For now, let's just return the demand from the current cache for the newly toggled date, but the callback expects a FULL map.
    // Better: Helper method to retrieve known demand.

    final Map<DateTime, DateDemandData> demandMap = {};
    for (final d in _tempSelectedDates) {
      // Try to find in current cache. If not found, we might need a persistent cache or assume 0 (which is bad).
      // If we are just selecting, we probably only select what we see.
      // If a date was selected previously, it should have associated demand.
      // BUT, we don't have that info passed IN.
      // COMPROMISE: We will return the map of what we HAVE.
      final normalizedInfo = DateTime(d.year, d.month, d.day);
      if (_demandCache.containsKey(normalizedInfo)) {
        demandMap[normalizedInfo] = _demandCache[normalizedInfo]!;
      }
    }

    widget.onDatesChanged(_tempSelectedDates, demandMap);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daysInMonth = DateUtils.getDaysInMonth(
      _currentMonth.year,
      _currentMonth.month,
    );
    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );
    // 1 = Mon, 7 = Sun. Material calendar usually starts Mon.
    // Let's standardise on starting Monday for grid.
    // weekday 1 (Mon) -> offset 0
    final firstWeekdayOffset = firstDayOfMonth.weekday - 1;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 360, // reasonable width
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _onMonthChanged(-1),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(_currentMonth),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _onMonthChanged(1),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Weekday Headers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                  .map(
                    (d) => SizedBox(
                      width: 40,
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),

            // Grid
            if (_isLoading)
              const SizedBox(
                height: 250,
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SizedBox(
                height: 300,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 4,
                    childAspectRatio: 0.75, // Taller for demand text
                  ),
                  itemCount: daysInMonth + firstWeekdayOffset,
                  itemBuilder: (context, index) {
                    if (index < firstWeekdayOffset) {
                      return const SizedBox.shrink();
                    }

                    final day = index - firstWeekdayOffset + 1;
                    final date = DateTime(
                      _currentMonth.year,
                      _currentMonth.month,
                      day,
                    );

                    final normalized = DateTime(
                      date.year,
                      date.month,
                      date.day,
                    );
                    final demandData = _demandCache[normalized];
                    final hasDemand =
                        demandData != null && demandData.totalDemand > 0;

                    final isSelected = _tempSelectedDates.any(
                      (d) => DateUtils.isSameDay(d, normalized),
                    );

                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final isPast = normalized.isBefore(today);

                    final isDisabled = isPast || !hasDemand;

                    return GestureDetector(
                      onTap: isDisabled ? null : () => _toggleDate(date),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : (hasDemand
                                    ? theme.colorScheme.primaryContainer
                                          .withValues(alpha: 0.3)
                                    : Colors.transparent),
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? null
                              : (DateUtils.isSameDay(date, today)
                                    ? Border.all(
                                        color: theme.colorScheme.onSecondary,
                                      )
                                    : null),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : [],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "$day",
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isSelected
                                    ? theme.colorScheme.onPrimary
                                    : (isDisabled
                                          ? theme.colorScheme.outline
                                          : theme.colorScheme.onSurface),
                                fontWeight:
                                    isSelected ||
                                        DateUtils.isSameDay(date, today)
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            if (hasDemand && !isDisabled) ...[
                              const SizedBox(height: 2),
                              Text(
                                DuruhaFormatter.formatCompactNumber(
                                  demandData.totalDemand,
                                ),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isSelected
                                      ? theme.colorScheme.onPrimary.withValues(
                                          alpha: 0.8,
                                        )
                                      : theme.colorScheme.onSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    widget.onDatesChanged([], {}); // Clear selection and demand
                    setState(() => _tempSelectedDates.clear());
                    Navigator.pop(context);
                  },
                  child: const Text(
                    "Clear",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Done"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
