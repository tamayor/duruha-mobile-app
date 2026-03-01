import 'package:duruha/shared/produce/data/produce_repository.dart';
import 'package:duruha/shared/produce/domain/produce_basic_info.dart';
import 'package:duruha/features/onboarding/presentation/components/selected_produce_summary.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:flutter/material.dart';

class ProduceSelectionStep extends StatefulWidget {
  final String userRole;
  final List<String> consumerFavProduce;
  final List<String> farmerFavProduce;
  final String searchQuery;
  final Function(String, bool) onItemToggled;
  final List<String> dialects;

  const ProduceSelectionStep({
    super.key,
    required this.userRole,
    required this.consumerFavProduce,
    required this.farmerFavProduce,
    required this.searchQuery,
    required this.onItemToggled,
    required this.dialects,
  });

  @override
  State<ProduceSelectionStep> createState() => _ProduceSelectionStepState();
}

class _ProduceSelectionStepState extends State<ProduceSelectionStep> {
  // ── Data ──────────────────────────────────────────────────────────────────
  final List<ProduceBasicInfo> _produceList = [];
  int _offset = 0;
  int _totalCount = 0;

  /// Keeps ProduceBasicInfo for every item the user has selected, regardless
  /// of which page is currently loaded or what the active search is.
  final Map<String, ProduceBasicInfo> _selectedProduceCache = {};

  // ── Status ────────────────────────────────────────────────────────────────
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;

  bool get _hasMore => _produceList.length < _totalCount;

  // ── Scroll ────────────────────────────────────────────────────────────────
  final _scrollController = ScrollController();
  static const _triggerDistance = 200.0; // px from bottom to trigger next load

  @override
  void initState() {
    super.initState();
    _fetchPage(reset: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant ProduceSelectionStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the parent's search query changes, reset and re-fetch
    if (oldWidget.searchQuery != widget.searchQuery) {
      _fetchPage(reset: true);
    }
    // Keep cache in sync: remove any item that was just deselected
    final currentIds =
        (widget.userRole == 'Consumer'
                ? widget.consumerFavProduce
                : widget.farmerFavProduce)
            .toSet();
    _selectedProduceCache.removeWhere((id, _) => !currentIds.contains(id));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Scroll listener ───────────────────────────────────────────────────────
  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - _triggerDistance) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (!_isLoadingMore && _hasMore) {
      _fetchPage(reset: false);
    }
  }

  // ── Fetch ─────────────────────────────────────────────────────────────────
  Future<void> _fetchPage({required bool reset}) async {
    if (reset) {
      // Avoid concurrent reset calls
      if (_isInitialLoading && _produceList.isEmpty && _offset == 0) {
        // First ever load — already in initial loading state
      } else {
        setState(() {
          _produceList.clear();
          _offset = 0;
          _totalCount = 0;
          _isInitialLoading = true;
        });
      }
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final repo = ProduceRepository();

      // Pass search from parent so the RPC filters server-side too
      final (items, total) = await repo.fetchProduceBasicInfoPaged(
        search: widget.searchQuery,
        offset: _offset,
      );

      if (mounted) {
        setState(() {
          _produceList.addAll(items);
          _totalCount = total;
          _offset = _produceList.length;
          _isInitialLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [ProduceSelectionStep] fetchPage error: $e');
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  // ── Cache helpers ─────────────────────────────────────────────────────────
  /// Call this whenever a card tap triggers onItemToggled so the cache stays
  /// in sync with the parent's favProduce lists.
  void _handleToggle(ProduceBasicInfo produce, bool selected) {
    if (selected) {
      _selectedProduceCache[produce.id] = produce;
    } else {
      _selectedProduceCache.remove(produce.id);
    }
    widget.onItemToggled(produce.id, selected);
  }

  // ── Summary sheet ─────────────────────────────────────────────────────────
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
          consumerFavProduce: widget.consumerFavProduce,
          farmerFavProduce: widget.farmerFavProduce,
          // Use the persistent cache so items selected via search
          // still appear even when that search is no longer active.
          availableProduce: _selectedProduceCache.values.toList(),
          onRemoveItem: (id) {
            _selectedProduceCache.remove(id);
            widget.onItemToggled(id, false);
            setState(() {});
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
              _showSummary();
            }
          },
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final selectedCount = widget.userRole == 'Consumer'
        ? widget.consumerFavProduce.length
        : widget.farmerFavProduce.length;

    return Stack(
      children: [
        // ─── Grid ──────────────────────────────────────────────────────────
        if (_isInitialLoading)
          const Center(child: CircularProgressIndicator())
        else
          GridView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 4,
              bottom: 100,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            // +1 extra cell for the bottom loading indicator
            itemCount:
                _produceList.length + (_isLoadingMore || _hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              // Last cell: full-width loading spinner
              if (index == _produceList.length) {
                return Center(
                  child: _isLoadingMore
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const SizedBox.shrink(),
                );
              }

              final produce = _produceList[index];
              final isSelected = widget.userRole == 'Consumer'
                  ? widget.consumerFavProduce.contains(produce.id)
                  : widget.farmerFavProduce.contains(produce.id);

              return DuruhaSelectionCard(
                isList: false,
                title: produce.localName,
                imageUrl: produce.imageUrl,
                isSelected: isSelected,
                onTap: () => _handleToggle(produce, !isSelected),
              );
            },
          ),

        // ─── Floating Summary Button ────────────────────────────────────────
        Positioned(
          bottom: 24,
          right: 24,
          child: AnimatedScale(
            scale: selectedCount > 0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 300),
            child: FloatingActionButton(
              onPressed: selectedCount > 0 ? _showSummary : null,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 4,
              shape: const CircleBorder(),
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
