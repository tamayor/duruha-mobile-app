import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/helpers/duruha_status_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:duruha/core/widgets/duruha_progress_bar.dart';
import 'package:duruha/core/widgets/duruha_section_container.dart';
import 'package:duruha/features/farmer/shared/presentation/navigation.dart';
import 'package:duruha/features/farmer/features/monitor/data/monitor_repository.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:duruha/features/farmer/features/profile/data/profile_repository.dart';

class MonitorPledgeScreen extends StatefulWidget {
  const MonitorPledgeScreen({super.key});

  @override
  State<MonitorPledgeScreen> createState() => _MonitorPledgeScreenState();
}

class _MonitorPledgeScreenState extends State<MonitorPledgeScreen> {
  final _repository = MonitorRepository();
  final _profileRepo = FarmerProfileRepositoryImpl();
  bool _isLoading = true;
  List<HarvestPledge> _pledges = [];
  String _userName = "Farmer";

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final results = await Future.wait([
        _repository.getMyPledges(),
        _profileRepo.getFarmerProfile('current_user'),
      ]);

      if (!mounted) return;
      setState(() {
        _pledges = results[0] as List<HarvestPledge>;
        _userName = (results[1] as dynamic).name.split(' ').first;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filter active vs history
    final now = DateTime.now();
    final activePledges = _pledges
        .where((p) => p.harvestDate.isAfter(now))
        .toList();
    final historyPledges = _pledges
        .where((p) => p.harvestDate.isBefore(now))
        .toList();

    // Sort active by harvest date soonest
    activePledges.sort((a, b) => a.harvestDate.compareTo(b.harvestDate));
    // Sort history by recent
    historyPledges.sort((a, b) => b.harvestDate.compareTo(a.harvestDate));

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text("Monitor Pledge"),
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          centerTitle: true,
          bottom: TabBar(
            labelColor: theme.colorScheme.onPrimary,
            unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
            indicatorColor: theme.colorScheme.primary,
            tabs: const [
              Tab(text: "Active Harvests"),
              Tab(text: "Pledge History"),
            ],
          ),
        ),
        bottomNavigationBar: FarmerNavigation(
          name: _userName,
          currentRoute: '/farmer/biz',
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  // Active Harvests Tab
                  activePledges.isEmpty
                      ? Center(
                          child: Text(
                            "No active pledges.",
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: activePledges.length,
                          itemBuilder: (context, index) {
                            return _buildPledgeCard(
                              context,
                              activePledges[index],
                              isActive: true,
                            );
                          },
                        ),

                  // Pledge History Tab
                  historyPledges.isEmpty
                      ? Center(
                          child: Text(
                            "No pledge history.",
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: historyPledges.length,
                          itemBuilder: (context, index) {
                            return _buildPledgeCard(
                              context,
                              historyPledges[index],
                              isActive: false,
                            );
                          },
                        ),
                ],
              ),
      ),
    );
  }

  Widget _buildPledgeCard(
    BuildContext context,
    HarvestPledge pledge, {
    required bool isActive,
  }) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    // Calculate Progress
    final createdAt =
        pledge.createdAt ?? now.subtract(const Duration(days: 1)); // fallback
    final totalDuration = pledge.harvestDate
        .difference(createdAt)
        .inHours; // Hours for precision
    final elapsed = now.difference(createdAt).inHours;

    // Safety clamp
    double progress = 0.0;
    if (totalDuration > 0) {
      progress = (elapsed / totalDuration).clamp(0.0, 1.0);
    } else {
      progress = 1.0; // Instant
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/farmer/biz/monitor/${pledge.id}',
            arguments: pledge,
          );
        },
        child: DuruhaSectionContainer(
          backgroundColor: theme.colorScheme.primaryContainer.withValues(
            alpha: 0.1,
          ),
          padding: const EdgeInsets.all(16),
          children: [
            // Header: ID and Market Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "ID: ${pledge.id ?? '---'}",
                  style: TextStyle(
                    fontFamily: 'Courier', // Monospace for ID
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: DuruhaStatus.getMarketColor(
                      context,
                      pledge.targetMarket,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: DuruhaStatus.getMarketColor(
                        context,
                        pledge.targetMarket,
                      ).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    pledge.targetMarket,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: DuruhaStatus.getMarketColor(
                        context,
                        pledge.targetMarket,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Main Content: Name and Qty
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.pushNamed(
                      context,
                      '/farmer/crops/${pledge.cropId}',
                    );
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.spa, color: theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.pushNamed(
                        context,
                        '/farmer/crops/${pledge.cropId}',
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pledge.cropNameDialect ?? pledge.cropName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            decoration: TextDecoration.underline,
                            decorationStyle: TextDecorationStyle.dotted,
                          ),
                        ),
                        if (pledge.cropNameDialect != null)
                          Text(
                            pledge.cropName.toUpperCase(),
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        Text(
                          pledge.variants.join(", "),
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "${DuruhaFormatter.formatNumber(pledge.quantity)} ${pledge.unit}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                      ),
                    ),
                    const Text(
                      "Pledged",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),
            // Timeline as Divider
            if (isActive) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDatePoint(
                    context,
                    "Created",
                    createdAt,
                    isToday: false,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          "Harvest Progress",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        DuruhaProgressBar(
                          value: progress,
                          height: 8,
                          backgroundColor: theme.colorScheme.secondary,
                          color: theme.colorScheme.onSecondary,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildDatePoint(
                    context,
                    "Target",
                    pledge.harvestDate,
                    isToday: false,
                  ),
                ],
              ),
            ] else ...[
              // History Divider/Status line
              Container(
                height: 1,
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Text(
                    "Harvested on ${DateFormat('MMM d, yyyy').format(pledge.harvestDate)}",
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Status and Expenses
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      pledge.currentStatus,
                      theme.colorScheme,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    DuruhaStatus.toPresentTense(pledge.currentStatus),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(
                        pledge.currentStatus,
                        theme.colorScheme,
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "TOTAL EXPENSES",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "₱${DuruhaFormatter.formatNumber(pledge.totalExpenses)}",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status, ColorScheme colorScheme) {
    switch (status) {
      case 'Set':
        return Colors.blue;
      case 'Cultivate':
        return Colors.brown;
      case 'Plant':
        return Colors.green;
      case 'Grow':
        return Colors.lightGreen;
      case 'Harvest':
        return Colors.orange;
      case 'Process':
        return Colors.deepOrange;
      case 'Ready to Sell':
        return Colors.teal;
      case 'Sold':
        return Colors.purple;
      default:
        return colorScheme.primary;
    }
  }

  Widget _buildDatePoint(
    BuildContext context,
    String label,
    DateTime date, {
    required bool isToday,
  }) {
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
            color: isToday
                ? theme.colorScheme.onSecondary.withValues(alpha: 0.7)
                : theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}
