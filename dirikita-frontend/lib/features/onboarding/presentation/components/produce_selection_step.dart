import 'package:duruha/core/helpers/duruha_responsive.dart';
import 'package:duruha/shared/produce/data/produce_repository.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:duruha/features/onboarding/presentation/components/selected_produce_summary.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:flutter/material.dart';

class ProduceSelectionStep extends StatefulWidget {
  final String userRole;
  final Map<String, Map<String, dynamic>> consumerDemands;
  final Map<String, List<String>> farmerPledges;
  final String searchQuery;
  final ProduceCategory? selectedCategory;
  final Function(String, bool) onItemToggled;
  final Function(String, String, bool) onFarmerPledgeChanged;

  const ProduceSelectionStep({
    super.key,
    required this.userRole,
    required this.consumerDemands,
    required this.farmerPledges,
    required this.searchQuery,
    required this.selectedCategory,
    required this.onItemToggled,
    required this.onFarmerPledgeChanged,
  });

  @override
  State<ProduceSelectionStep> createState() => _ProduceSelectionStepState();
}

class _ProduceSelectionStepState extends State<ProduceSelectionStep> {
  List<Produce> _produceList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProduce();
  }

  Future<void> _fetchProduce() async {
    try {
      final produce = await ProduceRepository().getAllProduce();
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
    // 1. Filter Data
    bool useList = context.isMobile;
    final filteredProduce = _produceList.where((p) {
      // Category Filter
      if (widget.selectedCategory != null &&
          p.category != widget.selectedCategory) {
        return false;
      }

      // Search Filter
      if (widget.searchQuery.isNotEmpty) {
        final query = widget.searchQuery.toLowerCase();
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
            // 2. Data Grid
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : DuruhaDataGrid(
                      data: filteredProduce,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
                          imageUrl: produce.imageThumbnailUrl,
                          isSelected: isSelected,
                          onTap: () =>
                              widget.onItemToggled(produce.id, !isSelected),
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
