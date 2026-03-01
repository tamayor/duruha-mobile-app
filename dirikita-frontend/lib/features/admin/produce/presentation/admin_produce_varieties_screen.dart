import 'package:duruha/core/theme/duruha_styles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:duruha/features/admin/shared/data/produce_admin_repository.dart';
import 'package:duruha/features/admin/price_calculator/presentation/price_calculator_screen.dart';
import 'package:duruha/shared/produce/presentation/widgets/variety_form.dart';
import 'package:duruha/shared/produce/data/produce_repository.dart';
import 'package:duruha/shared/produce/domain/produce_variety.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:flutter/material.dart';

import 'package:duruha/shared/produce/presentation/widgets/variety_widgets.dart';
import 'dart:math' as math;
import 'dart:async';

class _PriceRange {
  final double min;
  final double max;
  _PriceRange(this.min, this.max);
}

class LinkedScrollControllerGroup {
  final List<ScrollController> _controllers = [];
  double _offset = 0.0;

  ScrollController addAndGet() {
    final controller = ScrollController(initialScrollOffset: _offset);
    controller.addListener(() {
      if (controller.offset != _offset) {
        _offset = controller.offset;
        for (final c in _controllers) {
          if (c != controller && c.hasClients && c.offset != _offset) {
            c.jumpTo(_offset);
          }
        }
      }
    });
    _controllers.add(controller);
    return controller;
  }
}

class AdminProduceVarietiesScreen extends StatefulWidget {
  final Produce produce;

  const AdminProduceVarietiesScreen({super.key, required this.produce});

  @override
  State<AdminProduceVarietiesScreen> createState() =>
      _AdminProduceVarietiesScreenState();
}

enum VarietySortOption { nameAsc, nameDesc, priceAsc, priceDesc }

extension VarietySortOptionExt on VarietySortOption {
  String get label {
    switch (this) {
      case VarietySortOption.nameAsc:
        return 'Name (A to Z)';
      case VarietySortOption.nameDesc:
        return 'Name (Z to A)';
      case VarietySortOption.priceAsc:
        return 'Price (Low to High)';
      case VarietySortOption.priceDesc:
        return 'Price (High to Low)';
    }
  }
}

class _AdminProduceVarietiesScreenState
    extends State<AdminProduceVarietiesScreen> {
  final _repository = ProduceRepository();
  late final ProduceAdminRepository _adminRepo;
  late List<ProduceVariety> _varieties;
  bool _isLoading = false;
  bool _isSearching = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  VarietySortOption _sortOption = VarietySortOption.nameAsc;
  String _selectedForm = "All";

  RealtimeChannel? _realtimeChannel;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _adminRepo = ProduceAdminRepository(Supabase.instance.client);
    _varieties = widget.produce.varieties;
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('admin_produce_varieties_realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'produce_varieties',
          callback: (_) => _debouncedReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'produce_variety_listing',
          callback: (_) => _debouncedReload(),
        )
        .subscribe();
  }

  void _debouncedReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      if (mounted) {
        _refreshVarieties(isRefresh: true);
      }
    });
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshVarieties({bool isRefresh = false}) async {
    if (!isRefresh && mounted) setState(() => _isLoading = true);
    try {
      final updatedProduce = await _repository.fetchProduceById(
        widget.produce.id,
      );
      if (updatedProduce != null && mounted) {
        setState(() {
          // Merge local varieties to prevent them disappearing if backend read replica is stale
          final updatedIds = updatedProduce.varieties.map((v) => v.id).toSet();
          final localAdded = _varieties
              .where((v) => !updatedIds.contains(v.id))
              .toList();

          _varieties = [...updatedProduce.varieties, ...localAdded];
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addFormToAllVarieties() async {
    if (_isLoading) return;

    try {
      String? formName;
      final confirmed = await DuruhaDialog.show(
        context: context,
        title: 'Add Form to All Varieties',
        message:
            'Enter a form name to add to all ${_varieties.length} varieties at once.',
        confirmText: 'Add to All',
        cancelText: 'Cancel',
        icon: Icons.add_circle_outline_rounded,
        extraContentBuilder: (ctx) => _FormInputDialogContent(
          onChanged: (val) => formName = val,
          label: 'Form Name (e.g. Peeled, Packaged)',
        ),
      );

      if (confirmed != true || !mounted) return;
      final name = formName?.trim();
      if (name == null || name.isEmpty) return;

      setState(() => _isLoading = true);
      for (final variety in _varieties) {
        await _adminRepo.createVarietyListing(
          varietyId: variety.id,
          produceForm: name,
        );
      }
      if (!mounted) return;
      DuruhaSnackBar.showSuccess(
        context,
        'Added "$name" to all ${_varieties.length} varieties!',
      );
      await _refreshVarieties();
    } catch (e) {
      if (!mounted) return;
      DuruhaSnackBar.showError(context, 'Error: $e');
      setState(() => _isLoading = false);
    }
  }

  void _showAddFormDialog(
    BuildContext context,
    String varietyId,
    String varietyName,
  ) async {
    try {
      String? formName;
      final confirmed = await DuruhaDialog.show(
        context: context,
        title: 'Add Pricing Form',
        message: 'Enter a form name (e.g., Organic, Class A) for $varietyName.',
        confirmText: 'Add Form',
        cancelText: 'Cancel',
        icon: Icons.add_circle_outline_rounded,
        extraContentBuilder: (ctx) => _FormInputDialogContent(
          onChanged: (val) => formName = val,
          label: 'Form Name',
        ),
      );

      if (confirmed != true || !context.mounted) return;
      final name = formName?.trim();
      if (name == null || name.isEmpty) return;

      setState(() => _isLoading = true);
      await _adminRepo.createVarietyListing(
        varietyId: varietyId,
        produceForm: name,
      );

      if (!context.mounted) return;
      await _refreshVarieties();
      if (context.mounted) {
        DuruhaSnackBar.showSuccess(context, 'Added pricing form: $name');
      }
    } catch (e) {
      if (context.mounted) {
        DuruhaSnackBar.showError(context, 'Failed to add form: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  List<ProduceVariety> _getFilteredAndSortedVarieties() {
    final filtered = _varieties.where((v) {
      final query = _searchQuery.toLowerCase();
      final matchesQuery =
          v.name.toLowerCase().contains(query) ||
          v.isNative.toString().toLowerCase().contains(query) ||
          (v.breedingType ?? '').toLowerCase().contains(query) ||
          (v.philippineSeason ?? '').toLowerCase().contains(query) ||
          (v.appearanceDesc ?? '').toLowerCase().contains(query);

      if (!matchesQuery) return false;

      if (_selectedForm != "All") {
        return v.listings.any((l) {
          final form = l.produceForm!;
          return form == _selectedForm;
        });
      }

      return true;
    }).toList();

    filtered.sort((a, b) {
      switch (_sortOption) {
        case VarietySortOption.nameAsc:
          return a.name.compareTo(b.name);
        case VarietySortOption.nameDesc:
          return b.name.compareTo(a.name);
        case VarietySortOption.priceAsc:
          final aPrice = a.listings.isNotEmpty
              ? a.listings.first.duruhaToConsumerPrice
              : 0.0;
          final bPrice = b.listings.isNotEmpty
              ? b.listings.first.duruhaToConsumerPrice
              : 0.0;
          return aPrice.compareTo(bPrice);
        case VarietySortOption.priceDesc:
          final aPrice = a.listings.isNotEmpty
              ? a.listings.first.duruhaToConsumerPrice
              : 0.0;
          final bPrice = b.listings.isNotEmpty
              ? b.listings.first.duruhaToConsumerPrice
              : 0.0;
          return bPrice.compareTo(aPrice);
      }
    });
    return filtered;
  }

  List<String> _getUniqueForms() {
    final Set<String> forms = {"All"};
    for (final variety in _varieties) {
      for (final listing in variety.listings) {
        final form = listing.produceForm!;
        forms.add(form);
      }
    }
    final sortedForms = forms.toList()..sort();
    // Ensure "All" is first
    sortedForms.remove("All");
    return ["All", ...sortedForms];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DuruhaScaffold(
      appBarTitle: _isSearching
          ? null
          : '${widget.produce.englishName} Varieties',
      appBarTitleWidget: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search varieties...',
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            )
          : null,
      appBarActions: [
        if (!_isSearching)
          DuruhaPopupMenu<VarietySortOption>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort varieties',
            items: VarietySortOption.values,
            selectedValue: _sortOption,
            onSelected: (option) => setState(() => _sortOption = option),
            labelBuilder: (option) => option.label,
            showBackground: false,
            showLabel: false,
          ),
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search),
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchQuery = "";
                _searchController.clear();
              }
            });
          },
        ),
        if (!_isSearching)
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showAddVarietyModal(),
          ),
      ],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildVarietiesTable(),
    );
  }

  Widget _buildVarietiesTable() {
    final filtered = _getFilteredAndSortedVarieties();
    final uniqueForms = _getUniqueForms();

    if (filtered.isEmpty) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'No varieties found for this filter',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: DuruhaPopupMenu<String>(
                  items: uniqueForms,
                  selectedValue: _selectedForm,
                  onSelected: (form) => setState(() => _selectedForm = form),
                  labelBuilder: (form) => form,
                  icon: const Icon(Icons.category_outlined, size: 20),

                  showLabel: true,
                  showBackground: true,
                ),
              ),
              const SizedBox(width: 12),
              DuruhaButton(
                text: 'Add Form',
                isSmall: true,
                isFullWidth: false,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                onPressed: _addFormToAllVarieties,
              ),
            ],
          ),
        ),
        if (_selectedForm != "All")
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: DuruhaButton(
              onPressed: () {
                final listingIds = <String>[];
                final listingNames = <String>[];
                double? market, trader, farmer;

                for (final v in filtered) {
                  for (final l in v.listings) {
                    final form =
                        (l.produceForm == null || l.produceForm!.isEmpty)
                        ? "Default"
                        : l.produceForm!;
                    if (form == _selectedForm) {
                      listingIds.add(l.listingId);
                      listingNames.add("${v.name} ($form)");
                      market ??= l.marketToConsumerPrice;
                      trader ??= l.farmerToTraderPrice;
                      farmer ??= l.farmerToDuruhaPrice;
                    }
                  }
                }

                if (listingIds.isEmpty) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PriceCalculatorScreen(
                      targetListingIds: listingIds,
                      produceName: widget.produce.englishName,
                      varietyName: "Bulk Adjustment",
                      targetListingNames: listingNames,
                      produceForm: _selectedForm,
                      initialMarketPrice: market ?? 0.0,
                      initialTraderPrice: trader ?? 0.0,
                      initialFarmerPrice: farmer ?? 0.0,
                    ),
                  ),
                ).then((refresh) {
                  if (refresh == true && mounted) {
                    _refreshVarieties();
                  }
                });
              },
              text: 'Bulk Adjust $_selectedForm Prices',
              icon: const Icon(Icons.auto_fix_high_rounded, size: 20),
              isFullWidth: true,
            ),
          ),
        _buildTableHeader(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final variety = filtered[index];
              final prices = _calculatePriceRanges(variety, _selectedForm);
              return _VarietySyncCard(
                key: ValueKey(variety.id),
                variety: variety,
                produceName: widget.produce.englishName,
                prices: prices,
                onTap: () => _showVarietyListingsModal(context, variety),
                onRefresh: _refreshVarieties,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildHeaderCell('Duruha', scheme, true)),
          Expanded(child: _buildHeaderCell('Payout', scheme)),
          Expanded(child: _buildHeaderCell('Trader', scheme)),
          Expanded(child: _buildHeaderCell('Market', scheme)),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(
    String label,
    ColorScheme scheme, [
    bool isPrimary = false,
  ]) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: isPrimary
            ? scheme.primary.withValues(alpha: 0.1)
            : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPrimary
              ? scheme.primary.withValues(alpha: 0.3)
              : scheme.outlineVariant,
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isPrimary ? scheme.onTertiary : scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Map<String, _PriceRange> _calculatePriceRanges(
    ProduceVariety variety, [
    String? form,
  ]) {
    final listings = (form == null || form == "All")
        ? variety.listings
        : variety.listings.where((l) => l.produceForm == form).toList();

    if (listings.isEmpty) {
      final basePrice = variety.price;
      return {
        'duruha': _PriceRange(basePrice, basePrice),
        'payout': _PriceRange(0, 0),
        'trader': _PriceRange(0, 0),
        'market': _PriceRange(0, 0),
      };
    }

    double dMin = double.infinity, dMax = -double.infinity;
    double pMin = double.infinity, pMax = -double.infinity;
    double tMin = double.infinity, tMax = -double.infinity;
    double mMin = double.infinity, mMax = -double.infinity;

    for (var l in listings) {
      dMin = math.min(dMin, l.duruhaToConsumerPrice);
      dMax = math.max(dMax, l.duruhaToConsumerPrice);
      pMin = math.min(pMin, l.farmerToDuruhaPrice);
      pMax = math.max(pMax, l.farmerToDuruhaPrice);
      tMin = math.min(tMin, l.farmerToTraderPrice);
      tMax = math.max(tMax, l.farmerToTraderPrice);
      mMin = math.min(mMin, l.marketToConsumerPrice);
      mMax = math.max(mMax, l.marketToConsumerPrice);
    }

    return {
      'duruha': _PriceRange(dMin, dMax),
      'payout': _PriceRange(pMin, pMax),
      'trader': _PriceRange(tMin, tMax),
      'market': _PriceRange(mMin, mMax),
    };
  }

  void _showVarietyListingsModal(BuildContext context, ProduceVariety variety) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final allForms = _getUniqueForms().where((f) => f != 'All').toList();
    final varietyForms = variety.listings
        .map(
          (l) => (l.produceForm == null || l.produceForm!.isEmpty)
              ? 'Default'
              : l.produceForm!,
        )
        .toSet();
    final missingForms = allForms
        .where((f) => !varietyForms.contains(f))
        .toList();
    if (variety.listings.isEmpty && !missingForms.contains('Default')) {}

    DuruhaBottomSheet.show(
      context: context,
      title: '${variety.name} Listings',
      icon: Icons.list_alt,
      isScrollable: false,
      heightFactor: 0.85,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: VarietySpecsCard(
                      variety: variety,
                      showAdminFields: true,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: DuruhaButton(
                      onPressed: () {
                        if (variety.listings.isEmpty) {
                          DuruhaSnackBar.showWarning(
                            context,
                            "No pricing forms found. Add a form first.",
                          );
                          return;
                        }
                        final listingIds = variety.listings
                            .map((l) => l.listingId)
                            .toList();
                        final firstListing = variety.listings.first;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PriceCalculatorScreen(
                              targetListingIds: listingIds,
                              produceName: widget.produce.englishName,
                              varietyName: variety.name,
                              targetListingNames: variety.listings
                                  .map((l) => l.produceForm ?? '')
                                  .toList(),
                              initialMarketPrice:
                                  firstListing.marketToConsumerPrice,
                              initialTraderPrice:
                                  firstListing.farmerToTraderPrice,
                              initialFarmerPrice:
                                  firstListing.farmerToDuruhaPrice,
                            ),
                          ),
                        ).then((refresh) {
                          if (refresh == true && context.mounted) {
                            _refreshVarieties();
                          }
                        });
                      },
                      text: 'Adjust All Form Pricing',
                      icon: const Icon(Icons.auto_fix_high_rounded, size: 20),
                      isFullWidth: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Divider(),
                  ),
                  if (variety.listings.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 32.0,
                        horizontal: 16.0,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: scheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No pricing forms found',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Click "Add Form" below to start tracking prices.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ...List.generate(variety.listings.length, (index) {
                    final listing = variety.listings[index];
                    final isDefaultForm =
                        listing.produceForm == null ||
                        listing.produceForm!.isEmpty;
                    final formName = isDefaultForm
                        ? 'Default Form'
                        : listing.produceForm!;

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(
                                      formName,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: isDefaultForm
                                                ? scheme.onPrimary
                                                : scheme.onTertiary,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  DuruhaButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              PriceCalculatorScreen(
                                                targetListingIds: [
                                                  listing.listingId,
                                                ],
                                                produceName:
                                                    widget.produce.englishName,
                                                varietyName: variety.name,
                                                produceForm:
                                                    (listing.produceForm ==
                                                            null ||
                                                        listing
                                                            .produceForm!
                                                            .isEmpty)
                                                    ? 'Default'
                                                    : listing.produceForm,
                                                initialMarketPrice: listing
                                                    .marketToConsumerPrice,
                                                initialTraderPrice:
                                                    listing.farmerToTraderPrice,
                                                initialFarmerPrice:
                                                    listing.farmerToDuruhaPrice,
                                              ),
                                        ),
                                      ).then((refresh) {
                                        if (refresh == true &&
                                            context.mounted) {
                                          _refreshVarieties();
                                        }
                                      });
                                    },
                                    text: 'Adjust',
                                    icon: const Icon(
                                      Icons.calculate_outlined,
                                      size: 16,
                                    ),
                                    isSmall: true,
                                    isFullWidth: false,
                                    isOutline: true,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildListingPricing(
                                      context,
                                      "Farmer -> Trader",
                                      listing.farmerToTraderPrice,
                                      scheme,
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildListingPricing(
                                      context,
                                      "Farmer -> Duruha",
                                      listing.farmerToDuruhaPrice,
                                      scheme,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildListingPricing(
                                      context,
                                      "Duruha -> Consumer",
                                      listing.duruhaToConsumerPrice,
                                      scheme,
                                      isBold: true,
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildListingPricing(
                                      context,
                                      "Market -> Consumer",
                                      listing.marketToConsumerPrice,
                                      scheme,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (index < variety.listings.length - 1)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Divider(),
                          ),
                      ],
                    );
                  }),
                  if (missingForms.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            variety.listings.isEmpty
                                ? 'Suggested Forms'
                                : 'Missing Common Forms',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: missingForms.map((formName) {
                              return DuruhaButton(
                                onPressed: () async {
                                  try {
                                    final name = formName;
                                    Navigator.pop(context); // Close modal
                                    setState(() => _isLoading = true);
                                    await _adminRepo.createVarietyListing(
                                      varietyId: variety.id,
                                      produceForm: name,
                                    );
                                    if (!context.mounted) return;
                                    await _refreshVarieties();
                                    if (context.mounted) {
                                      DuruhaSnackBar.showSuccess(
                                        context,
                                        'Added "$formName" pricing form!',
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      DuruhaSnackBar.showError(
                                        context,
                                        'Error: $e',
                                      );
                                      setState(() => _isLoading = false);
                                    }
                                  }
                                },
                                text: '+ $formName',
                                isSmall: true,
                                isOutline: true,
                                isFullWidth: false,
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: DuruhaButton(
                    onPressed: () => _showEditVarietyModal(variety),
                    text: 'Edit Variety',
                    icon: const Icon(Icons.edit_rounded),
                    isOutline: true,
                    isSmall: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DuruhaButton(
                    onPressed: () =>
                        _showAddFormDialog(context, variety.id, variety.name),
                    text: 'Add Form',
                    icon: const Icon(Icons.add_circle_outline),
                    isOutline: true,
                    isSmall: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListingPricing(
    BuildContext context,
    String label,
    double value,
    ColorScheme scheme, {
    bool isBold = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        Text(
          "₱${value.toStringAsFixed(2)}",
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: isBold ? scheme.onTertiary : null,
          ),
        ),
      ],
    );
  }

  void _showEditVarietyModal(ProduceVariety variety) async {
    // Close the listings modal first to prevent duplicate GlobalKey errors
    Navigator.pop(context);
    // Wait for the close animation to complete
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    DuruhaBottomSheet.show(
      context: context,
      title: 'Edit ${variety.name}',
      icon: Icons.edit_rounded,
      isScrollable: true,
      child: VarietyForm(
        produceName: variety.name,
        produceId: widget.produce.id,
        initialData: {
          'id': variety.id,
          'variety_name': variety.name,
          'image_url': variety.imageUrl,
          'breeding_type': variety.breedingType,
          'days_to_maturity_min': variety.daysToMaturityMin,
          'days_to_maturity_max': variety.daysToMaturityMax,
          'peak_months': variety.peakMonths,
          'philippine_season': variety.philippineSeason,
          'flood_tolerance': variety.floodTolerance,
          'handling_fragility': variety.handlingFragility,
          'shelf_life_days': variety.shelfLifeDays,
          'optimal_storage_temp_c': variety.optimalStorageTempC,
          'packaging_requirement': variety.packagingRequirement,
          'appearance_desc': variety.appearanceDesc,
          'is_native': variety.isNative,
        },
        repository: _repository,
        onSave: (data) async {
          try {
            final result = await _repository.addProduceVariety(data);
            if (!mounted) return;
            Navigator.pop(context); // Close edit modal

            // Optimistically update
            setState(() {
              final index = _varieties.indexWhere((v) => v.id == variety.id);
              if (index >= 0) {
                _varieties[index] = ProduceVariety(
                  id: (result['variety_id'] ?? result['id'] ?? variety.id)
                      .toString(),
                  name: result['variety_name'] ?? variety.name,
                  imageUrl: result['image_url'],
                  isNative: result['is_native'] == true,
                  breedingType: result['breeding_type'],
                  daysToMaturityMin: result['days_to_maturity_min'],
                  daysToMaturityMax: result['days_to_maturity_max'],
                  peakMonths:
                      (result['peak_months'] as List<dynamic>?)
                          ?.map((e) => e.toString())
                          .toList() ??
                      [],
                  philippineSeason: result['philippine_season'],
                  floodTolerance: result['flood_tolerance'],
                  handlingFragility: result['handling_fragility'],
                  shelfLifeDays: result['shelf_life_days'] ?? 7,
                  optimalStorageTempC: result['optimal_storage_temp_c'] != null
                      ? (result['optimal_storage_temp_c'] as num).toDouble()
                      : null,
                  packagingRequirement: result['packaging_requirement'],
                  appearanceDesc: result['appearance_desc'],
                  listings: variety.listings,
                );
              }
            });

            await _refreshVarieties(isRefresh: true); // Background refresh
            if (mounted) {
              DuruhaSnackBar.showSuccess(
                context,
                "Updated ${variety.name} specifications",
              );
            }
          } catch (e) {
            if (!mounted) return;
            DuruhaSnackBar.showError(context, "Failed to update variety: $e");
          }
        },
      ),
    );
  }

  void _showAddVarietyModal() {
    DuruhaBottomSheet.show(
      context: context,
      title: 'Add New Variety',
      icon: Icons.add_circle_outline,
      isScrollable: true,
      child: VarietyForm(
        produceName: widget.produce.englishName,
        produceId: widget.produce.id,
        repository: _repository,
        onSave: (data) async {
          try {
            final result = await _repository.addProduceVariety(data);
            if (!mounted) return;
            Navigator.pop(context); // Close modal

            // Optimistically add
            setState(() {
              _varieties.add(
                ProduceVariety(
                  id: (result['variety_id'] ?? result['id']).toString(),
                  name: result['variety_name'] ?? '',
                  imageUrl: result['image_url'],
                  isNative: result['is_native'] == true,
                  breedingType: result['breeding_type'],
                  daysToMaturityMin: result['days_to_maturity_min'],
                  daysToMaturityMax: result['days_to_maturity_max'],
                  peakMonths:
                      (result['peak_months'] as List<dynamic>?)
                          ?.map((e) => e.toString())
                          .toList() ??
                      [],
                  philippineSeason: result['philippine_season'],
                  floodTolerance: result['flood_tolerance'],
                  handlingFragility: result['handling_fragility'],
                  shelfLifeDays: result['shelf_life_days'] ?? 7,
                  optimalStorageTempC: result['optimal_storage_temp_c'] != null
                      ? (result['optimal_storage_temp_c'] as num).toDouble()
                      : null,
                  packagingRequirement: result['packaging_requirement'],
                  appearanceDesc: result['appearance_desc'],
                  listings: [],
                ),
              );
            });

            await _refreshVarieties(isRefresh: true); // Background refresh
            if (mounted) {
              DuruhaSnackBar.showSuccess(context, "Added new variety");
            }
          } catch (e) {
            if (!mounted) return;
            DuruhaSnackBar.showError(context, "Failed to add variety: $e");
          }
        },
      ),
    );
  }
}

class _FormInputDialogContent extends StatefulWidget {
  final Function(String) onChanged;
  final String label;

  const _FormInputDialogContent({required this.onChanged, required this.label});

  @override
  State<_FormInputDialogContent> createState() =>
      _FormInputDialogContentState();
}

class _FormInputDialogContentState extends State<_FormInputDialogContent> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      autofocus: true,
      decoration: DuruhaStyles.inputDecoration(
        context,
        label: widget.label,
        icon: Icons.category_outlined,
      ),
      textCapitalization: TextCapitalization.words,
      onChanged: widget.onChanged,
    );
  }
}

class _VarietySyncCard extends StatefulWidget {
  final ProduceVariety variety;
  final String produceName;
  final VoidCallback onTap;
  final Map<String, _PriceRange> prices;
  final VoidCallback onRefresh;

  const _VarietySyncCard({
    super.key,
    required this.variety,
    required this.produceName,
    required this.onTap,
    required this.prices,
    required this.onRefresh,
  });

  @override
  State<_VarietySyncCard> createState() => _VarietySyncCardState();
}

class _VarietySyncCardState extends State<_VarietySyncCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: DuruhaInkwell(
        variation: InkwellVariation.brand,
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Section: Info
            _buildVarietyInfo(theme, scheme),
            const Divider(height: 1),
            // Middle Section: Scrollable Prices
            _buildPricingScroll(theme, scheme),
            const Divider(height: 1),
            // Bottom Section: Admin Actions
          ],
        ),
      ),
    );
  }

  Widget _buildVarietyInfo(ThemeData theme, ColorScheme scheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.2),
      ),
      child: Text(
        widget.variety.name,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: scheme.onSurface,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildPricingScroll(ThemeData theme, ColorScheme scheme) {
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          Expanded(
            child: _buildPriceCell(
              widget.prices['duruha']!,
              theme,
              scheme,
              true,
            ),
          ),
          Expanded(
            child: _buildPriceCell(widget.prices['payout']!, theme, scheme),
          ),
          Expanded(
            child: _buildPriceCell(widget.prices['trader']!, theme, scheme),
          ),
          Expanded(
            child: _buildPriceCell(widget.prices['market']!, theme, scheme),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCell(
    _PriceRange range,
    ThemeData theme,
    ColorScheme scheme, [
    bool isAppPrice = false,
  ]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Center(
        child: (range.min <= 0 && range.max <= 0)
            ? Text('-', style: theme.textTheme.labelLarge)
            : range.min == range.max
            ? Text(
                "₱${range.max.toStringAsFixed(0)}",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isAppPrice ? scheme.onSecondary : null,
                  fontSize: 14,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "₱${range.max.toStringAsFixed(0)}",
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isAppPrice
                          ? scheme.onTertiary
                          : scheme.onSecondary,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    "₱${range.min.toStringAsFixed(0)}",
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
