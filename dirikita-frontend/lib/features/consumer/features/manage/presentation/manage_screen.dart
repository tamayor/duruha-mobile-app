import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/consumer/features/manage/data/orders_repository.dart';
import 'package:duruha/features/consumer/features/manage/domain/order_details_model.dart';
import 'package:duruha/features/consumer/shared/presentation/navigation.dart';
import 'package:flutter/material.dart';
import 'package:duruha/features/consumer/shared/presentation/consumer_loading_screen.dart';
import 'manage_order_screen.dart';

class ConsumerManageScreen extends StatefulWidget {
  const ConsumerManageScreen({super.key});

  @override
  State<ConsumerManageScreen> createState() => _ConsumerManageScreenState();
}

class _ConsumerManageScreenState extends State<ConsumerManageScreen> {
  final _ordersRepository = OrdersRepository();
  bool _isLoading = true;

  // Order mode is the default. Plan mode is coming soon and cannot be activated.
  bool _isPlanMode = false;

  List<ConsumerOrderMatch> _activeMatches = [];
  String? _activeCursor;
  bool _hasMoreActive = false;
  bool _isFetchingMoreActive = false;

  List<ConsumerOrderMatch> _historyMatches = [];
  String? _historyCursor;
  bool _hasMoreHistory = false;
  bool _isFetchingMoreHistory = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final consumerId = await SessionService.getRoleId();
      if (consumerId == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      // Fetch both active and history orders initially (or could parallelize)
      final activeResponse = await _ordersRepository.fetchOrderMatches(
        isActive: true,
      );
      final historyResponse = await _ordersRepository.fetchOrderMatches(
        isActive: false,
      );

      if (!mounted) return;

      setState(() {
        _activeMatches = activeResponse.orders;
        _activeCursor = activeResponse.nextCursor;
        _hasMoreActive = activeResponse.pagination?.hasMore ?? false;

        _historyMatches = historyResponse.orders;
        _historyCursor = historyResponse.nextCursor;
        _hasMoreHistory = historyResponse.pagination?.hasMore ?? false;

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ [CONSUMER MANAGE FETCH ERROR]: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _fetchMore({required bool isActive}) async {
    final isFetching = isActive
        ? _isFetchingMoreActive
        : _isFetchingMoreHistory;
    final hasMore = isActive ? _hasMoreActive : _hasMoreHistory;
    final cursor = isActive ? _activeCursor : _historyCursor;

    if (isFetching || !hasMore || cursor == null) return;

    setState(() {
      if (isActive) {
        _isFetchingMoreActive = true;
      } else {
        _isFetchingMoreHistory = true;
      }
    });

    try {
      final response = await _ordersRepository.fetchOrderMatches(
        isActive: isActive,
        cursor: cursor,
      );

      if (!mounted) return;

      setState(() {
        if (isActive) {
          _activeMatches.addAll(response.orders);
          _activeCursor = response.nextCursor;
          _hasMoreActive = response.pagination?.hasMore ?? false;
          _isFetchingMoreActive = false;
        } else {
          _historyMatches.addAll(response.orders);
          _historyCursor = response.nextCursor;
          _hasMoreHistory = response.pagination?.hasMore ?? false;
          _isFetchingMoreHistory = false;
        }
      });
    } catch (e) {
      debugPrint('❌ [CONSUMER MANAGE FETCH MORE ERROR]: $e');
      if (mounted) {
        setState(() {
          if (isActive) {
            _isFetchingMoreActive = false;
          } else {
            _isFetchingMoreHistory = false;
          }
        });
      }
    }
  }

  void _toggleMode(bool isPlan) {
    // Plan mode is coming soon — tapping Plan shows the placeholder only.
    setState(() => _isPlanMode = isPlan);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DuruhaScaffold(
      appBarTitle: _isPlanMode ? 'My Plans' : 'My Orders',
      showBackButton: false,
      appBarActions: [
        Padding(
          padding: const EdgeInsets.all(2),
          child: Tooltip(
            message: _isPlanMode ? 'Coming soon' : 'Plan mode — coming soon',
            child: DuruhaToggleButton(
              value: _isPlanMode,
              onChanged: _toggleMode,
              iconTrue: Icons.calendar_today_rounded,
              iconFalse: Icons.shopping_bag_rounded,
            ),
          ),
        ),
        const SizedBox(width: 16),
      ],
      bottomNavigationBar: const ConsumerNavigation(
        currentRoute: '/consumer/manage',
      ),
      body: _isLoading
          ? const ConsumerLoadingScreen()
          : _isPlanMode
          ? _buildComingSoon(theme, scheme)
          : ConsumerOrdersScreen(
              activeMatches: _activeMatches,
              historyMatches: _historyMatches,
              onLoadMoreActive: () => _fetchMore(isActive: true),
              onLoadMoreHistory: () => _fetchMore(isActive: false),
              hasMoreActive: _hasMoreActive,
              hasMoreHistory: _hasMoreHistory,
              isFetchingMoreActive: _isFetchingMoreActive,
              isFetchingMoreHistory: _isFetchingMoreHistory,
            ),
    );
  }

  Widget _buildComingSoon(ThemeData theme, ColorScheme scheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 72,
              color: scheme.outline,
            ),
            const SizedBox(height: 20),
            Text(
              'Plan Mode — Coming Soon',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'Pre-ordering for future harvest is on the way.\nStay tuned!',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.tonal(
              onPressed: () => setState(() => _isPlanMode = false),
              child: const Text('Back to Orders'),
            ),
          ],
        ),
      ),
    );
  }
}
