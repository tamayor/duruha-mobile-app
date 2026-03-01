import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:duruha/core/helpers/duruha_helpers.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:duruha/shared/produce/presentation/widgets/produce_dialect_widget.dart';
import 'package:duruha/features/admin/produce/data/produce_repository.dart';
import 'package:duruha/features/admin/shared/presentation/widgets/admin_navigation.dart';
import 'package:duruha/features/admin/produce/presentation/admin_produce_form_screen.dart';
import 'package:duruha/features/admin/produce/presentation/admin_produce_varieties_screen.dart';

class AdminProduceScreen extends StatefulWidget {
  const AdminProduceScreen({super.key});

  @override
  State<AdminProduceScreen> createState() => _AdminProduceScreenState();
}

class _AdminProduceScreenState extends State<AdminProduceScreen> {
  final List<Produce> _produceList = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  ProduceCursor? _cursor;

  // Local Filtering & Sorting Search States
  Timer? _debounce;
  bool _isSortedAscending = true;
  bool _isSearchVisible = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final ScrollController _scrollController = ScrollController();
  late final ProduceRepository _repo;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _repo = ProduceRepository(Supabase.instance.client);
    _scrollController.addListener(_onScroll);
    _loadInitialData();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('admin_produce_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'produce',
          callback: (_) => _debouncedReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'produce_varieties',
          callback: (_) => _debouncedReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'produce_variety_listing',
          callback: (_) => _debouncedReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'produce_dialects',
          callback: (_) => _debouncedReload(),
        )
        .subscribe();
  }

  void _debouncedReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      // Only reload paginated list; don't interrupt active search
      if (_searchController.text.trim().isEmpty) {
        _loadInitialData(isRefresh: true);
      } else {
        _searchProduce(_searchController.text.trim(), isRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (_isSearchVisible) {
        _searchFocusNode.requestFocus();
      } else {
        _searchFocusNode.unfocus();
        _searchController.clear();
        _onSearchChanged(''); // trigger empty search to reload paginated data
      }
    });
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      if (query.trim().isEmpty) {
        // revert to paginated list
        _cursor = null;
        _hasMore = true;
        _loadInitialData();
      } else {
        _searchProduce(query);
      }
    });
  }

  Future<void> _searchProduce(String query, {bool isRefresh = false}) async {
    setState(() {
      if (!isRefresh) _isLoading = true;
      _error = null;
    });

    try {
      final results = await _repo.searchProduce(query);
      if (mounted) {
        setState(() {
          _produceList.clear();
          _produceList.addAll(results);
          _hasMore = false; // Disable pagination while searching
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreData();
    }
  }

  Future<void> _loadInitialData({bool isRefresh = false}) async {
    setState(() {
      if (!isRefresh) {
        _isLoading = true;
        _produceList.clear();
      }
      _error = null;
      _hasMore = true;
      _cursor = null;
    });

    try {
      final initialData = await _repo.getAllProduceWithVarieties(limit: 10);
      if (mounted) {
        setState(() {
          if (isRefresh) {
            _produceList.clear();
          }
          _produceList.addAll(initialData.data);
          _hasMore = initialData.hasMore;
          if (initialData.nextCursor != null) {
            _cursor = initialData.nextCursor;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreData() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final moreData = await _repo.getAllProduceWithVarieties(
        cursor: _cursor,
        limit: 10,
      );

      if (mounted) {
        setState(() {
          _produceList.addAll(moreData.data);
          _hasMore = moreData.hasMore;
          if (moreData.nextCursor != null) {
            _cursor = moreData.nextCursor;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        DuruhaSnackBar.showError(context, 'Failed to load more: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DuruhaScaffold(
      appBarTitleWidget: _isSearchVisible
          ? TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: theme.textTheme.titleMedium,
              decoration: InputDecoration(
                hintText: 'Search produce...',
                border: InputBorder.none,
                hintStyle: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              onChanged: (val) {
                _onSearchChanged(val);
              },
            )
          : Text(
              'Produce Pricing',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
      appBarActions: [
        IconButton(
          onPressed: _toggleSearch,
          icon: Icon(_isSearchVisible ? Icons.close : Icons.search),
          tooltip: _isSearchVisible ? "Close Search" : "Search",
        ),
        IconButton(
          icon: Icon(
            _isSortedAscending
                ? Icons.sort_by_alpha_rounded
                : Icons.sort_rounded,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
          onPressed: () {
            setState(() {
              _isSortedAscending = !_isSortedAscending;
            });
          },
          tooltip: 'Sort locally A-Z',
        ),
        const SizedBox(width: 8),
      ],
      showBackButton: false,
      bottomNavigationBar: const AdminNavigation(
        currentRoute: '/admin/produce',
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminProduceFormScreen(),
            ),
          ).then((_) {
            _loadInitialData();
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Produce'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _produceList.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _produceList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Failed to load produce:\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadInitialData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_produceList.isEmpty && !_isLoading) {
      return const Center(child: Text('No produce found.'));
    }

    // 1. Locally Sort Ascending / Descending (Filters operate directly on the list now)
    var sortedList = List<Produce>.from(_produceList);
    sortedList.sort((a, b) {
      final nameA = a.englishName.toLowerCase();
      final nameB = b.englishName.toLowerCase();
      return _isSortedAscending
          ? nameA.compareTo(nameB)
          : nameB.compareTo(nameA);
    });

    return RefreshIndicator(
      onRefresh: _loadInitialData,
      child: DuruhaGridView(
        physics: const AlwaysScrollableScrollPhysics(),
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 100),
        children: [
          ...sortedList.map((produce) => _buildProduceCard(context, produce)),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildProduceCard(BuildContext context, Produce produce) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: DuruhaInkwell(
        variation: InkwellVariation.brand,
        onTap: () => _showProduceDetailsModal(context, produce),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (produce.imageHeroUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    produce.imageHeroUrl,
                    width: context.screenWidth,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildProduceTypeIcon(produce.category, scheme),
                  ),
                )
              else
                _buildProduceTypeIcon(produce.category, scheme),
              const SizedBox(height: 12),
              Text(
                produce.englishName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                produce.scientificName ?? 'No scientific name',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              if (produce.varieties.isNotEmpty) ...[
                Builder(
                  builder: (context) {
                    final minPrice = produce.varieties
                        .map((v) => v.price)
                        .reduce(math.min);
                    final maxPrice = produce.varieties
                        .map((v) => v.price)
                        .reduce(math.max);
                    final priceText = minPrice == maxPrice
                        ? DuruhaFormatter.formatCurrency(minPrice)
                        : '${DuruhaFormatter.formatCurrency(minPrice)} - ${DuruhaFormatter.formatCurrency(maxPrice)}';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        priceText,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onTertiary,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            AdminProduceVarietiesScreen(produce: produce),
                      ),
                    ).then((_) => _loadInitialData());
                  },
                  icon: const Icon(Icons.eco_rounded, size: 16),
                  label: Text('${produce.varieties.length} Varieties'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: scheme.onSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProduceDetailsModal(BuildContext context, Produce produce) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    DuruhaBottomSheet.show(
      context: context,
      title: '${produce.englishName} Details',
      icon: Icons.info_outline,
      isScrollable: true,
      heightFactor: 0.8,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (produce.scientificName != null)
              Text(
                produce.scientificName!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: scheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Category',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  produce.category,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Base Unit',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  produce.unitOfMeasure,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Storage Group',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  produce.storageGroup ?? "",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Respiration Rate',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  produce.respirationRate ?? "",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Crush Weight Tolerance',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  '${produce.crushWeightTolerance}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Contamination Risk',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  produce.crossContaminationRisk?.isEmpty ?? true
                      ? 'None'
                      : produce.crossContaminationRisk!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ethylene Producer',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  produce.isEthyleneProducer ?? false ? 'Yes' : 'No',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Ethylene Sensitive',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  produce.isEthyleneSensitive ?? false ? 'Yes' : 'No',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Text(
              'Local Names',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ProduceDialectWidget(
              produceId: produce.id,
              dialects: produce.dialects,
            ),
            const SizedBox(height: 8),
            DuruhaButton(
              onPressed: () {
                Navigator.pop(context); // Close modal first
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AdminProduceFormScreen(produceToEdit: produce),
                  ),
                ).then((_) {
                  _loadInitialData();
                });
              },
              text: 'Edit Produce Matrix',
              icon: const Icon(Icons.edit_note_rounded),
              isOutline: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProduceTypeIcon(String category, ColorScheme scheme) {
    IconData icon;
    switch (category.toLowerCase()) {
      case 'vegetable':
      case 'vegetables':
        icon = Icons.eco_rounded;
        break;
      case 'fruit':
      case 'fruits':
        icon = Icons.apple_rounded;
        break;
      default:
        icon = Icons.park_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: scheme.primary),
    );
  }
}
