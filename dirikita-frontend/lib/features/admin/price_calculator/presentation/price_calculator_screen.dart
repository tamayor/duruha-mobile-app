import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/shared/produce/domain/produce_variety.dart';
import 'package:duruha/features/admin/shared/data/produce_admin_repository.dart';
import 'package:duruha/features/admin/shared/presentation/widgets/admin_navigation.dart';

class PriceCalculatorScreen extends StatefulWidget {
  final List<ProduceVariety>? targetVarieties;
  final List<String>? targetListingIds;
  final double? initialMarketPrice;
  final double? initialTraderPrice;
  final double? initialFarmerPrice;
  final String? produceName;
  final String? varietyName;
  final List<String>? targetListingNames;
  final String? produceForm;

  const PriceCalculatorScreen({
    super.key,
    this.targetVarieties,
    this.targetListingIds,
    this.initialMarketPrice,
    this.initialTraderPrice,
    this.initialFarmerPrice,
    this.produceName,
    this.varietyName,
    this.targetListingNames,
    this.produceForm,
  });

  @override
  State<PriceCalculatorScreen> createState() => _PriceCalculatorScreenState();
}

class _PriceCalculatorScreenState extends State<PriceCalculatorScreen> {
  // --- Core Inputs ---
  late final TextEditingController _marketPriceController;
  late final TextEditingController _discountPercentController;
  late final TextEditingController _logisticsCostController;
  late final TextEditingController _wastagePercentController;
  late final TextEditingController _duruhaMarginController;
  late final TextEditingController _traderPriceController;

  List<ProduceVariety> _activeVarieties = [];

  @override
  void initState() {
    super.initState();

    // Setup target list if provided
    if (widget.targetVarieties != null) {
      _activeVarieties = List.from(widget.targetVarieties!);
    }

    // Default or prepopulated values
    _marketPriceController = TextEditingController(
      text: widget.initialMarketPrice != null
          ? widget.initialMarketPrice!.toStringAsFixed(2)
          : '100',
    );

    _discountPercentController = TextEditingController(text: '10');
    _logisticsCostController = TextEditingController(text: '5');
    _wastagePercentController = TextEditingController(text: '5');

    // For Duruha margin, default to 15% but calculate inverse if farmer price is provided
    _duruhaMarginController = TextEditingController(text: '25');

    _traderPriceController = TextEditingController(
      text: widget.initialTraderPrice != null
          ? widget.initialTraderPrice!.toStringAsFixed(2)
          : '50',
    );
  }

  // --- Reactive Getters ---
  double get _marketPrice => double.tryParse(_marketPriceController.text) ?? 0;
  double get _discountPercent =>
      (double.tryParse(_discountPercentController.text) ?? 0) / 100;
  double get _logisticsCost =>
      double.tryParse(_logisticsCostController.text) ?? 0;
  double get _wastagePercent =>
      (double.tryParse(_wastagePercentController.text) ?? 0) / 100;
  double get _duruhaMarginPercent =>
      (double.tryParse(_duruhaMarginController.text) ?? 0) / 100;
  double get _traderPrice => double.tryParse(_traderPriceController.text) ?? 0;

  // --- Algorithm Calculations ---
  double get _duruhaAppPrice => _marketPrice * (1 - _discountPercent);
  double get _wastageCost => _duruhaAppPrice * _wastagePercent;
  double get _duruhaMargin => _duruhaAppPrice * _duruhaMarginPercent;
  double get _farmerPayout =>
      _duruhaAppPrice - _logisticsCost - _wastageCost - _duruhaMargin;

  void _triggerRebuild() {
    setState(() {});
  }

  @override
  void dispose() {
    _marketPriceController.dispose();
    _discountPercentController.dispose();
    _logisticsCostController.dispose();
    _wastagePercentController.dispose();
    _duruhaMarginController.dispose();
    _traderPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DuruhaScaffold(
      appBarTitle: 'Price Calculator',
      appBarActions: [
        if (widget.produceName != null || widget.varietyName != null)
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.swap_horiz_rounded, size: 20),
            label: const Text('Change'),
            style: TextButton.styleFrom(foregroundColor: scheme.onSurface),
          ),
      ],
      bottomNavigationBar: const AdminNavigation(
        currentRoute: '/admin/calculator',
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Level 1: Produce Name
                    if (widget.produceName != null)
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 20,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.produceName!,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: scheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    // Level 2: Produce Varieties
                    if (widget.targetListingNames != null &&
                        widget.targetListingNames!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.subdirectory_arrow_right_rounded,
                              size: 18,
                              color: scheme.outline,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: widget.targetListingNames!.map((
                                  name,
                                ) {
                                  final cleanName = name.split(' (').first;
                                  return Text(
                                    cleanName +
                                        (name == widget.targetListingNames!.last
                                            ? ""
                                            : ","),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: scheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (widget.varietyName != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.subdirectory_arrow_right_rounded,
                              size: 18,
                              color: scheme.outline,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.varietyName!,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Level 3: Produce Form
                    if (widget.produceForm != null)
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 36,
                          top: 4,
                        ), // Further indented
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.subdirectory_arrow_right_rounded,
                              size: 18,
                              color: scheme.outlineVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.produceForm!,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.initialMarketPrice != null ||
                  widget.initialTraderPrice != null ||
                  widget.initialFarmerPrice != null) ...[
                _buildPreviousPricesCard(scheme, theme),
                const SizedBox(height: 16),
              ],
              _buildResultsCard(scheme, theme),
              const SizedBox(height: 16),
              _buildConsumerSentimentCheck(scheme, theme),
              const SizedBox(height: 16),
              _buildFarmerSentimentCheck(scheme, theme),
              const SizedBox(height: 24),
              __buildInputSection(scheme, theme),
              if (_activeVarieties.isNotEmpty ||
                  widget.targetListingIds != null) ...[
                const SizedBox(height: 24),
                _buildTargetVarietiesSection(scheme, theme),
              ],
              const SizedBox(height: 100), // Padding for bottom nav
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviousPricesCard(ColorScheme scheme, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Current Pricing",
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (widget.initialMarketPrice != null)
            _buildResultRow(
              label: "Market Price",
              value: "₱${widget.initialMarketPrice!.toStringAsFixed(2)} /kg",
            ),
          if (widget.initialFarmerPrice != null) ...[
            const SizedBox(height: 4),
            _buildResultRow(
              label: "App Price (Farmer Payout)",
              value: "₱${widget.initialFarmerPrice!.toStringAsFixed(2)} /kg",
              valueColor: scheme.primary,
            ),
          ],
          if (widget.initialTraderPrice != null) ...[
            const SizedBox(height: 4),
            _buildResultRow(
              label: "Trader Price",
              value: "₱${widget.initialTraderPrice!.toStringAsFixed(2)} /kg",
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsCard(ColorScheme scheme, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Algorithm Results",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildResultRow(
            label: "Duruha App Price",
            value: "₱${_duruhaAppPrice.toStringAsFixed(2)} /kg",
            valueColor: scheme.onTertiary,
            isBold: true,
          ),
          const Divider(height: 24),
          _buildResultRow(
            label: "Logistics Deduction",
            value: "-₱${_logisticsCost.toStringAsFixed(2)}",
            valueColor: scheme.error,
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            label: "Wastage Buffer Deduction",
            value: "-₱${_wastageCost.toStringAsFixed(2)}",
            valueColor: scheme.error,
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            label: "Duruha Margin",
            value: "-₱${_duruhaMargin.toStringAsFixed(2)}",
            valueColor: scheme.error,
          ),
          const Divider(height: 24),
          _buildResultRow(
            label: "Final Farmer Payout",
            value: "₱${_farmerPayout.toStringAsFixed(2)} /kg",
            valueColor: scheme.onSecondary,
            isLarge: true,
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow({
    required String label,
    required String value,
    Color? valueColor,
    bool isBold = false,
    bool isLarge = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: isLarge ? 16 : 14,
            fontWeight: isBold || isLarge ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Theme.of(context).colorScheme.onSurface,
            fontSize: isLarge ? 20 : 16,
            fontWeight: isBold || isLarge ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildConsumerSentimentCheck(ColorScheme scheme, ThemeData theme) {
    final difference = _marketPrice - _duruhaAppPrice;
    final isGreatDeal = _duruhaAppPrice < _marketPrice;
    final diffString =
        "₱${difference.abs().toStringAsFixed(2)}/kg ${isGreatDeal ? 'saved' : 'more expensive'} vs Market";

    return _buildSentimentBanner(
      scheme: scheme,
      theme: theme,
      isGreatDeal: isGreatDeal,
      greatTitle: "Great for Consumers!",
      badTitle: "Bad for Consumers.",
      subtitle: diffString,
    );
  }

  Widget _buildFarmerSentimentCheck(ColorScheme scheme, ThemeData theme) {
    final difference = _farmerPayout - _traderPrice;
    final isGreatDeal = _farmerPayout >= _traderPrice;
    final diffString =
        "₱${difference.abs().toStringAsFixed(2)}/kg ${difference >= 0 ? 'more' : 'less'} than Trader";

    return _buildSentimentBanner(
      scheme: scheme,
      theme: theme,
      isGreatDeal: isGreatDeal,
      greatTitle: "Great Dealer for Farmer!",
      badTitle: "Bad Deal for Farmer.",
      subtitle: diffString,
    );
  }

  Widget _buildSentimentBanner({
    required ColorScheme scheme,
    required ThemeData theme,
    required bool isGreatDeal,
    required String greatTitle,
    required String badTitle,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGreatDeal
            ? const Color(0xFF10B981).withValues(alpha: 0.15) // Emerald green
            : const Color(0xFFEF4444).withValues(alpha: 0.15), // Red
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isGreatDeal
              ? const Color(0xFF10B981)
              : const Color(0xFFEF4444).withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isGreatDeal ? Icons.check_circle_rounded : Icons.warning_rounded,
            color: isGreatDeal
                ? const Color(0xFF10B981)
                : const Color(0xFFEF4444),
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isGreatDeal ? greatTitle : badTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isGreatDeal
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444),
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget __buildInputSection(ColorScheme scheme, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Algorithm Variables",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInputRow(
            "Market",
            _marketPriceController,
            Icons.storefront_rounded,
            "₱/kg",
          ),
          _buildInputRow(
            "Trader Price",
            _traderPriceController,
            Icons.compare_arrows_rounded,
            "₱/kg",
          ),
          Row(
            children: [
              Expanded(
                child: _buildInputRow(
                  "Discount",
                  _discountPercentController,
                  Icons.percent_rounded,
                  "%/kg",
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInputRow(
                  "Logistics",
                  _logisticsCostController,
                  Icons.local_shipping_rounded,
                  "₱/kg",
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: _buildInputRow(
                  "Wastage Buffer",
                  _wastagePercentController,
                  Icons.compost_rounded,
                  "%/kg",
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInputRow(
                  "Duruha Margin",
                  _duruhaMarginController,
                  Icons.account_balance_wallet_rounded,
                  "%/kg",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(
    String label,
    TextEditingController controller,
    IconData icon,
    String? suffixText,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: DuruhaInput(
        label: label,
        controller: controller,
        icon: icon,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => _triggerRebuild(),
        suffixText: suffixText,
      ),
    );
  }

  Widget _buildTargetVarietiesSection(ColorScheme scheme, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.targetListingIds != null
                    ? "Adjusting ${widget.targetListingNames?.length ?? widget.targetListingIds!.length} forms"
                    : "Adjusting ${_activeVarieties.length} varieties",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (_activeVarieties.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _activeVarieties.map((v) {
                return Chip(
                  label: Text(v.name),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    setState(() {
                      _activeVarieties.remove(v);
                    });
                  },
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          DuruhaButton(
            onPressed: () => _savePricingUpdates(context),
            text: widget.targetListingIds != null || _activeVarieties.isNotEmpty
                ? "Save Adjustments"
                : "Apply Calculated Prices",
            icon: const Icon(Icons.save_rounded),
          ),
        ],
      ),
    );
  }

  Future<void> _savePricingUpdates(BuildContext context) async {
    // If no target IDs are provided (e.g., when called from an unsaved form),
    // simply return the calculated values so the caller can apply them locally.
    if (_activeVarieties.isEmpty && widget.targetListingIds == null) {
      Navigator.pop(context, {
        'marketPrice': _marketPrice,
        'duruhaAppPrice': _duruhaAppPrice,
        'traderPrice': _traderPrice,
        'farmerPayout': _farmerPayout,
      });
      return;
    }

    try {
      final repo = ProduceAdminRepository(Supabase.instance.client);

      if (widget.targetListingIds != null) {
        await repo.updateListingPrices(
          widget.targetListingIds!,
          _marketPrice,
          _duruhaAppPrice,
          _traderPrice,
          _farmerPayout,
        );
      } else {
        final ids = _activeVarieties.map((v) => v.id).toList();
        await repo.updateVarietyPrices(
          ids,
          _marketPrice,
          _duruhaAppPrice,
          _traderPrice,
          _farmerPayout,
        );
      }

      if (context.mounted) {
        DuruhaSnackBar.show(context, message: 'Prices successfully updated!');
        Navigator.pop(context, true); // Return true to signal refresh
      }
    } catch (e) {
      if (context.mounted) {
        DuruhaSnackBar.show(context, message: 'Error updating prices.');
      }
    }
  }
}
