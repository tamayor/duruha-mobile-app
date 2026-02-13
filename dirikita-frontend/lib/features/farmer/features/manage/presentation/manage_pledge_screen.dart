import 'package:flutter/material.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:duruha/features/farmer/features/manage/presentation/widgets/pledge_card.dart';

class ManagePledgeScreen extends StatelessWidget {
  final List<HarvestPledge> pledges;

  const ManagePledgeScreen({super.key, required this.pledges});

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
      child: DuruhaScrollHideWrapper(
        bar: const DuruhaTabBar(
          tabs: [
            Tab(text: "Active Harvests"),
            Tab(text: "Pledge History"),
          ],
        ),
        body: TabBarView(
          children: [
            // Active Harvests Tab
            activePledges.isEmpty
                ? _buildEmptyState(
                    theme,
                    Icons.eco_outlined,
                    "No active pledges.",
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

            // Pledge History Tab
            historyPledges.isEmpty
                ? _buildEmptyState(
                    theme,
                    Icons.history_toggle_off,
                    "No pledge history.",
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
