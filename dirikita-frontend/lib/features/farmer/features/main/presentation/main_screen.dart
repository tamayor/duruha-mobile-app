import 'package:duruha/core/widgets/duruha_button.dart';
import 'package:duruha/core/widgets/duruha_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:duruha/features/farmer/shared/presentation/widgets/navigation.dart';
import 'package:duruha/features/farmer/features/main/data/recommendation_repository.dart';
import 'package:duruha/features/farmer/features/main/domain/recommendation_model.dart';
import 'package:duruha/features/farmer/features/main/presentation/widgets/recommendation_card.dart';
import 'package:duruha/features/farmer/shared/presentation/loading_screen.dart';
import 'package:flutter/services.dart';
import 'package:duruha/core/widgets/duruha_section_container.dart';
import 'package:duruha/features/farmer/shared/data/pledge_repository.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:duruha/features/farmer/features/manage/presentation/widgets/pledge_card.dart';

class FarmerMainScreen extends StatefulWidget {
  const FarmerMainScreen({super.key});

  @override
  State<FarmerMainScreen> createState() => _FarmerDashboardScreenState();
}

class _FarmerDashboardScreenState extends State<FarmerMainScreen> {
  final _repository = CropRecommendationRepository();
  final _pledgeRepository = PledgeRepository();
  List<CropRecommendation> _recommendations = [];
  List<HarvestPledge> _activePledges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final recs = await _repository.getRecommendations();
      final pledges = await _pledgeRepository.fetchMyPledges();

      final now = DateTime.now();
      final active = pledges.where((p) => p.harvestDate.isAfter(now)).toList();
      active.sort((a, b) => a.harvestDate.compareTo(b.harvestDate));

      if (mounted) {
        setState(() {
          _recommendations = recs;
          _activePledges = active;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DuruhaScaffold(
      appBarTitle: 'Farm',
      bottomNavigationBar: FarmerNavigation(
        name: 'Elly Farmer',
        currentRoute: '/farmer/farm',
      ),
      body: _isLoading
          ? const FarmerLoadingScreen()
          : Stack(
              children: [
                // Content
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Content with padding
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildRecommendationsSection(),
                            _buildActivePledgesSection(),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRecommendationsSection() {
    if (_recommendations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            "Recommended for You",
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: _recommendations.map((rec) {
              return RecommendationCard(
                rec: rec,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/farmer/pledge/study',
                    arguments: rec.id,
                  );
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActivePledgesSection() {
    if (_activePledges.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: DuruhaSectionContainer(
        title: "Active Pledges (Top 3)",
        children: [
          ..._activePledges.take(3).map((pledge) {
            return PledgeCard(pledge: pledge, isActive: true);
          }),
          DuruhaButton(
            text: "View Pledge Monitor",
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pushNamed(context, '/farmer/monitor');
            },
          ),
        ],
      ),
    );
  }
}
