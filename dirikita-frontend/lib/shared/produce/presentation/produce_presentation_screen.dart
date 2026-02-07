import 'package:flutter/material.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:duruha/shared/produce/data/produce_presentation_repository.dart';

class ProducePresentationScreen extends StatefulWidget {
  final String produceId;
  const ProducePresentationScreen({super.key, required this.produceId});

  @override
  State<ProducePresentationScreen> createState() =>
      _ProducePresentationScreenState();
}

class _ProducePresentationScreenState extends State<ProducePresentationScreen> {
  final _repository = ProducePresentationRepository();
  Produce? _details;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    try {
      final details = await _repository.getProduceDetails(widget.produceId);
      if (!mounted) return;
      setState(() {
        _details = details;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    if (_details == null) {
      return Scaffold(
        body: Center(child: Text(_errorMessage ?? "Produce not found")),
      );
    }

    final produce = _details!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          DuruhaSliverAppBar(
            title: produce.nameEnglish,
            imageUrl: produce.imageHeroUrl,
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _HeaderSection(produce: produce),
                const SizedBox(height: 32),
                _PricingSection(produce: produce),
                const SizedBox(height: 32),
                _VarietiesSection(produce: produce),
                const SizedBox(height: 32),
                _GradingSection(produce: produce),
                const SizedBox(height: 32),
                _MetricsGrid(produce: produce),
                const SizedBox(height: 48),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// --- SUB-WIDGETS (Private to this file for cleanliness) ---

class _HeaderSection extends StatelessWidget {
  final Produce produce;
  const _HeaderSection({required this.produce});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                produce.nameScientific,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (produce.namesByDialect.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  produce.namesByDialect.values.toSet().join(
                    ' • ',
                  ), // Unique names separated by dots
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: produce.tags
                    .map((tag) => _TagChip(tag: tag))
                    .toList(),
              ),
            ],
          ),
        ),
        _EcoAvatar(),
      ],
    );
  }
}

class _PricingSection extends StatelessWidget {
  final Produce produce;
  const _PricingSection({required this.produce});

  @override
  Widget build(BuildContext context) {
    final econ = produce.pricingEconomics;
    final theme = Theme.of(context);

    return DuruhaSectionContainer(
      title: "Pricing Transparency",
      subtitle: "Per ${produce.unitOfMeasure} | ${econ.priceTrendSignal} Trend",
      children: [
        _PriceRow(
          label: "Restaurant Pays",
          price: econ.duruhaConsumerPrice,
          color: theme.colorScheme.onPrimary,
          isHero: true,
        ),
        const SizedBox(height: 12),
        _PriceRow(
          label: "Farmer Receives (70% Share)",
          price: econ.duruhaFarmerPayout,
          color: theme.colorScheme.onSecondary,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Divider(),
        ),
        _PriceRow(
          label: "Market Benchmark (Retail)",
          price: econ.marketBenchmarkRetail,
          color: theme.colorScheme.error,
          subtitle: "Standard Supermarket Price",
        ),
        const SizedBox(height: 12),
        _PriceRow(
          label: "Middleman Offer (Farmgate)",
          price: econ.marketBenchmarkFarmgate,
          color: Colors.grey,
          subtitle: "Traditional Middleman Price",
        ),
        const SizedBox(height: 20),
        _InfoNote(
          text:
              "Duruha ensures farmers get a fair share, nearly 2x traditional middleman offers.",
        ),
      ],
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final Produce produce;
  const _MetricsGrid({required this.produce});

  @override
  Widget build(BuildContext context) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      children: [
        _MetricTile(
          label: "Growing Cycle",
          value: "${produce.growingCycleDays} Days",
          icon: Icons.timer_outlined,
        ),
        _MetricTile(
          label: "Yield",
          value: "${produce.yieldPerSqm} kg/m²",
          icon: Icons.grass_rounded,
        ),
        _MetricTile(
          label: "Shelf Life",
          value: "${produce.shelfLifeDays} Days",
          icon: Icons.calendar_today_outlined,
        ),
        _MetricTile(
          label: "Perishability",
          value: "${produce.perishabilityIndex}/5",
          icon: Icons.warning_amber_rounded,
        ),
      ],
    );
  }
}

// --- HELPER ATOMS ---

class _PriceRow extends StatelessWidget {
  final String label;
  final double price;
  final Color color;
  final bool isHero;
  final String? subtitle;

  const _PriceRow({
    required this.label,
    required this.price,
    required this.color,
    this.isHero = false,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isHero ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
        Text(
          DuruhaFormatter.formatCurrency(price),
          style:
              (isHero ? theme.textTheme.titleMedium : theme.textTheme.bodyLarge)
                  ?.copyWith(fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(label, style: theme.textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String tag;
  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text("#$tag", style: theme.textTheme.labelSmall),
    );
  }
}

class _EcoAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CircleAvatar(
      backgroundColor: theme.colorScheme.primaryContainer,
      child: Icon(
        Icons.eco_rounded,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  final String text;
  const _InfoNote({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

// Note: Varieties and Grading sections follow a similar pattern of extraction.
class _VarietiesSection extends StatelessWidget {
  final Produce produce;
  const _VarietiesSection({required this.produce});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DuruhaSectionContainer(
      title: "Varieties & Sourcing",
      children: produce.availableVarieties.map((v) {
        final basePrice = produce.pricingEconomics.duruhaConsumerPrice;
        final totalVarPrice = basePrice + v.priceModifier;

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              _SourcingIcon(isLocal: v.isLocallyGrown),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Sourced: ${v.sourcingProvinces.join(', ')}",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _PriceDelta(totalPrice: totalVarPrice, modifier: v.priceModifier),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SourcingIcon extends StatelessWidget {
  final bool isLocal;
  const _SourcingIcon({required this.isLocal});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color:
            (isLocal ? theme.colorScheme.primary : theme.colorScheme.tertiary)
                .withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isLocal ? Icons.location_on_rounded : Icons.airplanemode_active_rounded,
        size: 18,
        color: isLocal ? theme.colorScheme.primary : theme.colorScheme.tertiary,
      ),
    );
  }
}

class _PriceDelta extends StatelessWidget {
  final double totalPrice;
  final double modifier;

  const _PriceDelta({required this.totalPrice, required this.modifier});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = modifier > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          DuruhaFormatter.formatCurrency(totalPrice),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        if (modifier != 0)
          Text(
            "${isPositive ? '+' : ''}${DuruhaFormatter.formatCurrency(modifier)}",
            style: theme.textTheme.labelSmall?.copyWith(
              color: isPositive
                  ? theme.colorScheme.secondary
                  : theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

class _GradingSection extends StatelessWidget {
  final Produce produce;
  const _GradingSection({required this.produce});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DuruhaSectionContainer(
      title: "Quality Grading",
      action: TextButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.picture_as_pdf, size: 16),
        label: const Text("Guide"),
      ),
      children: produce.gradingStandards.entries.map((entry) {
        final multiplier = produce.gradeMultiplier[entry.key] ?? 1.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    entry.key,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "(${(multiplier * 100).toInt()}% Price)",
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                entry.value,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
