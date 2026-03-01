import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/farmer/features/sales/data/farmer_produce_repository.dart';
import 'package:duruha/features/farmer/features/sales/domain/farmer_selected_produce.dart';
import 'package:duruha/features/farmer/shared/presentation/widgets/navigation.dart';
import 'package:duruha/features/farmer/shared/presentation/farmer_loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum SortOption { rankAsc, rankDesc, nameAsc, nameDesc }

class FarmerCropsScreen extends StatefulWidget {
  const FarmerCropsScreen({super.key});

  @override
  State<FarmerCropsScreen> createState() => _FarmerCropsScreenState();
}

class _FarmerCropsScreenState extends State<FarmerCropsScreen> {
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

  @override
  void initState() {
    super.initState();
    _fetchCrops();
  }

  Future<void> _fetchCrops() async {
    try {
      final userId = await SessionService.getUserId() ?? '';
      final result = await _repository.fetchFarmerProduce(userId);
      if (mounted) {
        setState(() {
          _allCrops = result.data;
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

      // Filter by Favorites (Mock logic for now, using rank < 5 as "favorites")
      if (_showFavoritesOnly) {
        crops = crops.where((crop) => (crop.rank ?? 99) <= 5).toList();
      }

      _filteredCrops = crops;
      // Removed sort logic call as SortOption was removed
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

  void _onActionPressed() {
    if (_selectedCropIds.isEmpty) return;
    HapticFeedback.mediumImpact();
    // Redirect to pledge creation with selected IDs
    // Pass mode too if needed, for now just IDs
    Navigator.pushNamed(
      context,
      '/farmer/pledge/create',
      arguments: {
        'ids': _selectedCropIds.toList(),
        'mode': _isPledgeMode ? 'pledge' : 'offer',
      },
    );
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
              'Crops',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),

      // ACTIONS LOGIC
      appBarActions: [
        // Favorite Toggle
        if (!_isSearchVisible)
          IconButton(
            onPressed: _toggleFavoriteFilter,
            icon: Icon(
              _showFavoritesOnly ? Icons.favorite : Icons.favorite_border,
              color: _showFavoritesOnly ? Colors.red : null,
            ),
            tooltip: "Show Favorites",
          ),

        // Search Toggle
        IconButton(
          onPressed: _toggleSearch,
          icon: Icon(_isSearchVisible ? Icons.close : Icons.search),
          tooltip: _isSearchVisible ? "Close Search" : "Search",
        ),

        // Removed Sort Button
        const SizedBox(width: 8),
      ],

      bottomNavigationBar: const FarmerNavigation(
        name: displayName,
        currentRoute: '/farmer/crops',
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
        if (val == true) {
          DuruhaSnackBar.showInfo(context, "Pledge mode is coming soon!");
          return;
        }
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
        ? theme.colorScheme.primary
        : theme.colorScheme.tertiary;
    final onColor = _isPledgeMode
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onTertiary;

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

  Widget _buildCropCard(
    BuildContext context,
    FarmerSelectedProduce crop,
    bool isSelected,
  ) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: isSelected
            ? Border.all(color: theme.colorScheme.primary, width: 2)
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
                  : theme.colorScheme.outline.withValues(alpha: 0.1),
            ),
          ),
          child: InkWell(
            onTap: () {
              Navigator.pushNamed(context, '/produce/${crop.id}');
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Rank Badge
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '#${crop.rank ?? "?"}',
                      style: TextStyle(
                        color: theme.colorScheme.onSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

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
                      ],
                    ),
                  ),

                  // Add/Remove Button
                  IconButton.filledTonal(
                    onPressed: () => _toggleSelection(crop.id),
                    icon: Icon(
                      isSelected ? Icons.check : Icons.add,
                      color: isSelected ? theme.colorScheme.primary : null,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: isSelected
                          ? theme.colorScheme.primaryContainer
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
