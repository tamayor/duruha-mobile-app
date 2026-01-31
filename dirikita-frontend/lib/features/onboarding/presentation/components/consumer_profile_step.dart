import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:flutter/material.dart';
import 'package:duruha/core/theme/duruha_styles.dart';

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

  void _toggleQuality(String value) {
    setState(() {
      if (_qualityPreferences.contains(value)) {
        _qualityPreferences.remove(value);
      } else {
        _qualityPreferences.add(value);
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
            items: [
              'Household',
              'Restaurant',
              'Carinderia',
            ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
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
            items: const ['Daily', 'Weekly', 'Monthly'],
            itemIcons: const {
              'Daily': Icons.soup_kitchen,
              'Weekly': Icons.calendar_view_week,
              'Monthly': Icons.calendar_month,
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
            subtitle: "Select all that apply to your preference",
            options: [
              'Class A (Premium)',
              'Class B (Standard)',
              'Class C (Imperfect)',
            ],
            selectedValues: _qualityPreferences,
            onToggle: (val) => _toggleQuality(val),
          ),
          const SizedBox(height: 100), // Spacing for Bottom Bar
        ],
      ),
    );
  }
}
