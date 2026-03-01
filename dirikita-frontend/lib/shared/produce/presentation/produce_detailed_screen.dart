import 'package:duruha/core/helpers/duruha_color_helper.dart';
import 'package:duruha/shared/produce/presentation/produce_varieties_screen.dart';
import 'package:duruha/shared/produce/presentation/widgets/produce_dialect_widget.dart';

import 'package:flutter/material.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:duruha/shared/produce/data/produce_repository.dart';
import 'package:duruha/shared/produce/presentation/widgets/variety_widgets.dart';
import 'package:duruha/shared/produce/domain/produce_variety.dart';
import 'package:duruha/core/services/session_service.dart';

class ProduceDetailedScreen extends StatefulWidget {
  final String produceId;
  const ProduceDetailedScreen({super.key, required this.produceId});

  @override
  State<ProduceDetailedScreen> createState() => _ProduceDetailedScreenState();
}

class _ProduceDetailedScreenState extends State<ProduceDetailedScreen> {
  final _repository = ProduceRepository();
  final _varietiesSectionKey = GlobalKey<VarietiesSectionState>();
  Produce? _details;
  List<ProduceVariety> _localVarieties = [];
  bool _isLoading = true;
  bool _isFavorite = false;
  String? _errorMessage;
  String? _userDialect;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final details = await _repository.fetchProduceById(widget.produceId);
      final userId = await SessionService.getUserId();
      final user = await SessionService.getSavedUser();

      if (userId != null && user != null) {
        final favs = await _repository.fetchFavoriteProduceIds(
          userId,
          user.role?.name.toUpperCase(),
        );
        _isFavorite = favs.contains(widget.produceId);
        if (user.dialect.isNotEmpty) {
          _userDialect = user.dialect.first;
        }
      }

      if (!mounted) return;
      if (details == null) throw Exception("Produce not found");
      final produce = details;
      setState(() {
        _details = produce;
        _localVarieties = List.from(produce.varieties);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = "Failed to load produce details";
      });
      DuruhaSnackBar.showError(context, _errorMessage!);
    }
  }

  Future<void> _toggleFavorite() async {
    final userId = await SessionService.getUserId();
    final user = await SessionService.getSavedUser();

    if (!mounted) return;

    if (userId == null || user == null) {
      DuruhaSnackBar.showError(context, "Please login to favorite items");
      return;
    }

    // Optimistic UI
    setState(() {
      _isFavorite = !_isFavorite;
    });

    try {
      await _repository.toggleFavorite(
        userId,
        user.role?.name.toUpperCase(),
        widget.produceId,
      );
      if (!mounted) return;
      DuruhaSnackBar.showSuccess(
        context,
        _isFavorite ? "Added to favorites" : "Removed from favorites",
      );
    } catch (e) {
      // Revert on error
      setState(() {
        _isFavorite = !_isFavorite;
      });
      if (!mounted) return;
      DuruhaSnackBar.showError(context, "Failed to update favorites");
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    if (_details == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Produce Details")),
        body: Center(child: Text(_errorMessage ?? "Produce not found")),
      );
    }

    final produce = _details!;

    final List<Widget> slivers = [];

    // Only use slivers.addAll for varieties as requested
    slivers.addAll(
      VarietiesSection.buildSlivers(
        context: context,
        produce: produce,
        varieties: _localVarieties,
        onEdit: (v) =>
            _varietiesSectionKey.currentState?.showEditDialog(context, v),
      ),
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 1. Unified App Bar (Search logic removed)
          DuruhaSliverAppBar(
            title: produce.getLocalName(_userDialect ?? ''),
            imageUrl: produce.imageHeroUrl,
            expandedHeight: 200,
            actions: [
              IconButton(
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite
                      ? Colors.red
                      : theme.colorScheme.onSecondary,
                ),
                onPressed: _toggleFavorite,
              ),
            ],
          ),

          // 2. Header and Logistics Sections
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeaderSection(produce: produce),
                  const SizedBox(height: 32),
                  _LogisticsSection(produce: produce),
                ],
              ),
            ),
          ),

          // 4. "View All" Button at the bottom of the list
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsetsGeometry.symmetric(horizontal: 16),
              child: DuruhaButton(
                text: "View All Varieties",
                icon: Icon(Icons.arrow_forward),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProduceVarietiesScreen(
                        title: produce.englishName,
                        produce: produce,
                        varieties: _localVarieties,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final Produce produce;
  const _HeaderSection({required this.produce});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          produce.englishName,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (produce.scientificName != null) ...[
          const SizedBox(height: 4),
          Text(
            produce.scientificName!,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (produce.dialects.isNotEmpty) ...[
          const SizedBox(height: 12),
          ProduceDialectWidget(
            produceId: produce.id,
            dialects: produce.dialects,
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            TagChip(tag: produce.category, icon: Icons.category_outlined),
            const SizedBox(width: 8),
            TagChip(tag: produce.baseUnit, icon: Icons.scale_outlined),
          ],
        ),
      ],
    );
  }
}

class _LogisticsSection extends StatelessWidget {
  final Produce produce;
  const _LogisticsSection({required this.produce});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 100, // Fixed height for Bento items to align
          child: _buildBentoRow([
            _FeatureTile(
              label: "Storage",
              value: produce.storageGroup ?? "",
              icon: Icons.warehouse_rounded,
              color: DuruhaColorHelper.getColor(
                context,
                produce.storageGroup ?? "",
              ),
            ),
            _FeatureTile(
              label: "Respiration",
              value: produce.respirationRate ?? "",
              icon: Icons.air_rounded,
              color: DuruhaColorHelper.getColor(
                context,
                produce.respirationRate ?? "",
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        _buildRiskPanel(),
        const SizedBox(height: 24),
        buildCrushMetric(produce.crushWeightTolerance ?? 0, context),
        const SizedBox(height: 32),
        _buildStatusFooter(context),
      ],
    );
  }

  Widget _buildStatusFooter(BuildContext context) {
    if (produce.updatedAt == null) return const SizedBox.shrink();
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            "Last updated: ${DuruhaFormatter.formatDate(produce.updatedAt!)}",
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  // A sleek row that uses Flexible to handle different content widths
  Widget _buildBentoRow(List<Widget> children) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children
          .map(
            (c) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: c,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildRiskPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _RiskRow(
            label: "Ethylene Production",
            isHigh: produce.isEthyleneProducer ?? false,
            icon: Icons.warning_amber_rounded,
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          _RiskRow(
            label: "Ethylene Sensitivity",
            isHigh: produce.isEthyleneSensitive ?? false,
            icon: Icons.sensors_rounded,
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _FeatureTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RiskRow extends StatelessWidget {
  final String label;
  final bool isHigh;
  final IconData icon;

  const _RiskRow({
    required this.label,
    required this.isHigh,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final color = isHigh
        ? DuruhaColorHelper.getColor(context, "High")
        : DuruhaColorHelper.getColor(context, "Low");

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Text(
            isHigh ? "Yes" : "No",
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

Widget buildCrushMetric(int val, BuildContext context) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "CRUSH TOLERANCE",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Colors.grey,
            ),
          ),
          Text(
            "$val",
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: DuruhaProgressBar(
          value: val / 5, // Assuming 100 is max sensible
          height: 8,
          backgroundColor: Colors.grey.withValues(alpha: 0.2),
          color: DuruhaColorHelper.getColor(context, val.toString()),
        ),
      ),
    ],
  );
}

class InfoRow extends StatelessWidget {
  final List<Widget> children;
  const InfoRow({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.map((child) => Expanded(child: child)).toList(),
    );
  }
}

class InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const InfoItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class TagChip extends StatelessWidget {
  final String tag;
  final IconData icon;
  const TagChip({super.key, required this.tag, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.onTertiaryContainer),
          const SizedBox(width: 4),
          Text(
            tag,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class TraitChip extends StatelessWidget {
  final String label;
  final Color color;
  const TraitChip({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }
}
