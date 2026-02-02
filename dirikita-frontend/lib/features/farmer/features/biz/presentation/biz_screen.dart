import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/features/farmer/features/biz/data/biz_repository.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:duruha/features/farmer/shared/presentation/farmer_loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/farmer/shared/presentation/navigation.dart';
import 'package:intl/intl.dart';

class FarmerBizScreen extends StatefulWidget {
  const FarmerBizScreen({super.key});

  @override
  State<FarmerBizScreen> createState() => _FarmerBizScreenState();
}

class _FarmerBizScreenState extends State<FarmerBizScreen> {
  final _repository = BizRepository();
  bool _isLoading = true;
  List<HarvestPledge> _allPledges = [];
  bool _isFilterVisible = false;

  // Default year-over-year: Start from 1 year ago, End at today
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 365));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final pledges = await _repository.fetchSalesRecords();
      if (mounted) {
        setState(() {
          _allPledges = pledges;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleFilter() {
    setState(() {
      _isFilterVisible = !_isFilterVisible;
    });
  }

  void _hideFilter() {
    if (_isFilterVisible) {
      setState(() {
        _isFilterVisible = false;
      });
    }
  }

  List<HarvestPledge> get _filteredSoldPledges {
    return _allPledges.where((p) {
      final isSold = p.currentStatus == 'Sold';
      final isWithinRange =
          p.harvestDate.isAfter(_startDate) &&
          p.harvestDate.isBefore(_endDate.add(const Duration(days: 1)));
      return isSold && isWithinRange;
    }).toList();
  }

  Map<String, List<HarvestPledge>> get _groupedByCrop {
    final Map<String, List<HarvestPledge>> grouped = {};
    for (var p in _filteredSoldPledges) {
      final key = p.cropNameDialect ?? p.cropName;
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(p);
    }
    return grouped;
  }

  double get _totalRevenue {
    return _filteredSoldPledges.fold(
      0,
      (sum, p) => sum + (p.quantity * (p.sellingPrice ?? 0)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Business Hub"),
        centerTitle: true,
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _toggleFilter,
            icon: Icon(
              Icons.calendar_today_rounded,
              color: _isFilterVisible ? theme.colorScheme.primary : null,
            ),
            tooltip: "Filter Date Range",
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: const FarmerNavigation(
        name: "Elly",
        currentRoute: '/farmer/biz',
      ),
      body: _isLoading
          ? const FarmerLoadingScreen()
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _fetchData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Monitor Pledge Button
                        DuruhaButton(
                          text: "Open Pledge Monitor",
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.pushNamed(context, '/farmer/monitor');
                          },
                        ),
                        const SizedBox(height: 24),

                        // Revenue Summary Header
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.primary,
                                colorScheme.secondary,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.2,
                                ),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "TOTAL EARNINGS IN PERIOD",
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onPrimary.withValues(
                                    alpha: 0.8,
                                  ),
                                  letterSpacing: 1.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                DuruhaFormatter.formatCurrency(_totalRevenue),
                                style: theme.textTheme.headlineLarge?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  _buildMiniStat(
                                    context,
                                    "Sales",
                                    "${_filteredSoldPledges.length}",
                                  ),
                                  const SizedBox(width: 24),
                                  _buildMiniStat(
                                    context,
                                    "Crops sold",
                                    "${_groupedByCrop.length}",
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        Text(
                          "Earnings by Crop",
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (_groupedByCrop.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40.0),
                              child: Text(
                                "No sales found in this period.",
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          )
                        else
                          ..._groupedByCrop.entries.map(
                            (entry) => _buildCropGroup(entry.key, entry.value),
                          ),

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
                if (_isFilterVisible) ...[
                  // Barrier
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _hideFilter,
                      behavior: HitTestBehavior.opaque,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  // Popup
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(16),
                      color: theme.colorScheme.surface,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.1,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "Filter Date Range",
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildDateRangeFilter(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildDateRangeFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _buildDateButton(
              label: "Start Date",
              date: _startDate,
              onTap: () => _selectDate(true),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
          ),
          Expanded(
            child: _buildDateButton(
              label: "End Date",
              date: _endDate,
              onTap: () => _selectDate(false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateButton({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DuruhaInkwell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          // Using surfaceContainerHighest gives it a subtle contrast from the card it sits in
          color: colorScheme.surface.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Left Side: Label and Date
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, yyyy').format(date),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight:
                          FontWeight.w900, // Thick font for "Excitement"
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            // Right Side: Visual Cue
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                size: 15,
                color: colorScheme.onSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Widget _buildCropGroup(String cropName, List<HarvestPledge> pledges) {
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
        children: [...pledges.map((p) => _buildTransactionTile(p))],
      ),
    );
  }

  Widget _buildTransactionTile(HarvestPledge p) {
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

  Widget _buildMiniStat(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onPrimary.withValues(alpha: 0.6),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
