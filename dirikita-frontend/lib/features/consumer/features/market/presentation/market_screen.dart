import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/consumer/features/market/data/market_repository.dart';
import 'package:duruha/features/consumer/features/market/domain/market_order_model.dart';
import 'package:duruha/features/consumer/features/market/presentation/market_state.dart';
import 'package:duruha/features/consumer/features/market/presentation/widgets/produce_card.dart';
import 'package:duruha/features/consumer/shared/presentation/navigation.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class MarketScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const MarketScreen({super.key, required this.userData});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final MarketRepository _repository = MarketRepository();
  final MarketState _marketState = MarketState();

  List<MarketProduceItem> _produceItems = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProduce();
    _marketState.addListener(_onMarketStateChanged);
  }

  @override
  void dispose() {
    _marketState.removeListener(_onMarketStateChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onMarketStateChanged() {
    setState(() {}); // Rebuild when market state changes
  }

  Future<void> _loadProduce() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final produces = await _repository.getConsumerProduce();
      setState(() {
        _produceItems = produces;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading produce: $e')));
      }
    }
  }

  void _setMarketMode(MarketMode mode) {
    if (_marketState.marketMode == mode) return;
    _marketState.setMarketMode(mode);
  }

  void _navigateToOrder() {
    if (_marketState.hasSelectedItems) {
      Navigator.of(context).pushNamed(
        '/consumer/market/order',
        arguments: {'marketState': _marketState, 'userData': widget.userData},
      );
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _marketState.setSearchQuery('');
      }
    });
  }

  String _getCategoryLabel(String? category) {
    if (category == null) return 'All';
    return category;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userName = widget.userData['name'] ?? 'Consumer';

    final filteredItems = _marketState.filterItems(_produceItems);

    return DuruhaScaffold(
      appBarTitle: _isSearching ? null : 'Market',
      appBarActions: [
        if (_isSearching)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search produce...',
                  border: InputBorder.none,
                  hintStyle: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                  ),
                ),
                onChanged: (value) {
                  _marketState.setSearchQuery(value);
                },
              ),
            ),
          ),
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search),
          onPressed: _toggleSearch,
        ),
        if (!_isSearching)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: DuruhaPopupMenu<String?>(
              items: const [
                null,
                'leafy',
                'fruitVeg',
                'root',
                'spice',
                'fruit',
                'legume',
              ],
              selectedValue: _marketState.selectedCategory,
              onSelected: (category) {
                _marketState.setSelectedCategory(category);
              },
              labelBuilder: _getCategoryLabel,
              itemIcons: const {
                null: Icons.apps,
                'leafy': Icons.eco,
                'fruitVeg': Icons.category,
                'root': Icons.park,
                'spice': Icons.waves,
                'fruit': Icons.breakfast_dining,
                'legume': Icons.grain,
              },
              showLabel: false,
              tooltip: 'Filter by Category',
            ),
          ),
        IconButton(
          icon: Icon(
            _marketState.showFavoritesOnly
                ? Icons.favorite
                : Icons.favorite_border,
            color: _marketState.showFavoritesOnly
                ? const Color(0xFFFF5252)
                : null,
          ),
          onPressed: () {
            _marketState.toggleFavoritesFilter();
          },
        ),
        const SizedBox(width: 8),
      ],
      showBackButton: false,
      isLoading: _isLoading,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadProduce,
            child: filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _marketState.showFavoritesOnly ||
                                  _marketState.searchQuery.isNotEmpty
                              ? Icons.search_off
                              : Icons.inventory_2_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _marketState.showFavoritesOnly &&
                                  filteredItems.isEmpty
                              ? 'No favorites yet'
                              : _marketState.searchQuery.isNotEmpty
                              ? 'No results for "${_marketState.searchQuery}"'
                              : 'No produce available',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (_marketState.showFavoritesOnly ||
                            _marketState.searchQuery.isNotEmpty ||
                            _marketState.selectedCategory != null)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _marketState.setSearchQuery('');
                                _marketState.setSelectedCategory(null);
                                if (_marketState.showFavoritesOnly) {
                                  _marketState.toggleFavoritesFilter();
                                }
                                _searchController.clear();
                                _isSearching = false;
                              });
                            },
                            child: const Text('Clear all filters'),
                          ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 150),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final isSelected = _marketState.isSelected(
                        item.produce.id,
                      );
                      final isFavorite = _marketState.isFavorite(
                        item.produce.id,
                      );

                      final currentQuantity =
                          _marketState
                              .orderItems[item.produce.id]
                              ?.quantityKg ??
                          0.0;

                      return ProduceCard(
                        item: item,
                        isSelected: isSelected,
                        isFavorite: isFavorite,
                        marketMode: _marketState.marketMode,
                        quantity: currentQuantity,
                        onListTap: () {
                          _marketState.toggleSelection(item.produce);
                        },
                        onFavoriteTap: () {
                          _marketState.toggleFavorite(item.produce.id);
                        },
                        onQuantityChanged: (newQuantity) {
                          _marketState.updateQuantity(
                            item.produce.id,
                            newQuantity,
                          );
                        },
                      );
                    },
                  ),
          ),

          // --- MODE TOGGLE (Top Left) ---
          Positioned(
            top: 20,
            left: 20,
            child: DuruhaToggleButton(
              value: _marketState.marketMode == MarketMode.plan,
              onChanged: (isPlan) {
                _setMarketMode(isPlan ? MarketMode.plan : MarketMode.order);
              },
              labelTrue: "Plan Mode",
              labelFalse: "Order Mode",
              iconTrue: Icons.calendar_today_rounded,
              iconFalse: Icons.shopping_bag_rounded,
              colorTrue: theme.colorScheme.secondary,
              colorFalse: theme.colorScheme.primary,
              descriptionTrue: "Browse and pre-order produce before harvest.",
              descriptionFalse:
                  "Buy fresh produce available in the market right now.",
            ),
          ),
        ],
      ),
      floatingActionButton: _marketState.hasSelectedItems
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cart FAB with badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    FloatingActionButton(
                      onPressed: _navigateToOrder,
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                      child: const Icon(Icons.shopping_cart),
                    ),
                    // Badge
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5252),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 24,
                          minHeight: 24,
                        ),
                        child: Center(
                          child: Text(
                            '${_marketState.selectedCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : null,
      bottomNavigationBar: ConsumerNavigation(
        name: userName,
        currentRoute: '/consumer/market',
      ),
    );
  }
}
