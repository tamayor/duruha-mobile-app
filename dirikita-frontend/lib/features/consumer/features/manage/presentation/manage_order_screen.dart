import 'package:flutter/material.dart';
import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/consumer/features/manage/data/orders_repository.dart';
import '../domain/order_details_model.dart';
import 'package:duruha/features/consumer/shared/presentation/consumer_loading_screen.dart';
import 'widgets/order_card.dart';

class ConsumerOrdersScreen extends StatefulWidget {
  final bool isPlanMode;

  const ConsumerOrdersScreen({super.key, this.isPlanMode = false});

  @override
  State<ConsumerOrdersScreen> createState() => _ConsumerOrdersScreenState();
}

class _ConsumerOrdersScreenState extends State<ConsumerOrdersScreen>
    with SingleTickerProviderStateMixin {
  final _ordersRepository = OrdersRepository();

  List<ConsumerOrderMatch> _activeMatches = [];
  String? _activeCursor;
  bool _hasMoreActive = false;
  bool _isFetchingMoreActive = false;
  bool _isLoadingActive = false;

  List<ConsumerOrderMatch> _historyMatches = [];
  String? _historyCursor;
  bool _hasMoreHistory = false;
  bool _isFetchingMoreHistory = false;
  bool _isLoadingHistory = false;

  late ScrollController _activeScrollController;
  late ScrollController _historyScrollController;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _activeScrollController = ScrollController()..addListener(_onActiveScroll);
    _historyScrollController = ScrollController()
      ..addListener(_onHistoryScroll);

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);

    // Initial fetch
    _fetchData(isActive: true);
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      if (_tabController.index == 1 &&
          _historyMatches.isEmpty &&
          !_isLoadingHistory) {
        _fetchData(isActive: false);
      }
    }
  }

  @override
  void didUpdateWidget(ConsumerOrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlanMode != oldWidget.isPlanMode) {
      _activeMatches = [];
      _activeCursor = null;
      _hasMoreActive = false;
      _historyMatches = [];
      _historyCursor = null;
      _hasMoreHistory = false;
      _fetchData(isActive: _tabController.index == 0);
    }
  }

  Future<void> _fetchData({required bool isActive}) async {
    if (!mounted) return;
    setState(() {
      if (isActive) {
        _isLoadingActive = true;
      } else {
        _isLoadingHistory = true;
      }
    });

    try {
      final consumerId = await SessionService.getRoleId();
      if (consumerId == null) return;

      final response = await _ordersRepository.fetchOrderMatches(
        isActive: isActive,
        isPlan: widget.isPlanMode ? true : null,
      );

      if (mounted) {
        setState(() {
          if (isActive) {
            _activeMatches = response.orders;
            _activeCursor = response.nextCursor;
            _hasMoreActive = response.pagination?.hasMore ?? false;
            _isLoadingActive = false;
          } else {
            _historyMatches = response.orders;
            _historyCursor = response.nextCursor;
            _hasMoreHistory = response.pagination?.hasMore ?? false;
            _isLoadingHistory = false;
          }
        });
      }
    } catch (e) {
      debugPrint('❌ [CONSUMER ORDERS FETCH ERROR]: $e');
      if (mounted) {
        setState(() {
          if (isActive) {
            _isLoadingActive = false;
          } else {
            _isLoadingHistory = false;
          }
        });
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
        isPlan: widget.isPlanMode ? true : null,
      );

      if (mounted) {
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
      }
    } catch (e) {
      debugPrint('❌ [CONSUMER ORDERS FETCH MORE ERROR]: $e');
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

  @override
  void dispose() {
    _activeScrollController.dispose();
    _historyScrollController.dispose();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }

  void _onActiveScroll() {
    if (!_activeScrollController.hasClients) return;
    final pos = _activeScrollController.position.pixels;
    final max = _activeScrollController.position.maxScrollExtent;
    if (pos >= max * 0.8 && max > 0) {
      _fetchMore(isActive: true);
    }
  }

  void _onHistoryScroll() {
    if (!_historyScrollController.hasClients) return;
    final pos = _historyScrollController.position.pixels;
    final max = _historyScrollController.position.maxScrollExtent;
    if (pos >= max * 0.8 && max > 0) {
      _fetchMore(isActive: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DuruhaScrollHideWrapper(
      bar: DuruhaTabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: "Active"),
          Tab(text: "History"),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Active Orders Tab
          _buildMatchList(
            _activeMatches,
            theme,
            "No active orders found.",
            _activeScrollController,
            _hasMoreActive,
            _isLoadingActive || _isFetchingMoreActive,
          ),

          // Order History Tab
          _buildMatchList(
            _historyMatches,
            theme,
            "No order history found.",
            _historyScrollController,
            _hasMoreHistory,
            _isLoadingHistory || _isFetchingMoreHistory,
          ),
        ],
      ),
    );
  }

  Widget _buildMatchList(
    List<ConsumerOrderMatch> matchList,
    ThemeData theme,
    String emptyMessage,
    ScrollController controller,
    bool hasMore,
    bool isFetchingMore,
  ) {
    if (matchList.isEmpty && isFetchingMore) {
      return const ConsumerLoadingScreen();
    }

    if (matchList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 48,
              color: theme.colorScheme.outline.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.all(16),
      itemCount: matchList.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < matchList.length) {
          final match = matchList[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OrderCard(match: match),
          );
        } else {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
      },
    );
  }
}
