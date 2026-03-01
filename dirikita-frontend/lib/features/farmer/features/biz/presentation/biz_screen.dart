import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/features/farmer/features/biz/data/biz_repository.dart';
import 'package:duruha/features/farmer/features/sales/data/farmer_produce_repository.dart';
import 'package:duruha/features/farmer/features/sales/domain/farmer_selected_produce.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:duruha/features/farmer/shared/presentation/farmer_loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/farmer/shared/presentation/widgets/navigation.dart';

import 'widgets/biz_date_range_picker.dart';
import 'widgets/biz_earnings_section.dart';
import 'widgets/biz_revenue_card.dart';
import 'widgets/selected_crop_card.dart';

enum SortOption { rankAsc, rankDesc, nameAsc, nameDesc }

class FarmerBizScreen extends StatefulWidget {
  final int initialTabIndex;

  const FarmerBizScreen({super.key, this.initialTabIndex = 0});

  @override
  State<FarmerBizScreen> createState() => _FarmerBizScreenState();
}

class _FarmerBizScreenState extends State<FarmerBizScreen> {
  // Repositories
  final _bizRepository = BizRepository();
  final _cropsRepository = FarmerProduceRepository();

  // State
  bool _isLoading = true;
  bool _showCrops = false;

  // -- BIZ HUB STATE --
  List<HarvestPledge> _allPledges = [];
  bool _isFilterVisible = false;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 365));
  DateTime _endDate = DateTime.now();

  // -- CROPS STATE --
  List<FarmerSelectedProduce> _allCrops = [];
  List<FarmerSelectedProduce> _filteredCrops = [];
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _isSearchVisible = false;
  SortOption _sortOption = SortOption.rankAsc;

  @override
  void initState() {
    super.initState();
    _showCrops = widget.initialTabIndex == 1;
    _fetchAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchAllData() async {
    setState(() => _isLoading = true);
    try {
      final userId = await SessionService.getUserId() ?? '';
      final pledgesFuture = _bizRepository.fetchSalesRecords();
      final cropsFuture = _cropsRepository.fetchFarmerProduce(userId);

      final results = await Future.wait([pledgesFuture, cropsFuture]);
      final pledges = results[0] as List<HarvestPledge>;
      final cropsResult = results[1] as ProducePaginatedResult;
      final crops = cropsResult.data;

      if (mounted) {
        setState(() {
          _allPledges = pledges;
          _allCrops = crops;
          _filteredCrops = crops;
          _sortCrops(); // Initial sort
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- VIEW TOGGLE Logic ---

  void _toggleView() {
    setState(() {
      _showCrops = !_showCrops;
      // Reset search/filter when switching views
      if (_isSearchVisible) _removeSearch();
      if (_isFilterVisible) _hideFilter();
    });
  }

  // --- BIZ HUB Logic ---

  void _toggleFilter() {
    setState(() {
      _isFilterVisible = !_isFilterVisible;
    });
  }

  void _hideFilter() {
    if (_isFilterVisible) {
      setState(() {
        _isFilterVisible = false;
      });
    }
  }

  List<HarvestPledge> get _filteredSoldPledges {
    return _allPledges.where((p) {
      final isSold = p.currentStatus == 'Sold';
      final isWithinRange =
          p.harvestDate.isAfter(_startDate) &&
          p.harvestDate.isBefore(_endDate.add(const Duration(days: 1)));
      return isSold && isWithinRange;
    }).toList();
  }

  Map<String, List<HarvestPledge>> get _groupedByCrop {
    final Map<String, List<HarvestPledge>> grouped = {};
    for (var p in _filteredSoldPledges) {
      final key = p.cropNameDialect ?? p.cropName;
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(p);
    }
    return grouped;
  }

  double get _totalRevenue {
    return _filteredSoldPledges.fold(
      0,
      (sum, p) => sum + (p.quantity * (p.sellingPrice ?? 0)),
    );
  }

  Future<void> _selectDate(bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  // --- CROPS LIST Logic ---

  void _sortCrops() {
    _filteredCrops.sort((a, b) {
      switch (_sortOption) {
        case SortOption.rankAsc:
          return (a.rank ?? 99).compareTo(b.rank ?? 99);
        case SortOption.rankDesc:
          return (b.rank ?? 0).compareTo(a.rank ?? 0);
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
        _searchController.clear();
        _filterCrops('');
        _searchFocusNode.unfocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DuruhaScaffold(
      // Dynamic App Bar Title
      appBarTitleWidget: _showCrops && _isSearchVisible
          ? TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: theme.textTheme.titleMedium,
              decoration: InputDecoration(
                hintText: 'Search crops...',
                border: InputBorder.none,
                hintStyle: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              onChanged: _filterCrops,
            )
          : Text(
              _showCrops ? "My Crops" : "Business Hub",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),

      // Dynamic App Bar Actions
      appBarActions: [
        if (!_showCrops) ...[
          // BIZ HUB ACTIONS
          IconButton(
            onPressed: _toggleFilter,
            icon: Icon(
              Icons.calendar_today_rounded,
              color: _isFilterVisible ? theme.colorScheme.onSecondary : null,
            ),
            tooltip: "Filter Date Range",
          ),
        ] else ...[
          // MY CROPS ACTIONS
          if (_isSearchVisible)
            IconButton(
              onPressed: _removeSearch,
              icon: const Icon(Icons.close),
              tooltip: "Close Search",
            )
          else
            IconButton(
              onPressed: _toggleSearch,
              icon: const Icon(Icons.search),
              tooltip: "Search",
            ),

          DuruhaPopupMenu<SortOption>(
            tooltip: 'Sort by',
            items: SortOption.values,
            selectedValue: _sortOption,
            onSelected: (SortOption result) {
              setState(() {
                _sortOption = result;
                _filterCrops(_searchController.text);
              });
            },
            icon: const Icon(Icons.sort),
            labelBuilder: (SortOption option) {
              switch (option) {
                case SortOption.rankAsc:
                  return '0-9';
                case SortOption.rankDesc:
                  return '9-0';
                case SortOption.nameAsc:
                  return 'A-Z';
                case SortOption.nameDesc:
                  return 'Z-A';
              }
            },
          ),
        ],

        const SizedBox(width: 8),

        // --- TOGGLE VIEW ICON ---
        // Far right icon to switch views
        IconButton.filled(
          onPressed: _toggleView,
          tooltip: _showCrops ? "Switch to Biz Hub" : "Switch to My Crops",
          icon: Icon(
            _showCrops ? Icons.bar_chart_rounded : Icons.grass_rounded,
          ),
          style: IconButton.styleFrom(
            backgroundColor: theme.colorScheme.onPrimary.withValues(alpha: .5),
            foregroundColor: theme.colorScheme.primary,
            side: BorderSide(color: theme.colorScheme.primary),
            shape: const CircleBorder(),
          ),
        ),
        const SizedBox(width: 16),
      ],

      bottomNavigationBar: FarmerNavigation(
        name: "Elly",
        currentRoute: '/farmer/biz',
      ),
      body: _isLoading
          ? const FarmerLoadingScreen()
          : _showCrops
          ? _buildMyCropsTab(context)
          : _buildBizHubTab(context),
    );
  }

  // --- TAB 1: BIZ HUB CONTENT ---
  Widget _buildBizHubTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _fetchAllData,
          edgeOffset: MediaQuery.of(context).padding.top + kToolbarHeight,
          child: SingleChildScrollView(
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Revenue Summary Header
                      BizRevenueCard(
                        totalRevenue: _totalRevenue,
                        salesCount: _filteredSoldPledges.length,
                        cropsSoldCount: _groupedByCrop.length,
                      ),

                      const SizedBox(height: 32),

                      Text(
                        "Earnings by Crop",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 16),

                      BizEarningsSection(groupedByCrop: _groupedByCrop),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isFilterVisible) ...[
          // Barrier
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideFilter,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          // Popup
          Positioned(
            top: 10,
            left: 16,
            right: 16,
            child: BizDateRangePicker(
              startDate: _startDate,
              endDate: _endDate,
              onStartDateTap: () => _selectDate(true),
              onEndDateTap: () => _selectDate(false),
            ),
          ),
        ],
      ],
    );
  }

  // --- TAB 2: MY CROPS CONTENT ---
  Widget _buildMyCropsTab(BuildContext context) {
    final theme = Theme.of(context);

    // Simple direct list for now
    if (_filteredCrops.isEmpty) {
      return Center(
        child: Text(
          'No crops match your search.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: _filteredCrops.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final crop = _filteredCrops[index];
        return SelectedCropCard(
          crop: crop,
          onTap: () {
            Navigator.pushNamed(
              context,
              '/farmer/biz/crops/',
              arguments: crop.id,
            );
          },
        );
      },
    );
  }

  // --- WIDGET HELPERS ---
}
