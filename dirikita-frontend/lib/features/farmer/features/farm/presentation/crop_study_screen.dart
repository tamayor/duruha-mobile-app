import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';

import 'package:duruha/features/farmer/features/farm/data/study_repository.dart';
import 'package:duruha/features/farmer/features/farm/domain/study_model.dart';
import 'package:duruha/features/farmer/shared/presentation/farmer_loading_screen.dart';
import 'package:duruha/shared/produce/data/produce_repository.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Re-implementing SparklinePainter inside here to avoid dependency issues if file was deleted

class CropStudyScreen extends StatefulWidget {
  final String cropId;

  const CropStudyScreen({super.key, required this.cropId});

  @override
  State<CropStudyScreen> createState() => _CropStudyScreenState();
}

class _CropStudyScreenState extends State<CropStudyScreen> {
  bool _isLoading = true;
  Produce? _produce;
  CropMarketStudy? _marketStudy;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final allProduce = await ProduceRepository().getAllProduce();
      final produce = allProduce.firstWhere(
        (p) => p.id == widget.cropId,
        orElse: () => allProduce.first,
      );

      final study = await CropStudyRepository().getMarketStudy(widget.cropId);

      if (mounted) {
        setState(() {
          _produce = produce;
          _marketStudy = study;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading crop study data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: FarmerLoadingScreen()));
    }

    if (_produce == null || _marketStudy == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: const Center(child: Text("Crop data not found")),
      );
    }

    final p = _produce!;
    final study = _marketStudy!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // 1. Hero AppBar
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                p.namesByDialect['tagalog'] ?? p.nameEnglish,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    p.imageHeroUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // 2. Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Market Analysis",
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    p.nameEnglish,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Demand vs Supply Card
                  // Demand vs Supply Card
                  DuruhaSectionContainer(
                    title: "Demand Overview",
                    children: [
                      _buildComparisonRow(
                        context,
                        "Local Demand",
                        study.localDemandScore,
                        Colors.orange,
                      ),
                      const SizedBox(height: 16),
                      _buildComparisonRow(
                        context,
                        "National Demand",
                        study.nationalDemandScore,
                        Colors.blue,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Combined Forecast Graph
                  DuruhaSectionContainer(
                    title: "Market Demand Forecast (12-Months)",
                    children: [_buildCombinedMonthlyTimeline(context, study)],
                  ),

                  const SizedBox(height: 20),

                  // Metadata Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    childAspectRatio: 2.5,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      _buildStatTile(
                        context,
                        "Growing Cycle",
                        "${p.growingCycleDays} Days",
                      ),
                      _buildStatTile(
                        context,
                        "Season",
                        "${p.seasonalityStart}-${p.seasonalityEnd}",
                      ),
                      _buildStatTile(
                        context,
                        "Shelf Life",
                        "${p.shelfLifeDays} Days",
                      ),
                      _buildStatTile(
                        context,
                        "Perishability",
                        "${p.perishabilityIndex}/5",
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCombinedMonthlyTimeline(
    BuildContext context,
    CropMarketStudy study,
  ) {
    // Assuming local and national lists are aligned by month
    return Column(
      children: study.localForecasts.asMap().entries.map((entry) {
        final index = entry.key;
        final localData = entry.value;
        final nationalData = study.nationalForecasts.length > index
            ? study.nationalForecasts[index]
            : localData; // Fallback

        final dateParts = localData.month.split('\n');
        final monthName = dateParts.first;
        final year = dateParts.length > 1
            ? dateParts.last
            : DateTime.now().year.toString();

        // Calculate ratios
        final localRatio = (localData.fulfilledKg / localData.demandKg).clamp(
          0.0,
          1.0,
        );
        final nationalRatio = (nationalData.fulfilledKg / nationalData.demandKg)
            .clamp(0.0, 1.0);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: DuruhaInkwell(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pushNamed(
                  context,
                  '/farmer/pledge/create',
                  arguments: {
                    'cropId': widget.cropId,
                    'month': monthName,
                    'year': year,
                  },
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Month Box
                    Container(
                      width: 60,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        localData.month,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Bars Container
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Local Bar Group
                          _buildCompactBarGroup(
                            context,
                            "Local",
                            localData.fulfilledKg,
                            localData.demandKg,
                            localRatio,
                            Colors.orange,
                          ),
                          const SizedBox(height: 8),
                          // National Bar Group
                          _buildCompactBarGroup(
                            context,
                            "National",
                            nationalData.fulfilledKg,
                            nationalData.demandKg,
                            nationalRatio,
                            Colors.blue,
                          ),
                        ],
                      ),
                    ),

                    // Chevron
                    const Padding(
                      padding: EdgeInsets.only(left: 12, top: 16),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCompactBarGroup(
    BuildContext context,
    String label,
    double fulfilled,
    double demand,
    double ratio,
    Color color,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
            ),
            Text(
              "${DuruhaFormatter.formatNumber(fulfilled.toInt())} / ${DuruhaFormatter.formatNumber(demand.toInt())} kg",
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 2),
        DuruhaProgressBar(
          value: ratio,
          color: color,
          backgroundColor: color.withValues(alpha: 0.1),
          height: 8, // Compact height
        ),
      ],
    );
  }

  Widget _buildComparisonRow(
    BuildContext context,
    String label,
    double value,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              "${(value * 100).toInt()}%",
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DuruhaProgressBar(
          value: value,
          color: color,
          backgroundColor: color.withValues(alpha: 0.15),
          height: 12,
        ),
      ],
    );
  }

  Widget _buildStatTile(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
