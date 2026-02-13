import 'package:duruha/core/helpers/duruha_color_helper.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/shared/produce/data/produce_repository.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:duruha/shared/produce/domain/produce_variety.dart';
import 'package:duruha/shared/produce/presentation/widgets/add_variety_form.dart';
import 'package:flutter/material.dart';

class VarietiesSection extends StatefulWidget {
  final Produce produce;
  const VarietiesSection({super.key, required this.produce});

  @override
  State<VarietiesSection> createState() => _VarietiesSectionState();
}

class _VarietiesSectionState extends State<VarietiesSection> {
  final _repository = ProduceRepository();
  late List<ProduceVariety> _localVarieties;

  @override
  void initState() {
    super.initState();
    _localVarieties = List.from(widget.produce.varieties);
  }

  @override
  void didUpdateWidget(VarietiesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.produce.varieties != oldWidget.produce.varieties) {
      _localVarieties = List.from(widget.produce.varieties);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return DuruhaSectionContainer(
      title: "Available Varieties",
      action: TextButton.icon(
        onPressed: () {
          _showAddDialog(context);
        },
        icon: Icon(Icons.add, size: 18, color: colorScheme.onSecondary),
        label: Text("Add", style: TextStyle(color: colorScheme.onSecondary)),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
      ),
      children: [
        if (_localVarieties.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                "No varieties listed yet.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ..._localVarieties.map((v) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
                width: 0.8,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: ExpansionTile(
                backgroundColor: theme.colorScheme.surface,
                collapsedBackgroundColor: theme.colorScheme.surfaceContainerLow,
                shape: const RoundedRectangleBorder(side: BorderSide.none),
                collapsedShape: const RoundedRectangleBorder(
                  side: BorderSide.none,
                ),
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),

                // --- LEADING: Profile Image ---
                leading: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: v.imageUrl != null
                        ? Image.network(v.imageUrl!, fit: BoxFit.cover)
                        : Container(
                            color: theme.colorScheme.primaryContainer,
                            child: Icon(
                              Icons.eco,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                  ),
                ),

                // --- TITLE: Name & Price ---
                title: Text(
                  v.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildPriceBadge(v.calculatedPrice, theme),
                      _buildMultiplierBadge(v.multiplier, theme),
                      _buildTypeBadge(v.isNative, context),
                    ],
                  ),
                ),

                // --- EXPANDED CONTENT ---
                children: [
                  const Divider(height: 32),

                  // SECTION: Growth Info
                  _buildSectionLabel(
                    context,
                    "Growth Specs",
                    Icons.agriculture,
                  ),
                  _buildInfoGrid([
                    _InfoTile(
                      "Breeding",
                      v.breedingType ?? "N/A",
                      Icons.biotech,
                    ),
                    _InfoTile(
                      "Maturity",
                      "${v.daysToMaturityMin ?? '-'}-${v.daysToMaturityMax ?? '-'} days",
                      Icons.history_toggle_off,
                    ),
                    _InfoTile(
                      "Season",
                      v.philippineSeason ?? "All-Year",
                      Icons.wb_sunny_outlined,
                    ),
                    _InfoTile(
                      "Peak Months",
                      v.peakMonths.isEmpty ? "N/A" : v.peakMonths.join(" - "),
                      Icons.event_available,
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // SECTION: Logistics
                  _buildSectionLabel(
                    context,
                    "Logistics & Storage",
                    Icons.inventory_2_outlined,
                  ),
                  _buildInfoGrid([
                    _InfoTile(
                      "Shelf Life",
                      "${v.shelfLifeDays} Days",
                      Icons.hourglass_top,
                    ),
                    _InfoTile(
                      "Storage",
                      v.optimalStorageTempC != null
                          ? "${v.optimalStorageTempC}°C"
                          : "Ambient",
                      Icons.ac_unit,
                    ),
                  ]),

                  const SizedBox(height: 20),

                  // SECTION: Resilience (Visuals)
                  _buildSectionLabel(
                    context,
                    "Field Resilience",
                    Icons.security,
                  ),
                  const SizedBox(height: 8),
                  _buildRatingRow(
                    "Flood Tolerance",
                    v.floodTolerance ?? 0,
                    DuruhaColorHelper.getColor(
                      context,
                      v.floodTolerance?.toString() ?? "0",
                    ),
                    theme,
                  ),
                  const SizedBox(height: 12),
                  _buildRatingRow(
                    "Handling Fragility",
                    v.handlingFragility ?? 0,
                    DuruhaColorHelper.getColor(
                      context,
                      v.handlingFragility?.toString() ?? "0",
                    ),
                    theme,
                  ),

                  // SECTION: Descriptions
                  if (v.appearanceDesc != null) ...[
                    const SizedBox(height: 20),
                    _buildTextCard(
                      "Visual Appearance",
                      v.appearanceDesc!,
                      theme,
                    ),
                  ],
                  // SECTION: Descriptions
                  if (v.packagingRequirement != null) ...[
                    const SizedBox(height: 20),
                    _buildTextCard(
                      "Packaging Requirement",
                      v.packagingRequirement!,
                      theme,
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    await DuruhaModalBottomSheet.show(
      context: context,
      title: 'Add New Variety',
      icon: Icons.eco,
      child: AddVarietyForm(
        produceId: widget.produce.id,
        repository: _repository,
        onSave: (data) async {
          try {
            await _repository.addProduceVariety(data);
            if (!mounted) return;

            setState(() {
              // Add locally for immediate feedback
              _localVarieties.add(
                ProduceVariety(
                  id: data['variety_id'] as String,
                  name: data['variety_name'] as String,
                  basePriceAtMapping: widget.produce.basePrice,
                  multiplier: data['variety_multiplier'] as double? ?? 1.0,
                  isNative: data['is_native'] as bool? ?? false,
                  imageUrl: data['image_url'] as String?,
                  breedingType: data['breeding_type'] as String?,
                  daysToMaturityMin: data['days_to_maturity_min'] as int?,
                  daysToMaturityMax: data['days_to_maturity_max'] as int?,
                  peakMonths:
                      (data['peak_months'] as List?)?.cast<String>() ?? [],
                  philippineSeason: data['philippine_season'] as String?,
                  floodTolerance: data['flood_tolerance'] as int?,
                  handlingFragility: data['handling_fragility'] as int?,
                  shelfLifeDays: data['shelf_life_days'] as int? ?? 7,
                  optimalStorageTempC:
                      data['optimal_storage_temp_c'] as double?,
                  packagingRequirement:
                      data['packaging_requirement'] as String?,
                  appearanceDesc: data['appearance_desc'] as String?,
                ),
              );
            });

            if (!context.mounted) return;

            DuruhaSnackBar.showSuccess(
              context,
              "Added variety: ${data['variety_name']}",
            );
          } catch (e) {
            if (!context.mounted) return;
            DuruhaSnackBar.showError(context, "Failed to add variety: $e");
            rethrow;
          }
        },
      ),
    );
  }

  // --- COMPONENT HELPERS ---

  Widget _buildPriceBadge(double price, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        DuruhaFormatter.formatCurrency(price),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMultiplierBadge(double multiplier, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        "x ${multiplier.toStringAsFixed(2)}",
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onPrimary.withValues(alpha: 0.5),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTypeBadge(bool isNative, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(
          color: DuruhaColorHelper.getColor(
            context,
            isNative ? "native" : "hybrid",
          ),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isNative ? Icons.local_florist : Icons.science,
            size: 12,
            color: DuruhaColorHelper.getColor(
              context,
              isNative ? "native" : "hybrid",
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isNative ? "NATIVE" : "HYBRID",
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: DuruhaColorHelper.getColor(
                context,
                isNative ? "native" : "hybrid",
              ),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoGrid(List<Widget> children) {
    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 48,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      children: children,
    );
  }

  Widget _buildRatingRow(
    String label,
    int value,
    Color color,
    ThemeData theme,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: theme.textTheme.bodySmall),
            Text(
              "$value/5",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        DuruhaProgressBar(
          value: value / 5.0,
          height: 6,
          color: color,
          backgroundColor: color.withValues(alpha: 0.1),
        ),
      ],
    );
  }

  Widget _buildTextCard(String title, String content, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(content, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _InfoTile(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      // ShaderMask creates the "Fade Out" effect
                      ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: const [Colors.black, Colors.transparent],
                            stops: const [
                              0.85,
                              1.0,
                            ], // Fades out the last 15% of the width
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.dstIn,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 24.0),
                            child: Text(
                              value,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                        ),
                      ),
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
}
