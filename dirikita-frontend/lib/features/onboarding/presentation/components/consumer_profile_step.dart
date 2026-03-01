import 'package:duruha/core/constants/quality_preferences.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:flutter/material.dart';
import 'package:duruha/core/theme/duruha_styles.dart';
import 'package:duruha/core/constants/consumer_options.dart';

class ConsumerProfileStep extends StatefulWidget {
  final String initialSegment;
  final String initialCookingFreq;
  final List<String> initialQualityPrefs;
  final Function(String) onSegmentChanged;
  final Function(String) onCookingFreqChanged;
  final Function(List<String>) onQualityChanged;

  const ConsumerProfileStep({
    super.key,
    required this.initialSegment,
    required this.initialCookingFreq,
    required this.initialQualityPrefs,
    required this.onSegmentChanged,
    required this.onCookingFreqChanged,
    required this.onQualityChanged,
  });

  @override
  State<ConsumerProfileStep> createState() => _ConsumerProfileStepState();
}

class _ConsumerProfileStepState extends State<ConsumerProfileStep> {
  late String _segment;
  late String _cookingFrequency;
  late List<String> _qualityPreferences;

  @override
  void initState() {
    super.initState();
    _segment = widget.initialSegment;
    _cookingFrequency = widget.initialCookingFreq;
    _qualityPreferences = List.from(widget.initialQualityPrefs);
  }

  // Valid combos (in order): ['Select'] → ['Select','Regular'] → ['Select','Regular','Saver']
  // Selecting a tier includes all tiers before it.
  // Deselecting a tier removes it and all tiers after it.
  void _toggleQuality(String value) {
    const tiers =
        QualityPreferences.qualityPreferences; // ['Select','Regular','Saver']
    final tierIndex = tiers.indexOf(value);
    if (tierIndex == -1) return;

    setState(() {
      final isCurrentlySelected = _qualityPreferences.contains(value);

      if (isCurrentlySelected) {
        // Deselect this tier AND all tiers after it
        _qualityPreferences = tiers.sublist(0, tierIndex).toList();
      } else {
        // Select this tier AND all tiers before it
        _qualityPreferences = tiers.sublist(0, tierIndex + 1).toList();
      }

      widget.onQualityChanged(_qualityPreferences);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _segment,
            decoration: DuruhaStyles.fieldDecoration(
              context,
              label: 'Segment Type',
              icon: Icons.category,
            ),
            items: ConsumerOptions.segments
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) {
              if (v != null) {
                setState(() => _segment = v);
                widget.onSegmentChanged(v);
              }
            },
          ),
          const SizedBox(height: 24),
          DuruhaDropdown(
            label: 'Cooking Frequency',
            value: _cookingFrequency,
            prefixIcon: Icons.restaurant_menu,
            items: ConsumerOptions.cookingFrequency,
            itemIcons: const {
              'Daily': Icons.soup_kitchen,
              'Weekly': Icons.calendar_view_week,
              'Monthly': Icons.calendar_month,
              'Occasional': Icons.calendar_today,
              'Few times a week': Icons.calendar_today,
            },
            onChanged: (v) {
              if (v != null) {
                setState(() => _cookingFrequency = v);
                widget.onCookingFreqChanged(v);
              }
            },
          ),
          const SizedBox(height: 24),
          DuruhaSelectionChipGroup(
            title: "Quality Preference",
            subtitle: "Select your tier — each includes the one before it",
            options: QualityPreferences.qualityPreferences,
            selectedValues: _qualityPreferences,
            onToggle: _toggleQuality,
          ),
          const SizedBox(height: 100), // Spacing for Bottom Bar
        ],
      ),
    );
  }
}
