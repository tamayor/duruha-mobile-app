import 'package:flutter/material.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'admin_produce_form_models.dart';

class AdminProduceLevelWidget extends StatefulWidget {
  final FormProduce produce;

  const AdminProduceLevelWidget({super.key, required this.produce});

  @override
  State<AdminProduceLevelWidget> createState() =>
      _AdminProduceLevelWidgetState();
}

class _AdminProduceLevelWidgetState extends State<AdminProduceLevelWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final produce = widget.produce;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Level 1: Produce Item",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSecondary,
              ),
            ),
            const Divider(),
            const SizedBox(height: 12),
            DuruhaTextField(
              controller: produce.englishName,
              label: "English Name",
              icon: Icons.eco,
            ),
            DuruhaTextField(
              controller: produce.scientificName,
              label: "Scientific Name",
              icon: Icons.science,
              isRequired: false,
            ),
            Row(
              children: [
                Expanded(
                  child: DuruhaTextField(
                    controller: produce.baseUnit,
                    label: "Base Unit",
                    icon: Icons.unfold_more,
                    helperText: "e.g. kg, box, g",
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DuruhaTextField(
                    controller: produce.imageUrl,
                    label: "Image URL",
                    icon: Icons.image,
                    isRequired: false,
                  ),
                ),
              ],
            ),
            DuruhaDropdown<String>(
              value: produce.category,
              label: "Category",
              prefixIcon: Icons.category,
              items: {
                produce.category,
                "Vegetable",
                "Fruit",
                "Fruit Vegetable",
                "Herb",
                "Root",
                "Legume",
                "Gourd",
              }.toList(),
              onChanged: (val) =>
                  setState(() => produce.category = val ?? 'Vegetable'),
            ),
            const SizedBox(height: 16),
            Text(
              "Logistics & Storage",
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.onSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DuruhaDropdown<String>(
                    value: produce.storageGroup,
                    label: "Storage",
                    prefixIcon: Icons.ac_unit,
                    items: {
                      produce.storageGroup,
                      "Ambient",
                      "Cool/Moist",
                      "Cold/Dry",
                    }.toList(),
                    onChanged: (val) =>
                        setState(() => produce.storageGroup = val ?? 'Ambient'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DuruhaDropdown<String>(
                    value: produce.respirationRate,
                    label: "Respiration",
                    prefixIcon: Icons.air,
                    items: {
                      produce.respirationRate,
                      "Low",
                      "Medium",
                      "High",
                    }.toList(),
                    onChanged: (val) =>
                        setState(() => produce.respirationRate = val ?? 'Low'),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: const Text(
                      "Ethylene Producer",
                      style: TextStyle(fontSize: 12),
                    ),
                    value: produce.isEthyleneProducer,
                    onChanged: (val) => setState(
                      () => produce.isEthyleneProducer = val ?? false,
                    ),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: const Text(
                      "Ethylene Sensitive",
                      style: TextStyle(fontSize: 12),
                    ),
                    value: produce.isEthyleneSensitive,
                    onChanged: (val) => setState(
                      () => produce.isEthyleneSensitive = val ?? false,
                    ),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: DuruhaTextField(
                    controller: produce.crushWeightTolerance,
                    label: "Crush Tolerance (1-5)",
                    icon: Icons.scale,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DuruhaTextField(
                    controller: produce.crossContaminationRisk,
                    label: "Contam. Risk (1-5)",
                    icon: Icons.warning_amber,
                    keyboardType: TextInputType.number,
                    isRequired: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
