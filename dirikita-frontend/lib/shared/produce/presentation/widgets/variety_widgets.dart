import 'package:duruha/core/helpers/duruha_color_helper.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/shared/produce/data/produce_repository.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:duruha/shared/produce/domain/produce_variety.dart';
import 'package:duruha/shared/produce/presentation/widgets/variety_form.dart';
import 'package:flutter/material.dart';

class VarietiesSection extends StatefulWidget {
  final Produce produce;
  final List<ProduceVariety> localVarieties;
  final Function(ProduceVariety) onEdit;
  final VoidCallback? onUpdate;

  const VarietiesSection({
    super.key,
    required this.produce,
    required this.localVarieties,
    required this.onEdit,
    this.onUpdate,
  });

  @override
  State<VarietiesSection> createState() => VarietiesSectionState();

  static List<Widget> buildSlivers({
    required BuildContext context,
    required Produce produce,
    required List<ProduceVariety> varieties,
    required Function(ProduceVariety) onEdit,
    bool? compactOverride,
    Widget Function(ProduceVariety)? adminTrailingBuilder,
    Widget Function(ProduceVariety)? adminContentBuilder,
  }) {
    if (varieties.isEmpty) {
      return [SliverToBoxAdapter(child: _EmptyVarietiesPlaceholder())];
    }

    return varieties.map((v) {
      return DuruhaSectionSliver(
        compactOverride: compactOverride,
        footerHeight: 24,
        headerPadding: const EdgeInsets.symmetric(horizontal: 20),
        leading: _VarietyThumbnail(imageUrl: v.imageUrl),
        title: _VarietyNameScrollable(name: v.name),
        subtitle: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _buildPriceBadge(v, Theme.of(context)),
            _buildTypeBadge(v.isNative, context),
          ],
        ),
        trailing:
            adminTrailingBuilder?.call(v) ??
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => onEdit(v),
              visualDensity: VisualDensity.compact,
              tooltip: 'Edit Variety',
              padding: EdgeInsets.zero,
            ),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        content: Column(
          children: [
            if (adminContentBuilder != null) ...[
              adminContentBuilder(v),
              const SizedBox(height: 16),
            ],
            _VarietyDetailsContent(variety: v),
          ],
        ),
      );
    }).toList();
  }
}

class VarietiesSectionState extends State<VarietiesSection> {
  final _repository = ProduceRepository();

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(VarietiesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  /// Called from the parent (e.g. app bar action) to open the Add dialog.
  void showAddDialog() => _showAddDialog(context);

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }

  Future<void> showEditDialog(
    BuildContext context,
    ProduceVariety variety,
  ) async {
    await DuruhaBottomSheet.show(
      context: context,
      title: 'Edit Variety',
      icon: Icons.edit,
      child: VarietyForm(
        produceName: widget.produce.englishName,
        produceId: widget.produce.id,
        initialData: {
          'id': variety.id,
          'variety_name': variety.name,
          'image_url': variety.imageUrl,
          'breeding_type': variety.breedingType,
          'days_to_maturity_min': variety.daysToMaturityMin,
          'days_to_maturity_max': variety.daysToMaturityMax,
          'peak_months': variety.peakMonths,
          'philippine_season': variety.philippineSeason,
          'flood_tolerance': variety.floodTolerance,
          'handling_fragility': variety.handlingFragility,
          'shelf_life_days': variety.shelfLifeDays,
          'optimal_storage_temp_c': variety.optimalStorageTempC,
          'packaging_requirement': variety.packagingRequirement,
          'appearance_desc': variety.appearanceDesc,
          'is_native': variety.isNative,
          // 'price': variety.price,
        },
        repository: _repository,
        onSave: (data) async {
          try {
            data['variety_id'] = variety.id;
            await _repository.addProduceVariety(data);
            if (!mounted) return;

            setState(() {
              final index = widget.localVarieties.indexWhere(
                (v) => v.id == variety.id,
              );
              if (index != -1) {
                widget.localVarieties[index] = ProduceVariety(
                  id: variety.id,
                  name: data['variety_name'] as String,
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
                  optimalStorageTempC: (data['optimal_storage_temp_c'] ?? 0.0)
                      .toDouble(),
                  packagingRequirement:
                      data['packaging_requirement'] as String?,
                  appearanceDesc: data['appearance_desc'] as String?,
                );
              }
            });
            widget.onUpdate?.call();

            if (!context.mounted) return;
            DuruhaSnackBar.showSuccess(
              context,
              "Updated variety: ${data['variety_name']}",
            );
          } catch (e) {
            if (!context.mounted) return;
            DuruhaSnackBar.showError(context, "Failed to update variety: $e");
            rethrow;
          }
        },
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    await DuruhaBottomSheet.show(
      context: context,
      title: 'Add New Variety',
      icon: Icons.eco,
      child: VarietyForm(
        produceName: widget.produce.englishName,
        produceId: widget.produce.id,
        repository: _repository,
        onSave: (data) async {
          try {
            await _repository.addProduceVariety(data);
            if (!mounted) return;

            setState(() {
              widget.localVarieties.add(
                ProduceVariety(
                  id:
                      data['variety_id'] as String? ??
                      'temp-${DateTime.now().millisecondsSinceEpoch}',
                  name: data['variety_name'] as String,
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
            widget.onUpdate?.call();

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
}

class _EmptyVarietiesPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.eco_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No varieties listed yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VarietyDetailsContent extends StatelessWidget {
  final ProduceVariety variety;
  const _VarietyDetailsContent({required this.variety});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vListings = variety.listings;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel(context, "Pricing", Icons.sell_outlined),
          _buildInfoGrid([
            _InfoTile(
              "Farmer → Trader",
              vListings.isNotEmpty
                  ? "₱${vListings.first.farmerToTraderPrice.toStringAsFixed(2)}"
                  : "-",
              Icons.storefront,
            ),
            _InfoTile(
              "Farmer → Duruha",
              vListings.isNotEmpty
                  ? "₱${vListings.first.farmerToDuruhaPrice.toStringAsFixed(2)}"
                  : "-",
              Icons.handshake_outlined,
            ),
            _InfoTile(
              "Duruha → Consumer",
              vListings.isNotEmpty
                  ? "₱${vListings.first.duruhaToConsumerPrice.toStringAsFixed(2)}"
                  : "-",
              Icons.shopping_bag_outlined,
            ),
            _InfoTile(
              "Public Market",
              vListings.isNotEmpty
                  ? "₱${vListings.first.marketToConsumerPrice.toStringAsFixed(2)}"
                  : "-",
              Icons.public,
            ),
          ]),
          const SizedBox(height: 20),
          VarietySpecsSection(variety: variety),
        ],
      ),
    );
  }
}

class VarietySpecsSection extends StatelessWidget {
  final ProduceVariety variety;
  final bool showAdminFields;

  const VarietySpecsSection({
    super.key,
    required this.variety,
    this.showAdminFields = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final nativeLabel = variety.isNative ? 'NATIVE' : 'HYBRID';
    final nativeColor = variety.isNative
        ? Colors.green.shade700
        : Colors.orange.shade700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: scheme.onPrimary),
                const SizedBox(width: 8),
                Text(
                  'Specifications',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onPrimary,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: nativeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: nativeColor.withValues(alpha: 0.5)),
              ),
              child: Text(
                nativeLabel,
                style: textTheme.labelSmall?.copyWith(
                  color: nativeColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            _buildSpecsItem(
              context,
              'Season',
              variety.philippineSeason ?? 'N/A',
              scheme,
              textTheme,
            ),
            _buildSpecsItem(
              context,
              'Shelf Life',
              '${variety.shelfLifeDays} Days',
              scheme,
              textTheme,
            ),
            _buildSpecsItem(
              context,
              'Optimal Temp',
              variety.optimalStorageTempC != null
                  ? '${variety.optimalStorageTempC}°C'
                  : 'N/A',
              scheme,
              textTheme,
            ),
            _buildSpecsItem(
              context,
              'Maturity',
              '${variety.daysToMaturityMin ?? "?"}-${variety.daysToMaturityMax ?? "?"} d',
              scheme,
              textTheme,
            ),
            _buildSpecsItem(
              context,
              'Breeding',
              variety.breedingType ?? 'N/A',
              scheme,
              textTheme,
            ),
            _buildSpecsItem(
              context,
              'Flood Tol.',
              variety.floodTolerance != null
                  ? '${variety.floodTolerance}/5'
                  : 'N/A',
              scheme,
              textTheme,
            ),
            _buildSpecsItem(
              context,
              'Fragility',
              variety.handlingFragility != null
                  ? '${variety.handlingFragility}/5'
                  : 'N/A',
              scheme,
              textTheme,
            ),
          ],
        ),

        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),

        // _buildSpecsItem(
        //   context,
        //   '30 Day Qty',
        //   '${variety.total30DaysQuantity.toStringAsFixed(1)} kg',
        //   scheme,
        //   textTheme,
        //   valueColor: scheme.onTertiary,
        // ),
        const SizedBox(height: 12),
        _buildInfoBlock(
          context,
          'Peak Months:',
          variety.peakMonths.isEmpty
              ? 'Not specified'
              : variety.peakMonths.join(', '),
          scheme,
          textTheme,
        ),
        if (variety.packagingRequirement != null &&
            variety.packagingRequirement!.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildInfoBlock(
            context,
            'Packaging:',
            variety.packagingRequirement!,
            scheme,
            textTheme,
          ),
        ],
        if (variety.appearanceDesc != null &&
            variety.appearanceDesc!.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildInfoBlock(
            context,
            'Appearance:',
            variety.appearanceDesc!,
            scheme,
            textTheme,
          ),
        ],
      ],
    );
  }

  Widget _buildSpecsItem(
    BuildContext context,
    String label,
    String value,
    ColorScheme scheme,
    TextTheme textTheme, {
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: textTheme.labelSmall?.copyWith(
            letterSpacing: 1.1,
            fontWeight: FontWeight.bold,
            fontSize: 9,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor ?? scheme.onPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBlock(
    BuildContext context,
    String label,
    String value,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(value, style: textTheme.bodySmall),
      ],
    );
  }
}

class VarietySpecsCard extends StatelessWidget {
  final ProduceVariety variety;
  final bool showAdminFields;

  const VarietySpecsCard({
    super.key,
    required this.variety,
    this.showAdminFields = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: VarietySpecsSection(
        variety: variety,
        showAdminFields: showAdminFields,
      ),
    );
  }
}

// ── REUSABLE MINI WIDGETS ──────────────────────────────────

class _VarietyThumbnail extends StatelessWidget {
  final String? imageUrl;
  const _VarietyThumbnail({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: scheme.tertiaryContainer,
        image: imageUrl != null
            ? DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
                onError: (_, _) {},
              )
            : null,
      ),
      child: imageUrl == null
          ? Icon(Icons.eco, size: 28, color: scheme.onTertiaryContainer)
          : null,
    );
  }
}

class _VarietyNameScrollable extends StatelessWidget {
  final String name;
  const _VarietyNameScrollable({required this.name});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        stops: [0.78, 1.0],
        colors: [Colors.black, Colors.transparent],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.only(right: 32),
          child: Text(
            name,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            maxLines: 1,
            softWrap: false,
          ),
        ),
      ),
    );
  }
}

Widget _buildPriceBadge(ProduceVariety variety, ThemeData theme) {
  final hasListings = variety.listings.isNotEmpty;
  final displayPrice = hasListings
      ? variety.listings.first.duruhaToConsumerPrice
      : variety.price;

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: theme.colorScheme.primary.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      DuruhaFormatter.formatCurrency(displayPrice),
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onPrimary.withValues(alpha: 0.9),
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

Widget _buildTypeBadge(bool isNative, BuildContext context) {
  final color = DuruhaColorHelper.getColor(
    context,
    isNative ? "native" : "hybrid",
  );
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      border: Border.all(color: color.withValues(alpha: 0.1)),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isNative ? Icons.local_florist : Icons.science,
          size: 12,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          isNative ? "NATIVE" : "HYBRID",
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

Widget _buildSectionLabel(BuildContext context, String label, IconData icon) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSecondary),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSecondary,
          ),
        ),
      ],
    ),
  );
}

Widget _buildInfoGrid(List<Widget> children) {
  if (children.isEmpty) return const SizedBox.shrink();
  final List<Widget> rows = [];
  for (int i = 0; i < children.length; i += 2) {
    final List<Widget> rowChildren = [];
    rowChildren.add(Expanded(child: children[i]));
    rowChildren.add(const SizedBox(width: 8));
    if (i + 1 < children.length) {
      rowChildren.add(Expanded(child: children[i + 1]));
    } else {
      rowChildren.add(const Expanded(child: SizedBox.shrink()));
    }
    rows.add(Row(children: rowChildren));
    if (i + 2 < children.length) rows.add(const SizedBox(height: 8));
  }
  return Column(children: rows);
}

class _InfoTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _InfoTile(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: scheme.onSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSecondary.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.black, Colors.transparent],
                      stops: [0.85, 1.0],
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
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onPrimary,
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
    );
  }
}
