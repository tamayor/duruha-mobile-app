import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/farmer/features/sales/data/farmer_produce_repository.dart';
import 'package:duruha/features/farmer/features/sales/domain/farmer_selected_produce.dart';
import 'package:duruha/features/farmer/shared/presentation/widgets/navigation.dart';
import 'package:duruha/features/farmer/shared/presentation/farmer_loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum SortOption { rankAsc, rankDesc, nameAsc, nameDesc }

class FarmerSalesScreen extends StatefulWidget {
  const FarmerSalesScreen({super.key});

  @override
  State<FarmerSalesScreen> createState() => _FarmerSalesScreenState();
}

class _FarmerSalesScreenState extends State<FarmerSalesScreen> {
  final _repository = FarmerProduceRepository();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  bool _isSearchVisible = false;
  bool _showFavoritesOnly = false;
  bool _isPledgeMode = false; // false = Offer (Pledge disabled for now)
  final Set<String> _selectedCropIds = {};

  List<FarmerSelectedProduce> _allCrops = [];
  List<FarmerSelectedProduce> _filteredCrops = [];
  bool _isLoading = true;

  // Pagination State
  final _scrollController = ScrollController();
  bool _isFetchingMore = false;
  bool _hasMore = false;
  int? _nextOffset;

  @override
  void initState() {
    super.initState();
    _loadPersistenceSettings();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isFetchingMore &&
        _hasMore) {
      _fetchMoreCrops();
    }
  }

  Future<void> _loadPersistenceSettings() async {
    final showFavs = await SessionService.getFavoritePreference();
    // Mode preference ignored for now - forcing Offer Mode
    if (mounted) {
      setState(() {
        _showFavoritesOnly = showFavs;
        _isPledgeMode = false;
      });
      _fetchCrops();
    }
  }

  Future<void> _fetchCrops({bool reset = true}) async {
    if (reset) {
      if (mounted) setState(() => _isLoading = true);
      _nextOffset = 0;
      _hasMore = true;
    }

    if (!_hasMore) return;

    try {
      final result = await _repository.fetchFarmerProduce(
        favoritesOnly: _showFavoritesOnly,
        searchQuery: _searchController.text,
        offset: _nextOffset ?? 0,
      );

      if (mounted) {
        setState(() {
          if (reset) {
            _allCrops = result.data;
          } else {
            _allCrops.addAll(result.data);
          }
          _hasMore = result.hasMore;
          _nextOffset = result.nextOffset;
          _applyFilters();
          _isLoading = false;
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetchingMore = false;
        });
      }
    }
  }

  Future<void> _fetchMoreCrops() async {
    if (_isFetchingMore || !_hasMore) return;
    setState(() => _isFetchingMore = true);
    await _fetchCrops(reset: false);
  }

  void _applyFilters() {
    setState(() {
      var crops = _allCrops;

      // Filter by Search
      final query = _searchController.text.toLowerCase();
      if (query.isNotEmpty) {
        crops = crops.where((crop) {
          return crop.nameDialect.toLowerCase().contains(query) ||
              crop.nameEnglish.toLowerCase().contains(query);
        }).toList();
      }

      _filteredCrops = crops;
    });
  }

  void _toggleFavoriteFilter() async {
    setState(() {
      _showFavoritesOnly = !_showFavoritesOnly;
    });
    await SessionService.saveFavoritePreference(_showFavoritesOnly);
    _fetchCrops();
  }

  void _toggleSelection(String cropId) {
    setState(() {
      if (_selectedCropIds.contains(cropId)) {
        _selectedCropIds.remove(cropId);
      } else {
        _selectedCropIds.add(cropId);
      }
    });
  }

  Future<void> _onActionPressed() async {
    if (_selectedCropIds.isEmpty) return;
    HapticFeedback.mediumImpact();
    // Redirect to pledge creation with selected IDs
    // Pass mode too if needed, for now just IDs
    final result = await Navigator.pushNamed(
      context,
      '/farmer/tx/create',
      arguments: {
        'ids': _selectedCropIds.toList(),
        'mode': _isPledgeMode ? 'pledge' : 'offer',
      },
    );

    if (!mounted) return;

    // Update selection from result
    if (result is List<String>) {
      setState(() {
        _selectedCropIds.clear();
        _selectedCropIds.addAll(result);
      });
    } else if (result is List<dynamic>) {
      // Handle dynamic list if type check fails
      setState(() {
        _selectedCropIds.clear();
        _selectedCropIds.addAll(result.cast<String>());
      });
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
        _applyFilters();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const displayName = "Elly";

    return DuruhaScaffold(
      // TITLE LOGIC
      appBarTitleWidget: _isSearchVisible
          ? TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: theme.textTheme.titleMedium,
              decoration: InputDecoration(
                hintText: 'Search crops...',
                border: InputBorder.none,
                hintStyle: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              onChanged: (_) => _applyFilters(),
            )
          : Text(
              _isPledgeMode ? 'Pledge Produce' : 'Offer Produce',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),

      // ACTIONS LOGIC
      appBarActions: [
        // Search Toggle
        IconButton(
          onPressed: _toggleSearch,
          icon: Icon(_isSearchVisible ? Icons.close : Icons.search),
          tooltip: _isSearchVisible ? "Close Search" : "Search",
        ),
        // Favorite Toggle
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
        const SizedBox(width: 8),
      ],

      bottomNavigationBar: const FarmerNavigation(
        name: displayName,
        currentRoute: '/farmer/sales',
      ),

      body: Stack(
        children: [
          // MAIN CONTENT
          Positioned.fill(
            child: _isLoading
                ? const FarmerLoadingScreen()
                : _filteredCrops.isEmpty
                ? Center(
                    child: Text(
                      'No crops found.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 80, 20, 100),
                    itemCount:
                        _filteredCrops.length + (_isFetchingMore ? 1 : 0),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      if (index == _filteredCrops.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final crop = _filteredCrops[index];
                      final isSelected = _selectedCropIds.contains(crop.id);
                      return _buildCropCard(context, crop, isSelected);
                    },
                  ),
          ),
          // FLOATING TOGGLE (Top Left) - Disabled for now
          Positioned(top: 20, left: 20, child: _buildModeToggle(context)),

          // BOTTOM FLOATING ACTION BAR
          if (_selectedCropIds.isNotEmpty)
            Positioned(right: 20, bottom: 40, child: _buildBottomFab(context)),
        ],
      ),
    );
  }

  Widget _buildModeToggle(BuildContext context) {
    return DuruhaToggleButton(
      value: _isPledgeMode,
      onChanged: (val) async {
        if (val == true) {
          DuruhaSnackBar.showInfo(context, "Pledge mode is coming soon!");
          return;
        }
        setState(() {
          _isPledgeMode = val;
        });
        await SessionService.saveModePreference(val);
      },
      labelTrue: "Pledge Mode",
      labelFalse: "Offer Mode",
      iconTrue: Icons.handshake,
      iconFalse: Icons.local_offer,
    );
  }

  Widget _buildBottomFab(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final count = _selectedCropIds.length;
    final icon = _isPledgeMode ? Icons.handshake : Icons.local_offer;

    final backgroundColor = _isPledgeMode ? scheme.primary : scheme.tertiary;

    final foregroundColor = _isPledgeMode
        ? scheme.onPrimary
        : scheme.onTertiary;

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

  Widget _buildCropCard(BuildContext context, crop, bool isSelected) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected
            ? scheme.primaryContainer.withValues(alpha: 0.25)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? scheme.primary : scheme.outlineVariant,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: scheme.surface,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.pushNamed(context, '/produce/${crop.id}');
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Image / Icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                    image: crop.imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(crop.imageUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: crop.imageUrl == null
                      ? Center(
                          child: Text(
                            '🌱',
                            style: TextStyle(
                              fontSize: 24,
                              color: scheme.onTertiaryContainer,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        crop.nameDialect,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            crop.nameEnglish,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          if (crop.varietyCount > 0) ...[
                            Text(
                              " • ",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                            ),
                            Text(
                              crop.varietyCount.toString(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: scheme.onSecondary,
                              ),
                            ),
                            Text(
                              " varieties",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant.withValues(
                                  alpha: 0.5,
                                ),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_isPledgeMode) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(
                              Icons.trending_up,
                              size: 14,
                              color: scheme.tertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "${DuruhaFormatter.formatNumber(crop.total30DaysDemand)} kg demand",
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Add / Remove Button
                IconButton.filledTonal(
                  onPressed: () => _toggleSelection(crop.id),
                  icon: Icon(isSelected ? Icons.check : Icons.add),
                  style: IconButton.styleFrom(
                    backgroundColor: isSelected
                        ? scheme.primary
                        : scheme.secondaryContainer,
                    foregroundColor: isSelected
                        ? scheme.onPrimary
                        : scheme.onSecondaryContainer,
                  ),
                  tooltip: isSelected ? "Remove from List" : "Add to List",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
