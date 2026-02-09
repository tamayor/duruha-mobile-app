import 'package:flutter/material.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:duruha/features/farmer/features/manage/presentation/widgets/pledge_card.dart';

class ManageOfferScreen extends StatelessWidget {
  final List<HarvestPledge> pledges;

  const ManageOfferScreen({super.key, required this.pledges});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    // Filter active vs history
    final activePledges = pledges
        .where((p) => p.harvestDate.isAfter(now))
        .toList();
    final historyPledges = pledges
        .where((p) => p.harvestDate.isBefore(now))
        .toList();

    // Sort active by harvest date soonest
    activePledges.sort((a, b) => a.harvestDate.compareTo(b.harvestDate));
    // Sort history by recent
    historyPledges.sort((a, b) => b.harvestDate.compareTo(a.harvestDate));

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // Tab Bar
          Container(
            color: theme.colorScheme.surface,
            child: TabBar(
              labelColor: theme.colorScheme.onTertiary,
              unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
              labelStyle: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: theme.textTheme.titleMedium,
              indicatorColor: theme.colorScheme.onTertiary,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: "Active Offers"),
                Tab(text: "Offer History"),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Active Offers Tab
                activePledges.isEmpty
                    ? _buildEmptyState(
                        theme,
                        Icons.local_offer_outlined,
                        "No active offers.",
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: activePledges.length,
                        itemBuilder: (context, index) {
                          return PledgeCard(
                            pledge: activePledges[index],
                            isActive: true,
                          );
                        },
                      ),

                // Offer History Tab
                historyPledges.isEmpty
                    ? _buildEmptyState(
                        theme,
                        Icons.history,
                        "No offer history.",
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: historyPledges.length,
                        itemBuilder: (context, index) {
                          return PledgeCard(
                            pledge: historyPledges[index],
                            isActive: false,
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
