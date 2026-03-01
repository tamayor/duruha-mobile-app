import 'package:flutter/material.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import '../domain/order_details_model.dart';
import 'widgets/order_card.dart';

class ConsumerOrdersScreen extends StatefulWidget {
  final List<ConsumerOrderMatch> activeMatches;
  final List<ConsumerOrderMatch> historyMatches;
  final VoidCallback onLoadMoreActive;
  final VoidCallback onLoadMoreHistory;
  final bool hasMoreActive;
  final bool hasMoreHistory;
  final bool isFetchingMoreActive;
  final bool isFetchingMoreHistory;

  const ConsumerOrdersScreen({
    super.key,
    required this.activeMatches,
    required this.historyMatches,
    required this.onLoadMoreActive,
    required this.onLoadMoreHistory,
    required this.hasMoreActive,
    required this.hasMoreHistory,
    required this.isFetchingMoreActive,
    required this.isFetchingMoreHistory,
  });

  @override
  State<ConsumerOrdersScreen> createState() => _ConsumerOrdersScreenState();
}

class _ConsumerOrdersScreenState extends State<ConsumerOrdersScreen> {
  late ScrollController _activeScrollController;
  late ScrollController _historyScrollController;

  @override
  void initState() {
    super.initState();
    _activeScrollController = ScrollController()..addListener(_onActiveScroll);
    _historyScrollController = ScrollController()
      ..addListener(_onHistoryScroll);
  }

  @override
  void dispose() {
    _activeScrollController.dispose();
    _historyScrollController.dispose();
    super.dispose();
  }

  void _onActiveScroll() {
    if (!_activeScrollController.hasClients) return;
    final pos = _activeScrollController.position.pixels;
    final max = _activeScrollController.position.maxScrollExtent;
    if (pos >= max * 0.8 && max > 0) {
      widget.onLoadMoreActive();
    }
  }

  void _onHistoryScroll() {
    if (!_historyScrollController.hasClients) return;
    final pos = _historyScrollController.position.pixels;
    final max = _historyScrollController.position.maxScrollExtent;
    if (pos >= max * 0.8 && max > 0) {
      widget.onLoadMoreHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: DuruhaScrollHideWrapper(
        bar: const DuruhaTabBar(
          tabs: [
            Tab(text: "Active Orders"),
            Tab(text: "Order History"),
          ],
        ),
        body: TabBarView(
          children: [
            // Active Orders Tab
            _buildMatchList(
              widget.activeMatches,
              theme,
              "No active orders found.",
              _activeScrollController,
              widget.hasMoreActive,
              widget.isFetchingMoreActive,
            ),

            // Order History Tab
            _buildMatchList(
              widget.historyMatches,
              theme,
              "No order history found.",
              _historyScrollController,
              widget.hasMoreHistory,
              widget.isFetchingMoreHistory,
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
    if (matchList.isEmpty && !isFetchingMore) {
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
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: isFetchingMore
                  ? const CircularProgressIndicator()
                  : const SizedBox.shrink(),
            ),
          );
        }
      },
    );
  }
}
