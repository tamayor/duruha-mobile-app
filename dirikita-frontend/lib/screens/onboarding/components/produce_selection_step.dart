import 'package:duruha/data/produce_data.dart';
import 'package:duruha/helpers/duruha_responsive.dart';
import 'package:duruha/models/produce_model.dart';
import 'package:duruha/screens/onboarding/components/selected_produce_summary.dart';
import 'package:duruha/theme/duruha_styles.dart';
import 'package:duruha/widgets/duruha_widgets.dart';
import 'package:flutter/material.dart';

class ProduceSelectionStep extends StatefulWidget {
  final String userRole;
  final Map<String, Map<String, dynamic>> consumerDemands;
  final Map<String, List<String>> farmerPledges;
  final Function(String, bool) onItemToggled;
  final Function(String, String, bool) onFarmerPledgeChanged;

  const ProduceSelectionStep({
    super.key,
    required this.userRole,
    required this.consumerDemands,
    required this.farmerPledges,
    required this.onItemToggled,
    required this.onFarmerPledgeChanged,
  });

  @override
  State<ProduceSelectionStep> createState() => _ProduceSelectionStepState();
}

class _ProduceSelectionStepState extends State<ProduceSelectionStep> {
  String _produceSearchQuery = '';
  final _searchController = TextEditingController();
  ProduceCategory? _selectedCategory; // null represents "All"

  // Define category icons mapping
  static const Map<ProduceCategory, IconData> _categoryIcons = {
    ProduceCategory.leafy: Icons.eco,
    ProduceCategory.fruitVeg: Icons.bakery_dining,
    ProduceCategory.root: Icons.grass, // Using grass as proxy for root/earthy
    ProduceCategory.spice: Icons.flare,
    ProduceCategory.fruit: Icons.apple,
    ProduceCategory.legume: Icons.grain,
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSummary() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollController) => SelectedProduceSummary(
          userRole: widget.userRole,
          consumerDemands: widget.consumerDemands,
          farmerPledges: widget.farmerPledges,
          onRemoveItem: (id) {
            widget.onItemToggled(id, false);
            setState(() {});
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
              _showSummary();
            }
          },
          onRemoveVariety: (id, variety) {
            widget.onFarmerPledgeChanged(id, variety, false);
            Navigator.pop(context);
            _showSummary();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Filter Data
    bool useList = context.isMobile;
    final filteredProduce = mockProduceList.where((p) {
      // Category Filter
      if (_selectedCategory != null && p.category != _selectedCategory) {
        return false;
      }

      // Search Filter
      if (_produceSearchQuery.isNotEmpty) {
        final query = _produceSearchQuery.toLowerCase();
        return p.nameEnglish.toLowerCase().contains(query) ||
            p.nameScientific.toLowerCase().contains(query);
      }
      return true;
    }).toList();

    // Calculate selected count for the summary button
    final selectedCount = widget.userRole == 'Consumer'
        ? widget.consumerDemands.length
        : widget.farmerPledges.length;

    return Stack(
      children: [
        Column(
          children: [
            // Search and Filter Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  // Search Field
                  Expanded(
                    flex: 4,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _produceSearchQuery = v),
                      decoration: DuruhaStyles.fieldDecoration(
                        context,
                        label: "Search...",
                        icon: Icons.search,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Category Dropdown
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<ProduceCategory?>(
                      value: _selectedCategory,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, size: 18),
                      decoration: DuruhaStyles.inputDecoration(
                        context,
                        label: "Type",
                        icon: Icons.eco,
                      ),
                      items: [
                        // "All" Option
                        const DropdownMenuItem<ProduceCategory?>(
                          value: null,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.grid_view, size: 16),
                              SizedBox(width: 4),
                              Text("All", style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        // Enum Options
                        ..._categoryIcons.entries.map((entry) {
                          return DropdownMenuItem<ProduceCategory?>(
                            value: entry.key,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  entry.value,
                                  size: 16,
                                  color: Theme.of(context).primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  // Capitalize first letter of enum name logic or just name
                                  entry.key.name.substring(0, 1).toUpperCase() +
                                      entry.key.name.substring(1),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() => _selectedCategory = value);
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 2. Data Grid
            Expanded(
              child: DuruhaDataGrid(
                data: filteredProduce,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                maxCrossAxisExtent: 200,
                isList: useList,
                itemBuilder: (context, produce) {
                  final isSelected = widget.userRole == 'Consumer'
                      ? widget.consumerDemands.containsKey(produce.id)
                      : widget.farmerPledges.containsKey(produce.id);

                  return DuruhaSelectionCard(
                    isList: useList,
                    title: produce.nameEnglish,
                    subtitle: produce.nameScientific,
                    imageUrl: "assets/logo.png",
                    isSelected: isSelected,
                    onTap: () => widget.onItemToggled(produce.id, !isSelected),
                  );
                },
              ),
            ),
          ],
        ),

        // Floating Summary Button
        Positioned(
          bottom: 24,
          right: 24, // Positioned in the corner for one-handed thumb use
          child: AnimatedScale(
            // Using Scale instead of Opacity feels more modern for a FAB
            scale: selectedCount > 0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: FloatingActionButton(
              onPressed: selectedCount > 0 ? _showSummary : null,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 4,
              shape: const CircleBorder(), // Forces the circular shape
              child: Badge(
                label: Text(
                  '$selectedCount',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
                backgroundColor: Theme.of(context).colorScheme.outline,
                isLabelVisible: selectedCount > 0,
                child: const Icon(Icons.shopping_basket, size: 28),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
