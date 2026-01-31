import 'package:flutter/material.dart';
import 'package:duruha/features/farmer/shared/presentation/navigation.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/farmer/features/farm/data/recommendation_repository.dart';
import 'package:duruha/features/farmer/features/farm/domain/recommendation_model.dart';
import 'package:duruha/features/farmer/features/farm/presentation/recommendation_card.dart';

class FarmerDashboardScreen extends StatefulWidget {
  const FarmerDashboardScreen({super.key});

  @override
  State<FarmerDashboardScreen> createState() => _FarmerDashboardScreenState();
}

class _FarmerDashboardScreenState extends State<FarmerDashboardScreen> {
  final _repository = CropRecommendationRepository();
  List<CropRecommendation> _recommendations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    try {
      final data = await _repository.getRecommendations();
      if (mounted) {
        setState(() {
          _recommendations = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Farmer Dashboard')),
      bottomNavigationBar: FarmerNavigation(
        name: 'Elly Farmer',
        currentRoute: '/farmer/farm',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Welcome, Farmer!',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  _buildRecommendationsSection(),

                  const SizedBox(height: 40),
                ],
              ),
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
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
}
