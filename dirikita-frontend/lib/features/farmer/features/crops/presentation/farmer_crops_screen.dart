import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/farmer/features/crops/data/selected_crops_repository.dart';
import 'package:duruha/features/farmer/features/crops/domain/selected_crop_summary.dart';
import 'package:duruha/features/farmer/shared/presentation/navigation.dart';
import 'package:duruha/features/farmer/shared/presentation/farmer_loading_screen.dart';
import 'package:flutter/material.dart';

enum SortOption { rankAsc, rankDesc, nameAsc, nameDesc }

class FarmerCropsScreen extends StatefulWidget {
  const FarmerCropsScreen({super.key});

  @override
  State<FarmerCropsScreen> createState() => _FarmerCropsScreenState();
}

class _FarmerCropsScreenState extends State<FarmerCropsScreen> {
  final _repository = SelectedCropsRepository();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _isSearchVisible = false;
  // Removed unused _layerLink

  List<SelectedCropSummary> _allCrops = [];
  List<SelectedCropSummary> _filteredCrops = [];
  bool _isLoading = true;
  String? _errorMessage;
  SortOption _sortOption = SortOption.rankAsc;

  @override
  void initState() {
    super.initState();
    _fetchCrops();
  }

  Future<void> _fetchCrops() async {
    try {
      final crops = await _repository.fetchSelectedCrops();
      if (mounted) {
        setState(() {
          _allCrops = crops;
          _filteredCrops = crops;
          if (_searchController.text.isNotEmpty) {
            _filterCrops(_searchController.text);
          } else {
            _sortCrops();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _sortCrops() {
    _filteredCrops.sort((a, b) {
      switch (_sortOption) {
        case SortOption.rankAsc:
          return a.rank.compareTo(b.rank);
        case SortOption.rankDesc:
          return b.rank.compareTo(a.rank);
        case SortOption.nameAsc:
          return a.nameDialect.compareTo(b.nameDialect);
        case SortOption.nameDesc:
          return b.nameDialect.compareTo(a.nameDialect);
      }
    });
  }

  void _filterCrops(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCrops = List.from(_allCrops);
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredCrops = _allCrops.where((crop) {
          return crop.nameDialect.toLowerCase().contains(lowerQuery) ||
              crop.nameDialect.toLowerCase().contains(lowerQuery);
        }).toList();
      }
      _sortCrops(); // Re-sort after filtering
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (_isSearchVisible) {
        _searchFocusNode.requestFocus();
      } else {
        _searchFocusNode.unfocus();
      }
    });
  }

  void _removeSearch() {
    if (_isSearchVisible) {
      setState(() {
        _isSearchVisible = false;
        _searchFocusNode.unfocus();
      });
    }
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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Pledged Crops'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _toggleSearch,
            icon: const Icon(Icons.search),
            tooltip: "Search and Sort",
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: const FarmerNavigation(
        name: displayName,
        currentRoute: '/farmer/crops',
      ),
      body: _isLoading
          ? const FarmerLoadingScreen()
          : _errorMessage != null
          ? Center(
              child: Text(
                'Error: $_errorMessage',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            )
          : Stack(
              children: [
                Column(
                  children: [
                    // --- CROPS LIST ---
                    Expanded(
                      child: _filteredCrops.isEmpty
                          ? Center(
                              child: Text(
                                'No crops match your search.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(20),
                              itemCount: _filteredCrops.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (context, index) {
                                final crop = _filteredCrops[index];
                                return _buildCropCard(context, crop);
                              },
                            ),
                    ),
                  ],
                ),
                if (_isSearchVisible) ...[
                  // Barrier
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _removeSearch,
                      behavior: HitTestBehavior.opaque,
                      child: Container(color: Colors.transparent),
                    ),
                  ),
                  // Search Popup
                  Positioned(
                    top: 1 / 2,
                    left: 16,
                    right: 16,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(16),
                      color: theme.colorScheme.surface,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(
                              alpha: 0.1,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            DuruhaTextField(
                              label: "Search your crops",
                              icon: Icons.search,
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              onChanged: _filterCrops,
                              isRequired: false,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              child: DuruhaPopupMenu<SortOption>(
                                tooltip: 'Sort by',
                                items: SortOption.values,
                                selectedValue: _sortOption,
                                onSelected: (SortOption result) {
                                  setState(() {
                                    _sortOption = result;
                                    _filterCrops(_searchController.text);
                                  });
                                  // Keep visible
                                },
                                labelBuilder: (SortOption option) {
                                  switch (option) {
                                    case SortOption.rankAsc:
                                      return 'Rank (0-9)';
                                    case SortOption.rankDesc:
                                      return 'Rank (9-0)';
                                    case SortOption.nameAsc:
                                      return 'Name (A-Z)';
                                    case SortOption.nameDesc:
                                      return 'Name (Z-A)';
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildCropCard(BuildContext context, SelectedCropSummary crop) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent, // Background handled by Material
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
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
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        child: DuruhaInkwell(
          onTap: () {
            //print('Tapped crop: ${crop.id}');
            Navigator.pushNamed(context, '/farmer/crops/${crop.id}');
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
                    '#${crop.rank}',
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
                      const SizedBox(height: 8),
                      _buildTag(
                        context,
                        crop.pledgeCountLabel,
                        Icons
                            .verified_outlined, // Icon representing pledge count/order
                      ),
                    ],
                  ),
                ),

                // Arrow
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTag(BuildContext context, String text, IconData icon) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
