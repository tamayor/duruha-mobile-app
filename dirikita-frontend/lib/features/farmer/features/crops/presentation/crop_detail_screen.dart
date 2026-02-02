import 'package:duruha/features/farmer/shared/presentation/loading_screen.dart';
import 'package:duruha/shared/produce/data/produce_repository.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/farmer/features/crops/data/crop_details_repository.dart';
import 'package:duruha/features/farmer/features/crops/data/selected_crops_repository.dart';
import 'package:duruha/features/farmer/features/crops/domain/crop_detail_models.dart';
import 'package:duruha/features/farmer/features/crops/domain/selected_crop_summary.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

class CropDetailScreen extends StatefulWidget {
  final String cropId;

  const CropDetailScreen({super.key, required this.cropId});

  @override
  State<CropDetailScreen> createState() => _CropDetailScreenState();
}

class _CropDetailScreenState extends State<CropDetailScreen> {
  late Future<_CropDetailData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_CropDetailData> _loadData() async {
    // 1. Fetch Summary (Rank, Pledge Label)
    final summaries = await SelectedCropsRepository().fetchSelectedCrops();
    final summary = summaries.firstWhere(
      (s) => s.id == widget.cropId,
      orElse: () => throw Exception("Crop not found in summaries"),
    );

    // 2. Fetch Metadata (Simulated from central list)
    final allProduce = await ProduceRepository().getAllProduce();
    final produce = allProduce.firstWhere(
      (p) => p.id == widget.cropId,
      orElse: () => throw Exception("Produce metadata not found"),
    );

    // 3. Fetch Pledge History (Now from Repos)
    final history = await CropDetailsRepository().getPledgeHistory(
      widget.cropId,
    );
    return _CropDetailData(summary, produce, history);
  }

  @override
  Widget build(BuildContext context) {
    // ... (UI code essentially same, just generic updates if any names changed)
    // Actually internal variable names match CropPledgeHistoryItem fields.
    // ...
    final theme = Theme.of(context);

    return FutureBuilder<_CropDetailData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const FarmerLoadingScreen();
        }

        if (snapshot.hasError) {
          return DuruhaScaffold(
            appBarTitle: "Error",
            body: Center(child: Text("Error: ${snapshot.error}")),
          );
        }

        if (!snapshot.hasData) {
          return const DuruhaScaffold(
            appBarTitle: "Loading",
            body: Center(child: FarmerLoadingScreen()),
          );
        }

        final data = snapshot.data!;
        final summary = data.summary;
        final produce = data.produce;
        final history = data.history;

        // Note: DuruhaScaffold handles system UI overlay style via DuruhaAppBar

        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: CustomScrollView(
            slivers: [
              // 1. HERO SLIVER APPBAR
              DuruhaSliverAppBar(
                title: summary.nameDialect.toUpperCase(),
                imageUrl: produce.imageHeroUrl,
                expandedHeight: 300,
              ),

              // 2. CONTENT
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HEADER INFO
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  produce.nameEnglish,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  produce.nameScientific,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "#${summary.rank} Top Pick",
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // METADATA GRID
                      DuruhaSectionContainer(
                        title: "Crop Insights",
                        children: [_buildInfoGrid(context, produce)],
                      ),

                      const SizedBox(height: 24),

                      // PLEDGE HISTORY (Sold Only)
                      () {
                        final soldHistory = history
                            .where((p) => p.status == 'Sold')
                            .toList();
                        final totalEarnings = soldHistory.fold<double>(
                          0,
                          (sum, p) => sum + (p.amount * (p.price ?? 0)),
                        );

                        return DuruhaSectionContainer(
                          title: "Sales History",
                          subtitle:
                              "Past records of harvested\nand sold pledges.",
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 24,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    "TOTAL EARNINGS",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DuruhaFormatter.formatCurrency(
                                      totalEarnings,
                                    ),
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(),
                            ...soldHistory.map(
                              (p) => _buildPledgeTile(context, p),
                            ),
                          ],
                        );
                      }(),

                      const SizedBox(height: 80), // Bottom padding
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoGrid(BuildContext context, Produce p) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth / 2 - 10;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildInfoCard(
              context,
              width,
              "Market Price",
              "${DuruhaFormatter.formatCurrency(p.priceMinHistorical, decimalDigits: 0)}\n${DuruhaFormatter.formatCurrency(p.priceMaxHistorical, decimalDigits: 0)}",
              Icons.attach_money,
            ),
            _buildInfoCard(
              context,
              width,
              "Seasonality",
              "${p.seasonalityStart}\n${p.seasonalityEnd}",
              Icons.calendar_month,
            ),
            _buildInfoCard(
              context,
              width,
              "Growing Cycle",
              "${p.growingCycleDays} days",
              Icons.timer,
            ),
            _buildInfoCard(
              context,
              width,
              "Fair Guide",
              "${DuruhaFormatter.formatCurrency(p.currentFairMarketGuideline, decimalDigits: 0)}/${p.unitOfMeasure}",
              Icons.balance,
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    double width,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSecondary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPledgeTile(BuildContext context, CropPledgeHistoryItem p) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DuruhaInkwell(
        onTap: () {
          // Navigate to pledge detail screen
          Navigator.pushNamed(context, '/farmer/monitor/${p.id.toLowerCase()}');
        },
        backgroundColor: theme.colorScheme.surface,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${DuruhaFormatter.formatNumber(p.amount)} ${p.unit}",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      if (p.price != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              DuruhaFormatter.formatCurrency(
                                p.amount * p.price!,
                              ),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onPrimary,
                              ),
                            ),
                            Text(
                              "@ ₱${DuruhaFormatter.formatNumber(p.price!)}/unit",
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        p.variety,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            DateFormat('MMM d, yyyy').format(p.date),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _CropDetailData {
  final SelectedCropSummary summary;
  final Produce produce;
  final List<CropPledgeHistoryItem> history;

  _CropDetailData(this.summary, this.produce, this.history);
}
