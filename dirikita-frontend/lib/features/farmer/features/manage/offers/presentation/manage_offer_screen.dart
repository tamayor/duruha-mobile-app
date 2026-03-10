import 'package:flutter/material.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/farmer/features/manage/offers/data/manage_offer_repository.dart';
import 'package:duruha/features/farmer/features/manage/offers/domain/offer_model.dart';
import 'package:duruha/features/farmer/features/manage/offers/presentation/widgets/offer_card.dart';
import 'package:duruha/features/farmer/shared/presentation/farmer_loading_screen.dart';

class ManageOfferScreen extends StatefulWidget {
  const ManageOfferScreen({super.key});

  @override
  State<ManageOfferScreen> createState() => ManageOfferScreenState();
}

/// Public state — ManageScreen uses a GlobalKey<ManageOfferScreenState>
/// to call [applyFilters] when the user changes search/sort/date.
class ManageOfferScreenState extends State<ManageOfferScreen> {
  final _inner = GlobalKey<_ManageOfferContentState>();

  void applyFilters({
    required String search,
    required OfferSort sort,
    required DateTime? dateFrom,
    required DateTime? dateTo,
  }) {
    _inner.currentState?.applyFilters(
      search: search,
      sort: sort,
      dateFrom: dateFrom,
      dateTo: dateTo,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: _ManageOfferContent(key: _inner),
    );
  }
}

class _ManageOfferContent extends StatefulWidget {
  const _ManageOfferContent({super.key});

  @override
  State<_ManageOfferContent> createState() => _ManageOfferContentState();
}

class _ManageOfferContentState extends State<_ManageOfferContent> {
  final _repo = ManageOfferRepository();
  TabController? _tabController;

  // ── Per-tab state ──────────────────────────────────────────────────────────
  final _offers = [<FlatOffer>[], <FlatOffer>[]];
  final _loading = [true, true];
  final _loadingMore = [false, false];
  final _hasMore = [false, false];
  final _cursorVal = <String?>[null, null];
  final _cursorId = <String?>[null, null];
  final _scrollControllers = [ScrollController(), ScrollController()];

  // ── Filter state (driven by parent via OfferFilterController) ─────────────
  String _searchText = '';
  OfferSort _sort = OfferSort.dateDesc;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  bool get _hasAnyFilter =>
      _searchText.isNotEmpty ||
      _sort != OfferSort.dateDesc ||
      _dateFrom != null ||
      _dateTo != null;

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
    final ctrl = DefaultTabController.of(context);
    if (ctrl != _tabController) {
      _tabController?.removeListener(_onTabChanged);
      _tabController = ctrl;
      _tabController?.addListener(_onTabChanged);
      if (_loading[0] && _offers[0].isEmpty) _load(0);
    }
    // Pick up filter controller from ancestor ManageScreen
    final fc = OfferFilterController.of(context);
    if (fc != null) {
      _searchText = fc.searchText;
      _sort = fc.sort;
      _dateFrom = fc.dateFrom;
      _dateTo = fc.dateTo;
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
    _load(ctrl.index);
  }

  // ── Called by ManageScreen when filters change ─────────────────────────────
  void applyFilters({
    required String search,
    required OfferSort sort,
    required DateTime? dateFrom,
    required DateTime? dateTo,
  }) {
    _searchText = search;
    _sort = sort;
    _dateFrom = dateFrom;
    _dateTo = dateTo;
    _load(0);
    _load(1);
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _load(int tab) async {
    setState(() {
      _loading[tab] = true;
      _offers[tab] = [];
      _cursorVal[tab] = null;
      _cursorId[tab] = null;
    });

    final result = await _repo.fetchOffers(
      active: tab == 0,
      search: _searchText.isEmpty ? null : _searchText,
      sort: _sort,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
    if (!mounted) return;

    setState(() {
      _offers[tab] = result.offers;
      _hasMore[tab] = result.hasMore;
      _setCursor(tab, result.offers);
      _loading[tab] = false;
    });
  }

  Future<void> _loadMore(int tab) async {
    if (_loadingMore[tab] || !_hasMore[tab]) return;
    setState(() => _loadingMore[tab] = true);

    final result = await _repo.fetchOffers(
      active: tab == 0,
      cursorVal: _cursorVal[tab],
      cursorId: _cursorId[tab],
      search: _searchText.isEmpty ? null : _searchText,
      sort: _sort,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
    if (!mounted) return;

    setState(() {
      _offers[tab].addAll(result.offers);
      _hasMore[tab] = result.hasMore;
      _setCursor(tab, result.offers);
      _loadingMore[tab] = false;
    });
  }

  void _setCursor(int tab, List<FlatOffer> newOffers) {
    if (newOffers.isEmpty) return;
    final last = newOffers.last;
    _cursorVal[tab] = _sort.cursorVal(last);
    _cursorId[tab] = last.offer.offerId;
  }

  void _onScroll(int tab) {
    final ctrl = _scrollControllers[tab];
    if (ctrl.hasClients &&
        ctrl.position.pixels >= ctrl.position.maxScrollExtent - 200) {
      _loadMore(tab);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DuruhaScrollHideWrapper(
      bar: DuruhaTabBar(
        tabs: const [Tab(text: 'Active'), Tab(text: 'History')],
      ),
      body: TabBarView(
        children: [_buildTab(0, theme), _buildTab(1, theme)],
      ),
    );
  }

  Widget _buildTab(int tab, ThemeData theme) {
    if (_loading[tab]) return const FarmerLoadingScreen();

    final offers = _offers[tab];
    if (offers.isEmpty) {
      return _buildEmpty(
        theme,
        tab == 0 ? Icons.local_offer_outlined : Icons.history,
        _hasAnyFilter
            ? 'No offers match your filters.'
            : tab == 0
                ? 'No active offers.'
                : 'No offer history.',
      );
    }

    final items = _buildListItems(offers);

    return RefreshIndicator(
      onRefresh: () => _load(tab),
      child: ListView.builder(
        controller: _scrollControllers[tab],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: items.length + 1,
        itemBuilder: (context, idx) {
          if (idx == items.length) {
            if (_loadingMore[tab]) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (!_hasMore[tab]) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'All offers loaded',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          }

          final item = items[idx];

          if (item is _DateHeader) {
            return Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    DuruhaFormatter.formatDate(item.date),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            );
          }

          final flat = (item as _OfferItem).flat;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OfferCard(
              offer: flat.offer,
              produceGroup: flat.produce,
              isActive: tab == 0,
              index: idx,
              onRefresh: () => _load(tab),
            ),
          );
        },
      ),
    );
  }

  List<_ListItem> _buildListItems(List<FlatOffer> offers) {
    final items = <_ListItem>[];
    String? lastDate;
    for (final flat in offers) {
      final dateKey = flat.offer.createdAt.toIso8601String().substring(0, 10);
      if (dateKey != lastDate) {
        items.add(_DateHeader(flat.offer.createdAt));
        lastDate = dateKey;
      }
      items.add(_OfferItem(flat));
    }
    return items;
  }

  Widget _buildEmpty(ThemeData theme, IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.outline.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ── Filter controller passed via InheritedWidget ───────────────────────────────

class OfferFilterController extends InheritedWidget {
  final String searchText;
  final OfferSort sort;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  const OfferFilterController({
    super.key,
    required this.searchText,
    required this.sort,
    this.dateFrom,
    this.dateTo,
    required super.child,
  });

  static OfferFilterController? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OfferFilterController>();

  @override
  bool updateShouldNotify(OfferFilterController old) =>
      searchText != old.searchText ||
      sort != old.sort ||
      dateFrom != old.dateFrom ||
      dateTo != old.dateTo;
}

// ── List item types ────────────────────────────────────────────────────────────

sealed class _ListItem {}

class _DateHeader extends _ListItem {
  final DateTime date;
  _DateHeader(this.date);
}

class _OfferItem extends _ListItem {
  final FlatOffer flat;
  _OfferItem(this.flat);
}
