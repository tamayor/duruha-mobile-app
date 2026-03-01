import 'package:flutter/material.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'admin_produce_form_models.dart';
import 'admin_listing_level_widget.dart';

class AdminVarietyLevelWidget extends StatefulWidget {
  final FormProduce produce;

  const AdminVarietyLevelWidget({super.key, required this.produce});

  @override
  State<AdminVarietyLevelWidget> createState() =>
      _AdminVarietyLevelWidgetState();
}

class _AdminVarietyLevelWidgetState extends State<AdminVarietyLevelWidget> {
  void _addVariety() {
    setState(() {
      widget.produce.varieties.add(FormVariety());
    });
  }

  void _removeVariety(int index) {
    setState(() {
      widget.produce.varieties[index].dispose();
      widget.produce.varieties.removeAt(index);
    });
  }

  void _addListing(FormVariety variety) {
    setState(() {
      variety.listings.add(FormListing());
    });
  }

  void _removeListing(FormVariety variety, int index) {
    setState(() {
      variety.listings[index].dispose();
      variety.listings.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Level 2: Crop Varieties",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSecondary,
              ),
            ),
            TextButton.icon(
              onPressed: _addVariety,
              icon: Icon(Icons.add, color: scheme.onPrimary),
              label: Text(
                "Add Variety",
                style: TextStyle(color: theme.colorScheme.onPrimary),
              ),
            ),
          ],
        ),
        if (widget.produce.varieties.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "No varieties added yet. Add at least one.",
              textAlign: TextAlign.center,
            ),
          ),
        for (int i = 0; i < widget.produce.varieties.length; i++)
          _buildVarietyCard(widget.produce.varieties[i], i, theme, scheme),
      ],
    );
  }

  Widget _buildVarietyCard(
    FormVariety variety,
    int index,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left-side indicator
            Container(
              width: 6,
              color: index % 3 == 0
                  ? scheme.primary
                  : (index % 3 == 1 ? scheme.secondary : scheme.tertiary),
            ),
            Expanded(
              child: ExpansionTile(
                title: Text(
                  variety.name.text.isEmpty ? "New Variety" : variety.name.text,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: index % 3 == 0
                        ? scheme.onPrimaryContainer
                        : (index % 3 == 1
                              ? scheme.onSecondaryContainer
                              : scheme.onTertiaryContainer),
                  ),
                ),
                subtitle: Text(
                  "Agronomic Data & Listings",
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                initiallyExpanded: false, // Auto Compact Mode
                shape: const Border(), // Remove default borders
                collapsedShape: const Border(),
                childrenPadding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DuruhaTextField(
                          controller: variety.name,
                          label: "Variety Name",
                          icon: Icons.label,

                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _removeVariety(index),
                        icon: Icon(Icons.delete_outline, color: scheme.error),
                      ),
                    ],
                  ),
                  DuruhaDropdown<String>(
                    value: variety.breedingType,
                    label: "Breeding Type",
                    prefixIcon: Icons.biotech,

                    items: {
                      variety.breedingType,
                      'Inbred',
                      'Hybrid (F1)',
                      'OPV',
                      'Native/Landrace',
                      'Heirloom',
                    }.toList(),
                    onChanged: (val) =>
                        setState(() => variety.breedingType = val ?? 'OPV'),
                  ),
                  CheckboxListTile(
                    title: Text(
                      "Is Native",
                      style: TextStyle(
                        color: scheme.onTertiary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    value: variety.isNative,
                    activeColor: scheme.onTertiary,
                    onChanged: (val) =>
                        setState(() => variety.isNative = val ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: DuruhaTextField(
                          controller: variety.daysMin,
                          label: "Days Min",
                          icon: Icons.timer_outlined,

                          keyboardType: TextInputType.number,
                          isRequired: false,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DuruhaTextField(
                          controller: variety.daysMax,
                          label: "Days Max",
                          icon: Icons.timer,

                          keyboardType: TextInputType.number,
                          isRequired: false,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: DuruhaTextField(
                          controller: variety.floodTolerance,
                          label: "Flood Tol. (1-5)",
                          icon: Icons.water_drop_outlined,

                          keyboardType: TextInputType.number,
                          isRequired: false,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DuruhaTextField(
                          controller: variety.handlingFragility,
                          label: "Fragility (1-5)",
                          icon: Icons.pan_tool_outlined,

                          keyboardType: TextInputType.number,
                          isRequired: false,
                        ),
                      ),
                    ],
                  ),
                  DuruhaTextField(
                    controller: variety.packagingReq,
                    label: "Packaging Requirement",
                    icon: Icons.inventory_2_outlined,

                    isRequired: false,
                  ),
                  DuruhaTextField(
                    controller: variety.appearanceDesc,
                    label: "Appearance Description",
                    icon: Icons.auto_awesome_mosaic_outlined,

                    maxLines: 2,
                    isRequired: false,
                  ),
                  DuruhaTextField(
                    controller: variety.imageUrl,
                    label: "Variety Image URL",
                    icon: Icons.image_outlined,

                    isRequired: false,
                  ),
                  const SizedBox(height: 16),
                  _buildListingsLevel(variety, theme, scheme),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListingsLevel(
    FormVariety variety,
    ThemeData theme,
    ColorScheme scheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Level 3: Market Listings",
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.onSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: () => _addListing(variety),
              icon: Icon(
                Icons.add_shopping_cart,
                size: 16,
                color: scheme.onSecondary,
              ),
              label: Text(
                "Add Listing",
                style: TextStyle(color: scheme.onPrimary),
              ),
            ),
          ],
        ),
        if (variety.listings.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "No listings. Please add pricing tiers.",
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ),
        for (int i = 0; i < variety.listings.length; i++)
          AdminListingLevelWidget(
            variety: variety,
            listing: variety.listings[i],
            index: i,
            onRemove: () => _removeListing(variety, i),
          ),
      ],
    );
  }
}
