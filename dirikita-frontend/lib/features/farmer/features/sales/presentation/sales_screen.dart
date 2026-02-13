import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/farmer/features/sales/data/farmer_produce_repository.dart';
import 'package:duruha/features/farmer/features/sales/domain/farmer_selected_produce.dart';
import 'package:duruha/features/farmer/shared/presentation/widgets/navigation.dart';
import 'package:duruha/features/farmer/shared/presentation/loading_screen.dart';
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
  bool _isPledgeMode = true; // true = Pledge, false = Offer
  final Set<String> _selectedCropIds = {};

  List<FarmerSelectedProduce> _allCrops = [];
  List<FarmerSelectedProduce> _filteredCrops = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCrops();
  }

  Future<void> _fetchCrops() async {
    try {
      final crops = await _repository.fetchFarmerSelectedProduce("Bisaya");
      print(crops);
      if (mounted) {
        setState(() {
          _allCrops = crops;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

  void _toggleFavoriteFilter() {
    setState(() {
      _showFavoritesOnly = !_showFavoritesOnly;
      _applyFilters();
    });
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
              _isPledgeMode ? 'Pledge Crops' : 'Offer Crops',
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
            color: _showFavoritesOnly ? Colors.red : null,
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
                    // Add top padding for the floating toggle
                    padding: const EdgeInsets.fromLTRB(20, 80, 20, 100),
                    itemCount: _filteredCrops.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final crop = _filteredCrops[index];
                      final isSelected = _selectedCropIds.contains(crop.id);
                      return _buildCropCard(context, crop, isSelected);
                    },
                  ),
          ),
          // FLOATING TOGGLE (Top Left)
          Positioned(top: 20, left: 20, child: _buildModeToggle(context)),

          // BOTTOM FLOATING ACTION BAR
          if (_selectedCropIds.isNotEmpty)
            Positioned(right: 20, bottom: 40, child: _buildBottomFab(context)),
        ],
      ),
    );
  }

  Widget _buildModeToggle(BuildContext context) {
    final theme = Theme.of(context);

    return DuruhaToggleButton(
      value: _isPledgeMode,
      onChanged: (val) {
        setState(() {
          _isPledgeMode = val;
        });
      },
      labelTrue: "Pledge Mode",
      labelFalse: "Offer Mode",
      iconTrue: Icons.handshake,
      iconFalse: Icons.local_offer,
      colorTrue: theme.colorScheme.secondaryContainer,
      colorFalse: theme.colorScheme.primaryContainer,
      descriptionTrue: "Create a contract for future harvest.",
      descriptionFalse: "Sell your current stock immediately.",
    );
  }

  Widget _buildBottomFab(BuildContext context) {
    final theme = Theme.of(context);
    final count = _selectedCropIds.length;
    final icon = _isPledgeMode ? Icons.handshake : Icons.local_offer;
    final color = _isPledgeMode
        ? theme.colorScheme.secondaryContainer
        : theme.colorScheme.primaryContainer;
    final onColor = _isPledgeMode
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onPrimaryContainer;

    return Badge(
      label: Text(
        '$count',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      largeSize: 24,
      backgroundColor: theme.colorScheme.error,
      offset: const Offset(-5, -5), // Adjust badge position if needed
      child: FloatingActionButton(
        onPressed: _onActionPressed,
        backgroundColor: color,
        foregroundColor: onColor,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Icon(icon, size: 24),
      ),
    );
  }

  Widget _buildCropCard(BuildContext context, crop, bool isSelected) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: isSelected
            ? Border.all(color: theme.colorScheme.onSecondary, width: 1)
            : null,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            if (!isSelected)
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Material(
          color: theme.colorScheme.surface,
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected
                  ? Colors.transparent
                  : theme.colorScheme.outline.withOpacity(0.1),
            ),
          ),
          child: InkWell(
            onTap: () {
              Navigator.pushNamed(context, '/produce/${crop.id}');
            },
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  // Image / Icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      image: crop.imageUrl != null
                          ? DecorationImage(
                              image: NetworkImage(crop.imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: crop.imageUrl == null
                        ? const Center(
                            child: Text('🌱', style: TextStyle(fontSize: 24)),
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
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          crop.nameEnglish,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        if (_isPledgeMode) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Icon(
                                Icons.trending_up,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                "${DuruhaFormatter.formatNumber(crop.total30DaysDemand)} kg demand",
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.normal,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],
                    ),
                  ),

                  // Add/Remove Button
                  IconButton.filledTonal(
                    onPressed: () => _toggleSelection(crop.id),
                    icon: Icon(
                      isSelected ? Icons.check : Icons.add,
                      color: isSelected
                          ? theme.colorScheme.onSecondary
                          : theme.colorScheme.onPrimaryContainer,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: isSelected
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.surfaceContainerHighest,
                    ),
                    tooltip: isSelected ? "Remove from List" : "Add to List",
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
