import 'package:duruha/core/widgets/duruha_scaffold.dart';
import 'package:duruha/features/farmer/features/main/data/find_orders_repository.dart';
import 'package:duruha/features/farmer/features/main/domain/find_orders_model.dart';
import 'package:duruha/features/farmer/features/main/presentation/widgets/order_board_card.dart';
import 'package:duruha/features/farmer/shared/presentation/farmer_loading_screen.dart';
import 'package:duruha/features/farmer/shared/presentation/widgets/navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FarmerMainScreen extends StatefulWidget {
  const FarmerMainScreen({super.key});

  @override
  State<FarmerMainScreen> createState() => _FarmerMainScreenState();
}

class _FarmerMainScreenState extends State<FarmerMainScreen> {
  final _findOrdersRepo = FindOrdersRepository();

  FindOrdersResult? _nearMeResult;
  FindOrdersResult? _discoverResult;

  bool _isLoading = true;
  String? _ordersError;

  int _orderTab = 0;

  String? _openCopId;
  List<FindOrderItem> get _allOrders {
    final result = _orderTab == 0 ? _nearMeResult : _discoverResult;
    return result?.orders ?? [];
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<T?> _tryLoad<T>(Future<T> future, {String? tag}) async {
    try {
      return await future;
    } catch (e) {
      debugPrint('[${tag ?? 'load'}] error: $e');
      return null;
    }
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      _tryLoad(_findOrdersRepo.findOrders(mode: 'near_me'), tag: 'near_me'),
      _tryLoad(_findOrdersRepo.findOrders(mode: 'discover'), tag: 'discover'),
    ]);

    if (!mounted) return;

    final near = results[0];
    final discover = results[1];

    setState(() {
      _nearMeResult = near;
      _discoverResult = discover;
      _ordersError = (near == null && discover == null)
          ? 'Could not load orders. Check your connection and try again.'
          : null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DuruhaScaffold(
      appBarTitle: 'Farm',
      bottomNavigationBar: FarmerNavigation(
        name: 'Elly Farmer',
        currentRoute: '/farmer/main',
      ),
      body: _isLoading
          ? const FarmerLoadingScreen()
          : RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _isLoading = true;
                  _ordersError = null;
                  _openCopId = null;
                });
                await _loadData();
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildRecommendationsSection()),
                  _buildOrderBoardHeaderSliver(),
                  ..._buildOrderBoardSlivers(),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
    );
  }

  Widget _buildRecommendationsSection() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            'Recommended for You',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOrderBoardHeaderSliver() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Open Orders',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Consumers looking for produce you can supply',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _buildTabPillsSliver(cs, theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTabPillsSliver(ColorScheme cs, ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _TabPillSliver(
            label: 'Near Me',
            icon: Icons.near_me_rounded,
            isSelected: _orderTab == 0,
            count: _nearMeResult?.pagination.totalCount,
            cs: cs,
            theme: theme,
            onTap: () => setState(() {
              _orderTab = 0;
              _openCopId = null; // Reset open card when switching tabs
            }),
          ),
          const SizedBox(width: 4),
          _TabPillSliver(
            label: 'Discover',
            icon: Icons.explore_rounded,
            isSelected: _orderTab == 1,
            count: _discoverResult?.pagination.totalCount,
            cs: cs,
            theme: theme,
            onTap: () => setState(() {
              _orderTab = 1;
              _openCopId = null; // Reset open card when switching tabs
            }),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOrderBoardSlivers() {
    if (_ordersError != null) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Colors.red[300],
                ),
                const SizedBox(height: 12),
                Text(
                  'Failed to load orders',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(_ordersError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: _loadData,
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    if (_allOrders.isEmpty) {
      return [
        SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState()),
      ];
    }

    return _allOrders.map((order) {
      final isOpen = _openCopId == order.copId;
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        sliver: OrderBoardCard(
          order: order,
          isOpen: isOpen,
          onToggle: () {
            setState(() {
              if (_openCopId == order.copId) {
                _openCopId = null;
              } else {
                _openCopId = order.copId;
              }
            });
          },
        ),
      );
    }).toList();
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isNear = _orderTab == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isNear ? Icons.location_off_rounded : Icons.explore_off_rounded,
            size: 40,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            isNear ? 'No open orders nearby' : 'Nothing to discover yet',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isNear
                ? 'Try switching to Discover to see orders from other areas.'
                : 'All open orders are already in your nearby area.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab pill widget
// ─────────────────────────────────────────────────────────────────────────────

class _TabPillSliver extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final int? count;
  final ColorScheme cs;
  final ThemeData theme;
  final VoidCallback onTap;

  const _TabPillSliver({
    required this.label,
    required this.icon,
    required this.isSelected,
    this.count,
    required this.cs,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: isSelected ? cs.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isSelected ? cs.primary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isSelected ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
                if (count != null && count! > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? cs.primaryContainer
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isSelected
                            ? cs.onPrimaryContainer
                            : cs.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
