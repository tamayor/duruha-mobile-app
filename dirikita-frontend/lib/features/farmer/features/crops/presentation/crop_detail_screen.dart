import 'package:duruha/features/farmer/shared/presentation/farmer_loading_screen.dart';
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
          return Scaffold(
            appBar: AppBar(title: const Text("Error")),
            body: Center(child: Text("Error: ${snapshot.error}")),
          );
        }

        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: FarmerLoadingScreen()));
        }

        final data = snapshot.data!;
        final summary = data.summary;
        final produce = data.produce;
        final history = data.history;

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              // --- APP BAR ---
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    summary.nameDialect.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,

                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(produce.imageHeroUrl, fit: BoxFit.cover),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- CONTENT ---
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
                              "Past records of harvested and sold pledges.",
                          action: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Colors.green.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "TOTAL EARNINGS",
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  DuruhaFormatter.formatCurrency(totalEarnings),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          children: [
                            ...soldHistory.map(
                              (p) => _buildPledgeTile(context, p),
                            ),
                            if (soldHistory.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(24.0),
                                  child: Text(
                                    "No sales records yet.",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
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
              "${DuruhaFormatter.formatCurrency(p.priceMinHistorical, decimalDigits: 0)} - ${DuruhaFormatter.formatCurrency(p.priceMaxHistorical, decimalDigits: 0)}",
              Icons.attach_money,
            ),
            _buildInfoCard(
              context,
              width,
              "Seasonality",
              "${p.seasonalityStart} - ${p.seasonalityEnd}",
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSecondary),
          const SizedBox(height: 8),
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
    );
  }

  Widget _buildPledgeTile(BuildContext context, CropPledgeHistoryItem p) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
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
                            DuruhaFormatter.formatCurrency(p.amount * p.price!),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
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
          ),
        ],
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
