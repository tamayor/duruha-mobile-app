import 'package:flutter/material.dart';
import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/consumer/features/manage/data/orders_repository.dart';
import '../domain/order_details_model.dart';
import 'package:duruha/features/consumer/shared/presentation/consumer_loading_screen.dart';
import 'package:duruha/features/consumer/shared/presentation/navigation.dart';
import 'widgets/order_card.dart';

class ConsumerManageScreen extends StatefulWidget {
  const ConsumerManageScreen({super.key});

  @override
  State<ConsumerManageScreen> createState() => _ConsumerManageScreenState();
}

class _ConsumerManageScreenState extends State<ConsumerManageScreen>
    with SingleTickerProviderStateMixin {
  final _ordersRepository = OrdersRepository();

  // Filter states
  bool?
  _isPlanMode; // null = both orders and plans, true = plans only, false = orders only
  bool?
  _hasPaymentMethodFilter; // null = all, false = no payment method, true = has payment method

  // Total counts (always show full counts regardless of filters)
  int _totalUnpaidCount = 0;

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
      if (_tabController.index == 0) {
        // Active tab - reset to show all orders and plans
        setState(() {
          _isPlanMode = null; // Show both orders and plans
          _hasPaymentMethodFilter = null;
          _activeMatches = [];
          _activeCursor = null;
          _hasMoreActive = false;
          _historyMatches = [];
          _historyCursor = null;
          _hasMoreHistory = false;
        });
        _fetchData(isActive: true);
      } else if (_tabController.index == 1 &&
          _historyMatches.isEmpty &&
          !_isLoadingHistory) {
        _fetchData(isActive: false);
      }
    }
  }

  void _togglePaymentMethodFilter() {
    setState(() {
      if (_hasPaymentMethodFilter == null || _hasPaymentMethodFilter == true) {
        _hasPaymentMethodFilter = false; // Show unpaid only
      } else {
        _hasPaymentMethodFilter = true; // Show paid only
      }
      // Clear data when filter changes
      _activeMatches = [];
      _activeCursor = null;
      _hasMoreActive = false;
      _historyMatches = [];
      _historyCursor = null;
      _hasMoreHistory = false;
      _fetchData(isActive: _tabController.index == 0);
    });
  }

  @override
  void didUpdateWidget(ConsumerManageScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // This method is kept for future use if needed
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
        isPlan: _getIsPlanParam(),
        isOrder: _getIsOrderParam(),
        hasPaymentMethod: _hasPaymentMethodFilter,
      );

      if (mounted) {
        setState(() {
          if (isActive) {
            _activeMatches = response.orders;
            _activeCursor = response.nextCursor;
            _hasMoreActive = response.pagination?.hasMore ?? false;
            _isLoadingActive = false;
            // Update total unpaid count when fetching unfiltered active data
            if (_isPlanMode == null && _hasPaymentMethodFilter == null) {
              _totalUnpaidCount = response.orders
                  .where(
                    (order) =>
                        order.paymentMethod.isEmpty ||
                        order.paymentMethod == 'Not Paid',
                  )
                  .length;
            }
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
        isPlan: _getIsPlanParam(),
        isOrder: _getIsOrderParam(),
        hasPaymentMethod: _hasPaymentMethodFilter,
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

  bool? _getIsPlanParam() {
    if (_isPlanMode == null) {
      // Show both orders and plans
      return true;
    }
    // Filter based on _isPlanMode
    return _isPlanMode;
  }

  bool? _getIsOrderParam() {
    if (_isPlanMode == null) {
      // Show both orders and plans
      return true;
    }
    // Filter based on _isPlanMode (inverse for orders)
    return !_isPlanMode!;
  }

  String _getAppBarTitle() {
    if (_isPlanMode == null) {
      return 'My Orders & Plans';
    }
    return _isPlanMode! ? 'My Plans' : 'My Orders';
  }

  String _getModeTooltip() {
    if (_isPlanMode == null) {
      return 'Show Orders Only';
    } else if (_isPlanMode == false) {
      return 'Show Plans Only';
    } else {
      return 'Show All Orders & Plans';
    }
  }

  IconData _getModeIcon() {
    if (_isPlanMode == null) {
      return Icons.all_inclusive; // Show all
    } else if (_isPlanMode == false) {
      return Icons.shopping_bag_rounded; // Orders only
    } else {
      return Icons.calendar_today_rounded; // Plans only
    }
  }

  IconData _getCartIcon() {
    if (_hasPaymentMethodFilter == null) {
      return Icons.shopping_cart_outlined;
    } else if (_hasPaymentMethodFilter == false) {
      return Icons.shopping_cart; // Filled cart for unpaid filter
    } else {
      return Icons.credit_card; // Credit card for paid filter
    }
  }

  int _getUnpaidOrderCount() {
    return _totalUnpaidCount;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unpaidCount = _getUnpaidOrderCount();

    return DuruhaScaffold(
      appBarTitle: _getAppBarTitle(),
      showBackButton: false,
      appBarActions: [
        Padding(
          padding: const EdgeInsets.all(2),
          child: Tooltip(
            message: _getModeTooltip(),
            child: IconButton(
              icon: Icon(_getModeIcon()),
              onPressed: () {
                setState(() {
                  if (_isPlanMode == null) {
                    _isPlanMode = false; // First click: show orders only
                  } else if (_isPlanMode == false) {
                    _isPlanMode = true; // Second click: show plans only
                  } else {
                    _isPlanMode = null; // Third click: show both
                  }
                  // Clear data when mode changes
                  _activeMatches = [];
                  _activeCursor = null;
                  _hasMoreActive = false;
                  _historyMatches = [];
                  _historyCursor = null;
                  _hasMoreHistory = false;
                  _fetchData(isActive: _tabController.index == 0);
                });
              },
            ),
          ),
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(_getCartIcon()),
              onPressed: _togglePaymentMethodFilter,
            ),
            if (unpaidCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error,
                    shape: BoxShape.circle,
                  ),
                  constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    unpaidCount.toString(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onError,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 16),
      ],
      bottomNavigationBar: const ConsumerNavigation(
        currentRoute: '/consumer/manage',
      ),
      body: DuruhaScrollHideWrapper(
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
