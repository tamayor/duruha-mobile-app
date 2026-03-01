import 'package:flutter/material.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:duruha/shared/produce/domain/produce_variety.dart';
import 'package:duruha/shared/produce/presentation/widgets/variety_widgets.dart';
import 'package:duruha/shared/produce/data/produce_repository.dart';
import 'package:duruha/shared/produce/presentation/widgets/variety_form.dart';

class ProduceVarietiesScreen extends StatefulWidget {
  final Produce produce;
  final String title;
  final List<ProduceVariety> varieties;

  const ProduceVarietiesScreen({
    super.key,
    this.title = '',
    required this.produce,
    required this.varieties,
  });

  @override
  State<ProduceVarietiesScreen> createState() => _ProduceVarietiesScreenState();
}

enum VarietySortOption {
  nameAsc,
  nameDesc,
  priceAsc,
  priceDesc,
  shelfLifeDesc,
  maturityFastest,
}

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
      case VarietySortOption.shelfLifeDesc:
        return 'Longest Shelf Life';
      case VarietySortOption.maturityFastest:
        return 'Fastest Maturity';
    }
  }
}

class _ProduceVarietiesScreenState extends State<ProduceVarietiesScreen> {
  final _repository = ProduceRepository();
  late List<ProduceVariety> _localVarieties;
  final _searchController = TextEditingController();
  bool _isSearching = false;
  String _searchQuery = '';
  bool _isAllCompact = false;
  VarietySortOption _sortOption = VarietySortOption.nameAsc;

  @override
  void initState() {
    super.initState();
    _localVarieties = List.from(widget.varieties);
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
        _searchController.clear();
      }
    });
  }

  Future<void> _showAddDialog(BuildContext context) async {
    await DuruhaBottomSheet.show(
      context: context,
      title: 'Add New Variety',
      icon: Icons.eco,
      child: VarietyForm(
        produceName: widget.produce.englishName,
        produceId: widget.produce.id,
        repository: _repository,
        onSave: (data) async {
          try {
            await _repository.addProduceVariety(data);
            if (!mounted) return;

            setState(() {
              _localVarieties.add(
                ProduceVariety(
                  id:
                      data['variety_id'] as String? ??
                      'temp-${DateTime.now().millisecondsSinceEpoch}',
                  name: data['variety_name'] as String,
                  isNative: data['is_native'] as bool? ?? false,
                  imageUrl: data['image_url'] as String?,
                  breedingType: data['breeding_type'] as String?,
                  daysToMaturityMin: data['days_to_maturity_min'] as int?,
                  daysToMaturityMax: data['days_to_maturity_max'] as int?,
                  peakMonths:
                      (data['peak_months'] as List?)?.cast<String>() ?? [],
                  philippineSeason: data['philippine_season'] as String?,
                  floodTolerance: data['flood_tolerance'] as int?,
                  handlingFragility: data['handling_fragility'] as int?,
                  shelfLifeDays: data['shelf_life_days'] as int? ?? 7,
                  optimalStorageTempC:
                      data['optimal_storage_temp_c'] as double?,
                  packagingRequirement:
                      data['packaging_requirement'] as String?,
                  appearanceDesc: data['appearance_desc'] as String?,
                ),
              );
            });

            if (!context.mounted) return;
            DuruhaSnackBar.showSuccess(
              context,
              "Added variety: ${data['variety_name']}",
            );
          } catch (e) {
            if (!context.mounted) return;
            DuruhaSnackBar.showError(context, "Failed to add variety: $e");
            rethrow;
          }
        },
      ),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    ProduceVariety variety,
  ) async {
    await DuruhaBottomSheet.show(
      context: context,
      title: 'Edit Variety',
      icon: Icons.edit,
      child: VarietyForm(
        produceName: widget.produce.englishName,
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
          // 'price': variety.price,
        },
        repository: _repository,
        onSave: (data) async {
          try {
            data['variety_id'] = variety.id;
            await _repository.addProduceVariety(data);
            if (!mounted) return;

            setState(() {
              final index = _localVarieties.indexWhere(
                (v) => v.id == variety.id,
              );
              if (index != -1) {
                _localVarieties[index] = ProduceVariety(
                  id: variety.id,
                  name: data['variety_name'] as String,
                  isNative: data['is_native'] as bool? ?? false,
                  imageUrl: data['image_url'] as String?,
                  breedingType: data['breeding_type'] as String?,
                  daysToMaturityMin: data['days_to_maturity_min'] as int?,
                  daysToMaturityMax: data['days_to_maturity_max'] as int?,
                  peakMonths:
                      (data['peak_months'] as List?)?.cast<String>() ?? [],
                  philippineSeason: data['philippine_season'] as String?,
                  floodTolerance: data['flood_tolerance'] as int?,
                  handlingFragility: data['handling_fragility'] as int?,
                  shelfLifeDays: data['shelf_life_days'] as int? ?? 7,
                  optimalStorageTempC: (data['optimal_storage_temp_c'] ?? 0.0)
                      .toDouble(),
                  packagingRequirement:
                      data['packaging_requirement'] as String?,
                  appearanceDesc: data['appearance_desc'] as String?,
                );
              }
            });

            if (!context.mounted) return;
            DuruhaSnackBar.showSuccess(
              context,
              "Updated variety: ${data['variety_name']}",
            );
          } catch (e) {
            if (!context.mounted) return;
            DuruhaSnackBar.showError(context, "Failed to update variety: $e");
            rethrow;
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Filter logic moved here
    final filteredVarieties = _localVarieties
        .where(
          (v) =>
              v.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              v.isNative.toString().toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              (v.breedingType ?? '').toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              (v.daysToMaturityMin?.toString() ?? '').contains(
                _searchQuery.toLowerCase(),
              ) ||
              (v.daysToMaturityMax?.toString() ?? '').contains(
                _searchQuery.toLowerCase(),
              ) ||
              v.peakMonths.any(
                (m) => m.toLowerCase().contains(_searchQuery.toLowerCase()),
              ) ||
              (v.philippineSeason ?? '').toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              (v.floodTolerance?.toString() ?? '').contains(
                _searchQuery.toLowerCase(),
              ) ||
              (v.handlingFragility?.toString() ?? '').contains(
                _searchQuery.toLowerCase(),
              ) ||
              v.shelfLifeDays.toString().contains(_searchQuery.toLowerCase()) ||
              (v.optimalStorageTempC?.toString() ?? '').contains(
                _searchQuery.toLowerCase(),
              ) ||
              (v.packagingRequirement ?? '').toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ) ||
              (v.appearanceDesc ?? '').toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ),
        )
        .toList();

    filteredVarieties.sort((a, b) {
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
        case VarietySortOption.shelfLifeDesc:
          return b.shelfLifeDays.compareTo(a.shelfLifeDays);
        case VarietySortOption.maturityFastest:
          final aMat = a.daysToMaturityMin ?? 9999;
          final bMat = b.daysToMaturityMin ?? 9999;
          return aMat.compareTo(bMat);
      }
    });

    return DuruhaScaffold(
      appBarTitle: _isSearching ? null : widget.title,
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
        if (!_isSearching)
          IconButton(
            icon: Icon(_isAllCompact ? Icons.unfold_more : Icons.unfold_less),
            onPressed: () {
              setState(() {
                _isAllCompact = !_isAllCompact;
              });
            },
            tooltip: _isAllCompact ? 'Expand All' : 'Collapse All',
          ),
        IconButton(
          icon: Icon(_isSearching ? Icons.close : Icons.search),
          onPressed: _toggleSearch,
        ),
        if (!_isSearching)
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showAddDialog(context),
          ),
      ],
      body: CustomScrollView(
        slivers: [
          ...VarietiesSection.buildSlivers(
            context: context,
            produce: widget.produce,
            varieties: filteredVarieties,
            onEdit: (v) => _showEditDialog(context, v),
            compactOverride: _isAllCompact,
          ),
        ],
      ),
    );
  }
}
