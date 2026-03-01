import 'package:flutter/material.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/farmer/features/manage/offers/data/manage_offer_repository.dart';
import 'package:duruha/features/farmer/features/manage/offers/domain/offer_model.dart';
import 'package:duruha/features/farmer/features/manage/offers/presentation/widgets/offer_card.dart';
import 'package:duruha/features/farmer/shared/presentation/farmer_loading_screen.dart';

/// Shell widget: provides the DefaultTabController then delegates to the
/// inner content widget whose context is *inside* the controller.
class ManageOfferScreen extends StatelessWidget {
  const ManageOfferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(length: 2, child: _ManageOfferContent());
  }
}

/// Inner widget — its context is a descendant of DefaultTabController,
/// so DefaultTabController.of(context) works correctly.
class _ManageOfferContent extends StatefulWidget {
  const _ManageOfferContent();

  @override
  State<_ManageOfferContent> createState() => _ManageOfferContentState();
}

class _ManageOfferContentState extends State<_ManageOfferContent> {
  final _repo = ManageOfferRepository();

  // Per-tab state (index 0 = active, 1 = history)
  final _groups = [<DailyOfferGroup>[], <DailyOfferGroup>[]];
  final _loading = [true, true];
  final _loadingMore = [false, false];
  final _hasMore = [false, false];
  final _cursors = <String?>[null, null];
  final _scrollControllers = [ScrollController(), ScrollController()];

  bool _isAllCollapsed = true;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 2; i++) {
      _scrollControllers[i].addListener(() => _onScroll(i));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // DefaultTabController is a parent of this widget, so .of() works here.
    final ctrl = DefaultTabController.of(context);
    if (ctrl != _tabController) {
      _tabController?.removeListener(_onTabChanged);
      _tabController = ctrl;
      _tabController?.addListener(_onTabChanged);
      // Eagerly load active tab on first attach
      if (_loading[0] && _groups[0].isEmpty) _load(0);
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    for (final c in _scrollControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTabChanged() {
    final ctrl = _tabController;
    if (ctrl == null || ctrl.indexIsChanging) return;
    final idx = ctrl.index;
    // Lazy-load history tab the first time it's tapped
    if (_loading[idx] && _groups[idx].isEmpty) _load(idx);
  }

  Future<void> _load(int tabIdx) async {
    setState(() => _loading[tabIdx] = true);
    final result = await _repo.fetchOffers(active: tabIdx == 0);
    if (!mounted) return;
    setState(() {
      _groups[tabIdx] = result.groups;
      _hasMore[tabIdx] = result.hasMore;
      _cursors[tabIdx] = result.groups.isNotEmpty
          ? result.groups.last.dateCreated.toIso8601String()
          : null;
      _loading[tabIdx] = false;
    });
  }

  Future<void> _loadMore(int tabIdx) async {
    if (_loadingMore[tabIdx] || !_hasMore[tabIdx]) return;
    setState(() => _loadingMore[tabIdx] = true);

    final result = await _repo.fetchOffers(
      active: tabIdx == 0,
      cursor: _cursors[tabIdx],
    );

    if (!mounted) return;
    setState(() {
      final existingDays = _groups[tabIdx]
          .map((g) => g.dateCreated.toIso8601String())
          .toSet();
      for (final g in result.groups) {
        if (!existingDays.contains(g.dateCreated.toIso8601String())) {
          _groups[tabIdx].add(g);
        }
      }
      _hasMore[tabIdx] = result.hasMore;
      _cursors[tabIdx] = result.groups.isNotEmpty
          ? result.groups.last.dateCreated.toIso8601String()
          : _cursors[tabIdx];
      _loadingMore[tabIdx] = false;
    });
  }

  void _onScroll(int tabIdx) {
    final ctrl = _scrollControllers[tabIdx];
    if (ctrl.hasClients &&
        ctrl.position.pixels >= ctrl.position.maxScrollExtent - 200) {
      _loadMore(tabIdx);
    }
  }

  Future<void> _refresh(int tabIdx) async {
    setState(() {
      _cursors[tabIdx] = null;
      _hasMore[tabIdx] = false;
      _groups[tabIdx].clear();
    });
    await _load(tabIdx);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DuruhaScrollHideWrapper(
      bar: DuruhaTabBar(
        tabs: const [
          Tab(text: 'Active Offers'),
          Tab(text: 'Offer History'),
        ],
        trailing: IconButton(
          icon: Icon(
            _isAllCollapsed
                ? Icons.unfold_more_rounded
                : Icons.unfold_less_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          tooltip: _isAllCollapsed ? 'Expand All' : 'Collapse All',
          onPressed: () => setState(() => _isAllCollapsed = !_isAllCollapsed),
        ),
      ),
      body: TabBarView(children: [_buildTab(0, theme), _buildTab(1, theme)]),
    );
  }

  Widget _buildTab(int tabIdx, ThemeData theme) {
    if (_loading[tabIdx]) {
      return const FarmerLoadingScreen();
    }

    final groups = _groups[tabIdx];
    if (groups.isEmpty) {
      return _buildEmptyState(
        theme,
        tabIdx == 0 ? Icons.local_offer_outlined : Icons.history,
        tabIdx == 0 ? 'No active offers.' : 'No offer history.',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _refresh(tabIdx),
      child: CustomScrollView(
        controller: _scrollControllers[tabIdx],
        slivers: [
          for (final daily in groups)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              sliver: _buildDateSection(daily, tabIdx == 0, theme, tabIdx),
            ),

          if (_loadingMore[tabIdx])
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),

          if (!_hasMore[tabIdx] && groups.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'All offers loaded',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }

  Widget _buildDateSection(
    DailyOfferGroup daily,
    bool isActive,
    ThemeData theme,
    int tabIdx,
  ) {
    final dateStr = DuruhaFormatter.formatDate(daily.dateCreated);
    int totalOffers = 0;
    for (final p in daily.produces) {
      totalOffers += p.varieties.length;
    }

    int offerIdx = 0;

    return DuruhaSliverSectionContainer(
      title: 'Offers on $dateStr',
      subtitle: '$totalOffers offer${totalOffers == 1 ? '' : 's'}',
      isShrinkable: true,
      initialShrunk: true,
      shrinkOverride: _isAllCollapsed,
      children: [
        for (final produce in daily.produces) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Align(
              alignment: Alignment.center,
              child: Text(
                produce.produceLocalName.isNotEmpty
                    ? produce.produceLocalName
                    : produce.produceEnglishName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          ...produce.varieties.map((offer) {
            final currentIdx = offerIdx++;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OfferCard(
                offer: offer,
                produce: produce,
                isActive: isActive,
                index: currentIdx,
                onRefresh: () => _refresh(tabIdx),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme, IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: theme.colorScheme.outline.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
