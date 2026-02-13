import 'package:duruha/shared/produce/data/produce_repository.dart';
import 'package:duruha/shared/produce/domain/produce_basic_info.dart';
import 'package:duruha/features/onboarding/presentation/components/selected_produce_summary.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:flutter/material.dart';

class ProduceSelectionStep extends StatefulWidget {
  final String userRole;
  final Map<String, Map<String, dynamic>> consumerDemands;
  final Map<String, List<String>> farmerPledges;
  final String searchQuery;
  final Function(String, bool) onItemToggled;
  final Function(String, String, bool) onFarmerPledgeChanged;
  final List<String> dialects;

  const ProduceSelectionStep({
    super.key,
    required this.userRole,
    required this.consumerDemands,
    required this.farmerPledges,
    required this.searchQuery,
    required this.onItemToggled,
    required this.onFarmerPledgeChanged,
    required this.dialects,
  });

  @override
  State<ProduceSelectionStep> createState() => _ProduceSelectionStepState();
}

class _ProduceSelectionStepState extends State<ProduceSelectionStep> {
  List<ProduceBasicInfo> _produceList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProduce(widget.dialects[0]);
  }

  Future<void> _fetchProduce(String dialect) async {
    try {
      final produce = await ProduceRepository().fetchProduceBasicInfo([
        dialect,
      ]);
      if (mounted) {
        setState(() {
          _produceList = produce;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching produce: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
          availableProduce: _produceList, // Pass the list here
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
    final filteredProduce = _produceList.where((p) {
      // Search Filter
      if (widget.searchQuery.isNotEmpty) {
        final query = widget.searchQuery.toLowerCase();
        return p.englishName.toLowerCase().contains(query) ||
            (p.scientificName).toLowerCase().contains(query) ||
            (p.localName).toLowerCase().contains(query);
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
            // 2. Data Grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Column(
                        children: filteredProduce.map((produce) {
                          final isSelected = widget.userRole == 'Consumer'
                              ? widget.consumerDemands.containsKey(produce.id)
                              : widget.farmerPledges.containsKey(produce.id);

                          return Padding(
                            padding: const EdgeInsets.only(
                              left: 16,
                              right: 16,
                              bottom: 12,
                            ),
                            child: DuruhaSelectionCard(
                              isList: true, // Always list in Column view
                              title: produce.localName,
                              subtitle: produce.englishName,
                              imageUrl: produce.imageUrl,
                              isSelected: isSelected,
                              onTap: () =>
                                  widget.onItemToggled(produce.id, !isSelected),
                            ),
                          );
                        }).toList(),
                      ),
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
