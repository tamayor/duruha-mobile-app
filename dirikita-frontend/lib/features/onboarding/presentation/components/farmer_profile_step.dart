import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:flutter/material.dart';

class FarmerProfileStep extends StatefulWidget {
  final TextEditingController aliasController;
  final TextEditingController landAreaController;
  final String initialAccessibility;
  final List<String> initialWaterSources;
  final Function(String) onAccessibilityChanged;
  final Function(List<String>) onWaterSourcesChanged;

  const FarmerProfileStep({
    super.key,
    required this.aliasController,
    required this.landAreaController,
    required this.initialAccessibility,
    required this.initialWaterSources,
    required this.onAccessibilityChanged,
    required this.onWaterSourcesChanged,
  });

  @override
  State<FarmerProfileStep> createState() => _FarmerProfileStepState();
}

class _FarmerProfileStepState extends State<FarmerProfileStep> {
  late String _accessibility;
  late List<String> _waterSources;

  final List<String> _waterSourceOptions = [
    "River / Stream",
    "Deep Well (Borehole)",
    "Rainwater Harvesting",
    "Irrigation Canal",
    "Public/Municipal Tap",
    "Water Tanker",
  ];

  @override
  void initState() {
    super.initState();
    _accessibility = widget.initialAccessibility;
    _waterSources = List.from(widget.initialWaterSources);
  }

  void _toggleWaterSource(String source) {
    setState(() {
      if (_waterSources.contains(source)) {
        _waterSources.remove(source);
      } else {
        _waterSources.add(source);
      }
      widget.onWaterSourcesChanged(_waterSources);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Farm Details Group
          DuruhaSectionContainer(
            title: "Farm Details",
            children: [
              // 1. Farm Alias
              DuruhaTextField(
                controller: widget.aliasController,
                label: 'Farm Alias / Name',
                icon: Icons.store_mall_directory_outlined,
              ),

              // 2. Land Area
              DuruhaTextField(
                controller: widget.landAreaController,
                label: 'Total Land Area',
                icon: Icons.landscape_outlined,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                suffix: 'sqm',
              ),

              // 3. Accessibility Dropdown
              DuruhaDropdown(
                label: 'Road Accessibility',
                value: _accessibility,
                items: const ['Truck', 'Tricycle', 'Walk_In'],
                // Add icons to make it exciting!
                itemIcons: const {
                  'Truck': Icons.local_shipping_outlined,
                  'Tricycle': Icons.electric_rickshaw_outlined,
                  'Walk_In': Icons.directions_walk_outlined,
                },
                onChanged: (v) {
                  if (v != null) {
                    setState(() => _accessibility = v);
                    widget.onAccessibilityChanged(v);
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 2. Water Source Group
          DuruhaSectionContainer(
            title: "Irrigation",
            children: [
              // 4. Water Source Chips
              DuruhaSelectionChipGroup(
                title: "Water Source",
                subtitle: "Select all that apply to your farm",
                isRequired: true,
                options: _waterSourceOptions, // Pass your list of strings
                selectedValues:
                    _waterSources, // Pass your list of selected strings
                onToggle: (val) =>
                    _toggleWaterSource(val), // Pass your function
              ),
            ],
          ),
          const SizedBox(height: 100), // Spacing for Bottom Bar
        ],
      ),
    );
  }
}
