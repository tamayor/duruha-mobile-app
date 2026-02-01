import 'package:flutter/material.dart';
import 'package:duruha/features/farmer/shared/presentation/navigation.dart';
import 'package:duruha/features/farmer/shared/presentation/farmer_loading_screen.dart';
import 'package:duruha/features/farmer/shared/data/pledge_repository.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';

import 'package:duruha/features/farmer/shared/presentation/pledge_card.dart';

class MonitorPledgeScreen extends StatefulWidget {
  const MonitorPledgeScreen({super.key});

  @override
  State<MonitorPledgeScreen> createState() => _MonitorPledgeScreenState();
}

class _MonitorPledgeScreenState extends State<MonitorPledgeScreen> {
  final _repository = PledgeRepository();
  bool _isLoading = true;
  List<HarvestPledge> _pledges = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final data = await _repository.fetchMyPledges();
      if (!mounted) return;
      setState(() {
        _pledges = data;
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
        bottomNavigationBar: const FarmerNavigation(
          name: "Elly", // Dynamic name later
          currentRoute: '/farmer/biz',
        ),
        body: _isLoading
            ? const FarmerLoadingScreen()
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
                            return PledgeCard(
                              pledge: activePledges[index],
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
}
