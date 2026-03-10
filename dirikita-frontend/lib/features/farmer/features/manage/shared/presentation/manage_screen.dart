import 'package:duruha/core/services/session_service.dart';
import 'package:flutter/material.dart';
import 'package:duruha/features/farmer/shared/presentation/widgets/navigation.dart';
import 'package:duruha/features/farmer/shared/presentation/farmer_loading_screen.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/farmer/features/manage/offers/data/manage_offer_repository.dart';
import 'package:duruha/features/farmer/features/manage/offers/presentation/manage_offer_screen.dart';
import 'package:duruha/features/farmer/features/manage/pledges/presentation/manage_pledge_screen.dart';
import 'package:intl/intl.dart';

class ManageScreen extends StatefulWidget {
  const ManageScreen({super.key});

  @override
  State<ManageScreen> createState() => _ManageScreenState();
}

class _ManageScreenState extends State<ManageScreen> {
  bool _isLoading = true;
  bool _isPledgeMode = false;

  // ── Offer filter / search state ────────────────────────────────────────────
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _searchText = '';
  bool _isSearchVisible = false;
  OfferSort _sort = OfferSort.dateDesc;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  // Key so we can call applyFilters on the inner screen
  final _offerScreenKey = GlobalKey<ManageOfferScreenState>();
  final _pledgeScreenKey = GlobalKey<ManagePledgeScreenState>();

  bool get _hasActiveFilters =>
      _sort != OfferSort.dateDesc || _dateFrom != null || _dateTo != null;

  bool get _hasAnyFilter => _searchText.isNotEmpty || _hasActiveFilters;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      if (!mounted) return;
      final isPledge = await SessionService.getModePreference();
      setState(() {
        _isPledgeMode = isPledge;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleMode(bool isPledge) async {
    setState(() => _isPledgeMode = isPledge);
    await SessionService.saveModePreference(isPledge);
    if (isPledge) {
      _pledgeScreenKey.currentState?.refresh();
    } else {
      _applyAndReload();
    }
  }

  // ── Filter actions ─────────────────────────────────────────────────────────

  void _applyAndReload() {
    _offerScreenKey.currentState?.applyFilters(
      search: _searchText,
      sort: _sort,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
    );
  }

  void _clearAllFilters() {
    _searchController.clear();
    setState(() {
      _searchText = '';
      _isSearchVisible = false;
      _sort = OfferSort.dateDesc;
      _dateFrom = null;
      _dateTo = null;
    });
    _applyAndReload();
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDateRange: _dateFrom != null && _dateTo != null
          ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _dateFrom = picked.start;
        _dateTo = picked.end;
      });
      _applyAndReload();
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (_isSearchVisible) {
        _searchFocus.requestFocus();
      } else {
        _searchFocus.unfocus();
        _searchController.clear();
        _searchText = '';
        _applyAndReload();
      }
    });
  }

  List<Widget> _buildActions() {
    final acts = <Widget>[];

    if (!_isPledgeMode) {
      if (_isSearchVisible) {
        acts.add(
          IconButton(
            onPressed: _toggleSearch,
            icon: const Icon(Icons.close),
            tooltip: "Close Search",
          ),
        );
      } else {
        // Sort
        acts.add(
          DuruhaPopupMenu<OfferSort>(
            items: OfferSort.values,
            selectedValue: _sort,
            onSelected: (v) {
              setState(() => _sort = v);
              _applyAndReload();
            },
            labelBuilder: (v) => v.label,
            tooltip: 'Sort',
            showBackground: false,
            customTrigger: Badge(
              isLabelVisible: _sort != OfferSort.dateDesc,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.sort_rounded),
              ),
            ),
          ),
        );

        // Date range
        acts.add(
          IconButton(
            icon: Badge(
              isLabelVisible: _dateFrom != null || _dateTo != null,
              child: const Icon(Icons.date_range_rounded),
            ),
            tooltip: 'Date range',
            onPressed: _pickDateRange,
          ),
        );

        // Search icon
        acts.add(
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search',
            onPressed: _toggleSearch,
          ),
        );
      }
    } else {
      // In Pledge mode we still need search toggle if we allow search there?
      // For now, following current logic but ensuring toggle mode is visible
      if (_isSearchVisible) {
        acts.add(
          IconButton(onPressed: _toggleSearch, icon: const Icon(Icons.close)),
        );
      }
    }

    // Always show mode toggle
    acts.add(
      DuruhaToggleButton(
        value: _isPledgeMode,
        onChanged: _toggleMode,
        iconTrue: Icons.handshake_rounded,
        iconFalse: Icons.local_offer_rounded,
      ),
    );
    acts.add(const SizedBox(width: 8));

    return acts;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Active filter chips shown below the title in the app bar bottom
    final chipBar = _hasAnyFilter
        ? PreferredSize(
            preferredSize: const Size.fromHeight(36),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (_searchText.isNotEmpty)
                      _chip(
                        context,
                        Icons.search,
                        '"$_searchText"',
                        onRemove: () {
                          _searchController.clear();
                          setState(() {
                            _searchText = '';
                            _isSearchVisible = false;
                          });
                          _applyAndReload();
                        },
                      ),
                    if (_sort != OfferSort.dateDesc)
                      _chip(
                        context,
                        Icons.sort_rounded,
                        _sort.label,
                        onRemove: () {
                          setState(() => _sort = OfferSort.dateDesc);
                          _applyAndReload();
                        },
                      ),
                    if (_dateFrom != null || _dateTo != null)
                      _chip(
                        context,
                        Icons.date_range_rounded,
                        _dateFrom != null && _dateTo != null
                            ? '${DateFormat('MMM d').format(_dateFrom!)} – ${DateFormat('MMM d').format(_dateTo!)}'
                            : _dateFrom != null
                            ? 'From ${DateFormat('MMM d').format(_dateFrom!)}'
                            : 'To ${DateFormat('MMM d').format(_dateTo!)}',
                        onRemove: () {
                          setState(() {
                            _dateFrom = null;
                            _dateTo = null;
                          });
                          _applyAndReload();
                        },
                      ),
                    TextButton(
                      onPressed: _clearAllFilters,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Clear all',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        : null;

    return DuruhaScaffold(
      appBarTitleWidget: _isSearchVisible
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                style: theme.textTheme.titleMedium,
                decoration: InputDecoration(
                  hintText: 'Search…',
                  border: InputBorder.none,
                  hintStyle: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                onChanged: (v) => setState(() => _searchText = v),
                onSubmitted: (_) => _applyAndReload(),
              ),
            )
          : Text(
              _isPledgeMode ? 'Manage Pledges' : 'Manage Offers',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
      showBackButton: true,
      appBarActions: _buildActions(),
      appBarBottom: chipBar,
      bottomNavigationBar: const FarmerNavigation(
        name: 'Elly',
        currentRoute: '/farmer/manage',
      ),
      body: _isLoading
          ? const FarmerLoadingScreen()
          : _isPledgeMode
          ? ManagePledgeScreen(key: _pledgeScreenKey)
          : OfferFilterController(
              searchText: _searchText,
              sort: _sort,
              dateFrom: _dateFrom,
              dateTo: _dateTo,
              child: ManageOfferScreen(key: _offerScreenKey),
            ),
    );
  }

  Widget _chip(
    BuildContext context,
    IconData icon,
    String label, {
    required VoidCallback onRemove,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Chip(
        avatar: Icon(icon, size: 11),
        label: Text(label, style: const TextStyle(fontSize: 11)),
        deleteIcon: const Icon(Icons.close, size: 11),
        onDeleted: onRemove,
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: theme.colorScheme.secondaryContainer,
        side: BorderSide.none,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
