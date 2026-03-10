import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:flutter/material.dart';
import 'package:duruha/core/constants/consumer_options.dart';

class ConsumerProfileStep extends StatefulWidget {
  final String initialSegment;
  final String initialCookingFreq;
  final Function(String) onSegmentChanged;
  final Function(String) onCookingFreqChanged;

  const ConsumerProfileStep({
    super.key,
    required this.initialSegment,
    required this.initialCookingFreq,
    required this.onSegmentChanged,
    required this.onCookingFreqChanged,
  });

  @override
  State<ConsumerProfileStep> createState() => _ConsumerProfileStepState();
}

class _ConsumerProfileStepState extends State<ConsumerProfileStep> {
  late String _segment;
  late String _cookingFrequency;

  @override
  void initState() {
    super.initState();
    _segment = widget.initialSegment;
    _cookingFrequency = widget.initialCookingFreq;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DuruhaDropdown<String>(
            value: _segment,
            label: 'Segment Type',
            prefixIcon: Icons.category,
            items: ConsumerOptions.segments,
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
          const SizedBox(height: 100), // Spacing for Bottom Bar
        ],
      ),
    );
  }
}
