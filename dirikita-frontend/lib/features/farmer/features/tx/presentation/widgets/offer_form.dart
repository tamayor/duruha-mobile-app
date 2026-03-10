import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/shared/produce/domain/market_listing_model.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:duruha/shared/produce/domain/produce_variety.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:flutter/material.dart';
import '../crop_selection_state.dart';
import 'package:duruha/features/farmer/features/tx/data/transaction_draft_service.dart';

String _fk(String variety, String listingId) => '$variety::$listingId';

class OfferForm extends StatefulWidget {
  final Produce produce;
  final CropSelectionState state;
  final Function(DateTime) onAvailableDatePicked;
  final Function(DateTime) onDisposalDatePicked;
  final VoidCallback onStateChanged;

  const OfferForm({
    super.key,
    required this.produce,
    required this.state,
    required this.onAvailableDatePicked,
    required this.onDisposalDatePicked,
    required this.onStateChanged,
  });

  @override
  State<OfferForm> createState() => _OfferFormState();
}

class _OfferFormState extends State<OfferForm> {
  final Set<String> _expandedVarieties = {};

  // selected form listing IDs per variety: variety name -> Set<listingId>
  final Map<String, Set<String>> _selectedForms = {};

  // quantity controllers keyed by "variety::listingId"
  final Map<String, TextEditingController> _qtyControllers = {};

  // date maps keyed by "variety::listingId"
  final Map<String, DateTime?> _availDates = {};
  final Map<String, DateTime?> _dispDates = {};

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Rebuilds widget.state.offerEntries from this widget's internal maps.
  void _syncEntriesToState() {
    final entries = <OfferFormEntry>[];
    for (final variety in widget.produce.availableVarieties) {
      final selectedIds = _selectedForms[variety.name] ?? {};
      for (final listing in variety.listings) {
        if (!selectedIds.contains(listing.listingId)) continue;
        final key = _fk(variety.name, listing.listingId);
        final qty =
            double.tryParse(_qtyControllers[key]?.text.trim() ?? '') ?? 0;
        entries.add(
          OfferFormEntry(
            varietyName: variety.name,
            listingId: listing.listingId,
            produceForm: listing.produceForm?.isNotEmpty == true
                ? listing.produceForm!
                : 'Standard',
            quantity: qty,
            pricePerUnit: listing.farmerToDuruhaPrice,
            availableFrom: _availDates[key],
            availableTo: _dispDates[key],
          ),
        );
      }
    }
    widget.state.offerEntries = entries;
    widget.onStateChanged();
  }

  TextEditingController _getQtyController(String variety, String listingId) {
    final key = _fk(variety, listingId);
    return _qtyControllers.putIfAbsent(key, () => TextEditingController());
  }

  bool _varietyHasEntry(String variant) {
    final forms = _selectedForms[variant];
    if (forms == null || forms.isEmpty) return false;
    return forms.any((lid) {
      final ctrl = _qtyControllers[_fk(variant, lid)];
      return (double.tryParse(ctrl?.text.trim() ?? '') ?? 0) > 0;
    });
  }

  int get _totalVarietiesWithEntry => widget.produce.availableVarieties
      .where((v) => _varietyHasEntry(v.name))
      .length;

  List<ProduceVariety> get _filteredVarieties {
    final q = _searchQuery.toLowerCase().trim();
    if (q.isEmpty) return widget.produce.availableVarieties;
    return widget.produce.availableVarieties
        .where((v) => v.name.toLowerCase().contains(q))
        .toList();
  }

  void _onFormToggled(String variant, MarketListing listing) {
    setState(() {
      final forms = _selectedForms.putIfAbsent(variant, () => {});
      if (forms.contains(listing.listingId)) {
        forms.remove(listing.listingId);
        final key = _fk(variant, listing.listingId);
        _qtyControllers.remove(key)?.dispose();
        _availDates.remove(key);
        _dispDates.remove(key);
        if (forms.isEmpty) _expandedVarieties.remove(variant);
      } else {
        forms.add(listing.listingId);
        _expandedVarieties.add(variant);
      }
    });
    widget.onStateChanged();
  }

  void _copyDatesToAll(
    String variant,
    String listingId,
    DateTime? avail,
    DateTime? disp,
  ) {
    if (avail == null || disp == null) {
      DuruhaSnackBar.showWarning(context, 'Set dates for this form first');
      return;
    }
    setState(() {
      for (final v in widget.produce.availableVarieties) {
        final forms = _selectedForms[v.name] ?? <String>{};
        for (final lid in forms) {
          _availDates[_fk(v.name, lid)] = avail;
          _dispDates[_fk(v.name, lid)] = disp;
        }
      }
    });
    _syncEntriesToState();
    DuruhaSnackBar.showSuccess(context, 'Dates applied to all forms');
  }

  void _setInfinity(String variant, String listingId, DateTime? avail) {
    setState(() {
      _availDates[_fk(variant, listingId)] = avail ?? DateTime.now();
      _dispDates[_fk(variant, listingId)] = DateTime(2100);
    });
    _syncEntriesToState();
  }

  Widget _buildFormEntry(
    BuildContext context,
    String variant,
    MarketListing listing,
    ThemeData theme,
  ) {
    final key = _fk(variant, listing.listingId);
    final controller = _getQtyController(variant, listing.listingId);
    final avail = _availDates[key];
    final disp = _dispDates[key];
    final label = listing.produceForm?.isNotEmpty == true
        ? listing.produceForm!
        : 'Standard';
    final priceLabel = DuruhaFormatter.formatCurrency(
      listing.farmerToDuruhaPrice,
    );

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Form label + price per unit
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$priceLabel / ${widget.state.selectedUnit}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Quantity field
          DuruhaTextField(
            isRequired: false,
            controller: controller,
            label: 'Quantity ($label)',
            icon: Icons.scale_rounded,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            suffix: widget.state.selectedUnit,
            onChanged: (_) {
              _syncEntriesToState();
            },
          ),
          // Date range picker
          DuruhaDateRangePicker(
            startDate: avail,
            endDate: disp,
            onDateRangePicked: (range) {
              setState(() {
                _availDates[key] = range.start;
                _dispDates[key] = range.end;
              });
              _syncEntriesToState();
            },
          ),
          const SizedBox(height: 4),

          // Action buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
                  final qty = controller.text;
                  setState(() {
                    for (final v in widget.produce.availableVarieties) {
                      final forms = _selectedForms[v.name] ?? <String>{};
                      for (final lid in forms) {
                        _qtyControllers[_fk(v.name, lid)]?.text = qty;
                      }
                    }
                  });
                  _syncEntriesToState();
                  DuruhaSnackBar.showSuccess(
                    context,
                    'Qty copied to all forms',
                  );
                },
                icon: const Icon(Icons.content_copy_rounded, size: 14),
                label: const Text('All Qty'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: theme.colorScheme.onSurface,
                  textStyle: theme.textTheme.labelSmall,
                ),
              ),
              const Spacer(),
              // Copy dates to ALL forms across all varieties
              TextButton.icon(
                onPressed: () =>
                    _copyDatesToAll(variant, listing.listingId, avail, disp),
                icon: const Icon(Icons.copy_rounded, size: 14),
                label: const Text('All Date'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: theme.colorScheme.onSurface,
                  textStyle: theme.textTheme.labelSmall,
                ),
              ),
              // Infinity end date
              IconButton(
                onPressed: () =>
                    _setInfinity(variant, listing.listingId, avail),
                icon: const Icon(Icons.all_inclusive_rounded, size: 18),
                tooltip: 'Until Infinity',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final varieties = _filteredVarieties;
    final totalEntries = _totalVarietiesWithEntry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Search bar ──
        DuruhaTextField(
          isRequired: false,
          controller: _searchController,
          label: 'Search variety',

          icon: Icons.search_rounded,
          onChanged: (val) => setState(() => _searchQuery = val),
        ),
        const SizedBox(height: 12),

        // ── Variety counter ──
        Row(
          children: [
            Text(
              '${varieties.length} ${varieties.length == 1 ? 'variety' : 'varieties'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            if (totalEntries > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$totalEntries with entry',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Variety cards ──
        ...varieties.map((varietyItem) {
          final variant = varietyItem.name;
          final isExpanded = _expandedVarieties.contains(variant);
          final selectedFormIds = _selectedForms[variant] ?? <String>{};
          final hasEntry = _varietyHasEntry(variant);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: hasEntry
                  ? theme.colorScheme.surfaceContainerLow
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: hasEntry
                    ? theme.colorScheme.primaryContainer
                    : Colors.transparent,
                width: hasEntry ? 1.5 : 0,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: DuruhaInkwell(
                variation: InkwellVariation.subtle,
                onTap: () {
                  setState(() {
                    if (isExpanded) {
                      _expandedVarieties.remove(variant);
                    } else {
                      _expandedVarieties.add(variant);
                    }
                  });
                },

                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header: Variety name + expand icon ──
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              variant,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: hasEntry
                                    ? theme.colorScheme.onPrimaryContainer
                                    : theme.colorScheme.onSecondary,
                              ),
                            ),
                          ),
                          Icon(
                            isExpanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            size: 20,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),

                      // ── Compact summary when collapsed ──
                      if (!isExpanded)
                        ...() {
                          if (!hasEntry) {
                            return [
                              const SizedBox(height: 4),
                              Text(
                                'Tap to set offer details',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ];
                          }
                          // Build form-name → qty pairs
                          final summaryItems = <Widget>[];
                          for (final lid in selectedFormIds) {
                            final listing = varietyItem.listings.firstWhere(
                              (l) => l.listingId == lid,
                              orElse: () => varietyItem.listings.first,
                            );
                            final form = listing.produceForm?.isNotEmpty == true
                                ? listing.produceForm!
                                : 'Standard';
                            final qtyCtrl = _qtyControllers[_fk(variant, lid)];
                            final qty = qtyCtrl?.text.trim() ?? '';
                            summaryItems.add(
                              Container(
                                margin: const EdgeInsets.only(right: 6, top: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  qty.isNotEmpty
                                      ? '$form · $qty ${widget.state.selectedUnit}'
                                      : form,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            );
                          }
                          return [Wrap(children: summaryItems)];
                        }(),

                      if (isExpanded) ...[
                        const SizedBox(height: 14),

                        // ── Produce Form Chip Group ──
                        if (varietyItem.listings.isNotEmpty)
                          DuruhaSelectionChipGroup(
                            title: '',
                            options: varietyItem.listings
                                .map(
                                  (l) => l.produceForm?.isNotEmpty == true
                                      ? l.produceForm!
                                      : 'Standard',
                                )
                                .toList(),
                            selectedValues: varietyItem.listings
                                .where(
                                  (l) => selectedFormIds.contains(l.listingId),
                                )
                                .map(
                                  (l) => l.produceForm?.isNotEmpty == true
                                      ? l.produceForm!
                                      : 'Standard',
                                )
                                .toList(),
                            onToggle: (formName) {
                              final listing = varietyItem.listings.firstWhere(
                                (l) =>
                                    (l.produceForm?.isNotEmpty == true
                                        ? l.produceForm!
                                        : 'Standard') ==
                                    formName,
                              );
                              _onFormToggled(variant, listing);
                            },
                          )
                        else
                          Text(
                            'No available forms',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),

                        // ── Per-form entry blocks ──
                        ...varietyItem.listings
                            .where((l) => selectedFormIds.contains(l.listingId))
                            .map(
                              (listing) => _buildFormEntry(
                                context,
                                variant,
                                listing,
                                theme,
                              ),
                            ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
