import 'dart:async';
import 'package:duruha/core/helpers/duruha_helpers.dart';
import 'package:duruha/features/consumer/shared/presentation/consumer_loading_screen.dart';
import 'package:duruha/core/services/session_service.dart';

import 'package:duruha/core/widgets/duruha_widgets.dart';

import 'package:duruha/features/consumer/features/shop/data/consumer_produce_repository.dart';
import 'package:duruha/features/consumer/features/shop/domain/consumer_selected_produce.dart';
import 'package:duruha/features/consumer/shared/presentation/navigation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConsumerShopScreen extends StatefulWidget {
  const ConsumerShopScreen({super.key});

  @override
  State<ConsumerShopScreen> createState() => _ConsumerShopScreenState();
}

enum SortOption { nameAZ, nameZA, offersHighLow, offersLowHigh, category }

class _ConsumerShopScreenState extends State<ConsumerShopScreen> {
  final _repository = ConsumerProduceRepository();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  bool _isSearchVisible = false;
  bool _showFavoritesOnly = false;
  bool _isPlanMode = false;
  SortOption _currentSortOption = SortOption.nameAZ;

  final _scrollController = ScrollController();
  bool _isFetchingMore = false;
  int _offset = 0;
  int _totalCount = 0;
  bool get _hasMore => _allCrops.length < _totalCount;
  final Set<String> _selectedCropIds = {};

  RealtimeChannel? _realtimeChannel;
  Timer? _debounce;

  List<ConsumerSelectedProduce> _allCrops = [];
  List<ConsumerSelectedProduce> _filteredCrops = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadPersistenceSettings();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('shop_farmer_offers_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'farmer_offers',
          callback: (_) => _debouncedReload(),
        )
        .subscribe();
  }

  void _debouncedReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _fetchProduce(silent: true);
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isFetchingMore && _hasMore) _fetchMoreProduce();
    }
  }

  Future<void> _loadPersistenceSettings() async {
    final showFavs = await SessionService.getFavoritePreference();
    if (mounted) {
      setState(() {
        _showFavoritesOnly = showFavs;
      });
      _fetchProduce();
    }
  }

  Future<void> _fetchProduce({bool silent = false}) async {
    setState(() {
      if (!silent) _isLoading = true;
      _allCrops = [];
      _offset = 0;
      _totalCount = 0;
    });
    try {
      final user = await SessionService.getSavedUser();
      final (items, total) = await _repository.fetchProducePage(
        userId: user!.id,
        offset: 0,
        favoritesOnly: _showFavoritesOnly,
        search: _searchController.text,
      );
      if (mounted) {
        setState(() {
          _allCrops = items;
          _offset = items.length;
          _totalCount = total;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchMoreProduce() async {
    if (_isFetchingMore || !_hasMore) return;
    setState(() => _isFetchingMore = true);
    try {
      final user = await SessionService.getSavedUser();
      final (items, total) = await _repository.fetchProducePage(
        userId: user!.id,
        offset: _offset,
        favoritesOnly: _showFavoritesOnly,
        search: _searchController.text,
      );
      if (mounted) {
        setState(() {
          _allCrops.addAll(items);
          _offset = _allCrops.length;
          _totalCount = total;
          _applyFilters();
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isFetchingMore = false);
    }
  }

  void _applyFilters() {
    setState(() {
      var crops = List<ConsumerSelectedProduce>.from(_allCrops);

      // Apply Sorting
      switch (_currentSortOption) {
        case SortOption.nameAZ:
          crops.sort((a, b) => a.nameDialect.compareTo(b.nameDialect));
          break;
        case SortOption.nameZA:
          crops.sort((a, b) => b.nameDialect.compareTo(a.nameDialect));
          break;
        case SortOption.offersHighLow:
          crops.sort(
            (a, b) => b.total30DaysOffer.compareTo(a.total30DaysOffer),
          );
          break;
        case SortOption.offersLowHigh:
          crops.sort(
            (a, b) => a.total30DaysOffer.compareTo(b.total30DaysOffer),
          );
          break;
        case SortOption.category:
          crops.sort((a, b) {
            final catComp = a.category.compareTo(b.category);
            if (catComp != 0) return catComp;
            return a.nameDialect.compareTo(b.nameDialect);
          });
          break;
      }

      _filteredCrops = crops;
    });
  }

  void _toggleFavoriteFilter() async {
    setState(() {
      _showFavoritesOnly = !_showFavoritesOnly;
      _isLoading = true;
    });
    await SessionService.saveFavoritePreference(_showFavoritesOnly);
    _fetchProduce();
  }

  void _toggleSelection(ConsumerSelectedProduce item) {
    if (!_isPlanMode && item.varietyCountWithOffers == 0) {
      if (mounted) {
        DuruhaSnackBar.showError(
          context,
          "This produce has no available varieties for ordering right now.",
        );
      }
      return;
    }

    setState(() {
      if (_selectedCropIds.contains(item.id)) {
        _selectedCropIds.remove(item.id);
      } else {
        _selectedCropIds.add(item.id);
      }
    });
  }

  Future<void> _onActionPressed() async {
    if (_selectedCropIds.isEmpty) return;
    HapticFeedback.mediumImpact();

    final mode = _isPlanMode ? 'plan' : 'order';

    final result = await Navigator.of(context).pushNamed(
      '/consumer/tx/create',
      arguments: {'ids': _selectedCropIds.toList(), 'mode': mode},
    );

    if (mounted && result != null) {
      if (result is List<String>) {
        setState(() {
          _selectedCropIds.clear();
          _selectedCropIds.addAll(result);
        });
      } else if (result is List) {
        setState(() {
          _selectedCropIds.clear();
          _selectedCropIds.addAll(result.cast<String>());
        });
      }
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (_isSearchVisible) {
        _searchFocusNode.requestFocus();
      } else {
        _searchFocusNode.unfocus();
        _searchController.clear();
        _fetchProduce();
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DuruhaScaffold(
      onBackPressed: () {
        Navigator.of(context).pop();
      },
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
              onChanged: (_) => _debouncedReload(),
            )
          : Text(
              _isPlanMode ? 'Plan Order' : 'Order Now',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),

      // ACTIONS LOGIC
      appBarActions: [
        IconButton(
          onPressed: _toggleSearch,
          icon: Icon(_isSearchVisible ? Icons.close : Icons.search),
          tooltip: _isSearchVisible ? "Close Search" : "Search",
        ),
        IconButton(
          onPressed: _toggleFavoriteFilter,
          icon: Icon(
            _showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
            color: _showFavoritesOnly
                ? Colors.red
                : theme.colorScheme.onSecondary,
          ),
          tooltip: "Show Favorites",
        ),
        DuruhaPopupMenu<SortOption>(
          showBackground: false,
          showLabel: false,
          items: SortOption.values,
          selectedValue: _currentSortOption,
          onSelected: (option) {
            setState(() {
              _currentSortOption = option;
              _applyFilters();
            });
          },
          labelBuilder: (option) {
            switch (option) {
              case SortOption.nameAZ:
                return "Name (A-Z)";
              case SortOption.nameZA:
                return "Name (Z-A)";
              case SortOption.offersHighLow:
                return "Most Offers";
              case SortOption.offersLowHigh:
                return "Least Offers";
              case SortOption.category:
                return "Category";
            }
          },
          itemIcons: const {
            SortOption.nameAZ: Icons.sort_by_alpha,
            SortOption.nameZA: Icons.sort_by_alpha,
            SortOption.offersHighLow: Icons.trending_up,
            SortOption.offersLowHigh: Icons.trending_down,
            SortOption.category: Icons.category_outlined,
          },
          icon: Icon(Icons.sort, color: theme.colorScheme.onSecondary),
          tooltip: "Sort Menu",
        ),
        const SizedBox(width: 8),
      ],

      bottomNavigationBar: const ConsumerNavigation(
        currentRoute: '/consumer/shop',
      ),

      body: Stack(
        children: [
          // MAIN CONTENT
          Positioned.fill(
            child: _isLoading
                ? const ConsumerLoadingScreen()
                : _filteredCrops.isEmpty
                ? Center(
                    child: Text(
                      'No produce found.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchProduce,
                    child: DuruhaGridView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 80, 16, 100),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.8,
                      children: [
                        ..._filteredCrops.map((item) {
                          final isSelected = _selectedCropIds.contains(item.id);
                          return Tooltip(
                            preferBelow: false,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.1,
                                ),
                              ),
                            ),
                            richMessage: TextSpan(
                              children: [
                                TextSpan(
                                  text: '• ',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSecondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (!_isPlanMode)
                                  TextSpan(
                                    text: '${item.varietyCountWithOffers}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                TextSpan(
                                  text: _isPlanMode
                                      ? '${item.totalVarietyCount} varieties\n'
                                      : '/${item.totalVarietyCount} varieties available\n',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSecondary
                                        .withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),

                                const TextSpan(
                                  text:
                                      '• Tap image for details.\n• Tap body to add.',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            showDuration: const Duration(seconds: 2),
                            triggerMode: TooltipTriggerMode.longPress,
                            child: _buildCropCard(context, item, isSelected),
                          );
                        }),
                        if (_hasMore)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
          // FLOATING TOGGLE (Top Left)
          Positioned(left: 20, top: 20, child: _buildModeToggle(context)),

          // BOTTOM FLOATING ACTION BAR
          if (_selectedCropIds.isNotEmpty)
            Positioned(right: 20, bottom: 40, child: _buildBottomFab(context)),
        ],
      ),
    );
  }

  Widget _buildModeToggle(BuildContext context) {
    return DuruhaToggleButton(
      value: _isPlanMode,
      onChanged: (val) {
        setState(() {
          _isPlanMode = val;
          // Clear selections of unavailable items if switching to Order Mode
          if (!_isPlanMode) {
            _selectedCropIds.removeWhere((id) {
              final crop = _allCrops.firstWhere(
                (c) => c.id == id,
                orElse: () => _allCrops.first,
              );
              return crop.varietyCountWithOffers == 0;
            });
          }
        });
      },
      labelTrue: "Plan Mode",
      labelFalse: "Order Mode",
      iconTrue: Icons.calendar_today,
      iconFalse: Icons.shopping_cart,
      descriptionTrue: "Pre-order for future harvest.",
      descriptionFalse: "Buy available stock now.",
    );
  }

  Widget _buildBottomFab(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final count = _selectedCropIds.length;
    final icon = _isPlanMode ? Icons.calendar_month : Icons.shopping_cart;

    final backgroundColor = _isPlanMode ? scheme.primary : scheme.tertiary;

    final foregroundColor = _isPlanMode ? scheme.onPrimary : scheme.onTertiary;

    final fab = FloatingActionButton(
      onPressed: _onActionPressed,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Icon(icon, size: 24),
    );

    if (count == 0) return fab;

    return Badge(
      label: Text(
        '$count',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: scheme.onError,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      largeSize: 24,
      backgroundColor: scheme.error,
      offset: const Offset(-5, -5),
      child: fab,
    );
  }

  Widget _buildCropCard(
    BuildContext context,
    ConsumerSelectedProduce item,
    bool isSelected,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final isDisabled = !_isPlanMode && item.varietyCountWithOffers == 0;

    return Card(
      elevation: isSelected
          ? 2
          : 0, // Lower elevation for a flatter, modern look
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20), // Softer corners
        side: BorderSide(
          color: isSelected
              ? scheme.primary
              : scheme.outlineVariant.withValues(alpha: 0.5),
          width: isSelected ? 2.0 : 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Allow card to wrap content height
        children: [
          DuruhaInkwell(
            variation: InkwellVariation.subtle,
            borderRadius: 0,
            onTap: () => Navigator.pushNamed(context, '/produce/${item.id}'),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                children: [
                  Positioned.fill(child: _buildCropThumbnail(context, item)),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          // Fades from transparent (top half) to black (bottom)
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.0),
                            Colors.black.withValues(alpha: 0.7),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _buildCategoryBadge(context, item.category),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: _buildStatColumn(
                      context,
                      label: 'Avg. Available',
                      value: item.total30DaysOffer > 0
                          ? '${DuruhaFormatter.formatCompactNumber(item.total30DaysOffer)} ${item.baseUnit}'
                          : 'No offers',
                      icon: Icons.inventory_2_outlined,
                      isSelected: isSelected,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Info Area
          Opacity(
            opacity: isDisabled ? 0.5 : 1.0,
            child: DuruhaInkwell(
              variation: isSelected
                  ? InkwellVariation.brand
                  : InkwellVariation.subtle,
              onTap: () => _toggleSelection(item),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Toggle Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          item.nameDialect,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            color: isSelected
                                ? scheme.onPrimary
                                : scheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  // Scientific Name
                  if (item.nameEnglish.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text(
                        item.nameEnglish,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: isSelected
                              ? scheme.onPrimary.withValues(alpha: 0.8)
                              : scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                  const SizedBox(height: 12),
                  Divider(
                    height: 1,
                    color: isSelected
                        ? scheme.onPrimary.withValues(alpha: 0.2)
                        : scheme.outlineVariant,
                  ),
                  const SizedBox(height: 12),

                  // Stats Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : (isDisabled
                                  ? Icons.remove_circle_outline_rounded
                                  : Icons.add_circle_outline_rounded),
                        color: isSelected
                            ? scheme.onPrimary
                            : (isDisabled ? scheme.outline : scheme.primary),
                        size: 22,
                      ),
                      Expanded(
                        child: _buildStatColumn(
                          context,
                          label: 'Varieties',
                          value: _isPlanMode
                              ? '${item.totalVarietyCount} varieties'
                              : (item.totalVarietyCount > 0
                                    ? '${item.varietyCountWithOffers}/${item.totalVarietyCount} available'
                                    : '—'),
                          icon: Icons.local_florist_outlined,
                          isSelected: isSelected,
                          crossAxisAlignment: CrossAxisAlignment.end,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper to keep the code DRY and clean
  Widget _buildStatColumn(
    BuildContext context, {
    required String label,
    required String value,
    IconData? icon,
    required bool isSelected,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.start,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = isSelected ? scheme.onPrimary : scheme.onSurface;

    return Column(
      crossAxisAlignment: crossAxisAlignment,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 10,
            color: isSelected
                ? scheme.onPrimary.withValues(alpha: 0.7)
                : scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                value,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCropThumbnail(
    BuildContext context,
    ConsumerSelectedProduce crop,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final hasImage = crop.imageUrl?.isNotEmpty ?? false;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        image: hasImage
            ? DecorationImage(
                image: NetworkImage(crop.imageUrl!),
                fit: BoxFit.cover,
                alignment: Alignment.center,
              )
            : null,
      ),

      child: hasImage
          ? null
          : const Center(child: Text('🌱', style: TextStyle(fontSize: 48))),
    );
  }

  Widget _buildCategoryBadge(BuildContext context, String category) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Text(
        category.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: scheme.onSecondaryContainer,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
