import 'package:flutter/material.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/admin/price_calculator/presentation/price_calculator_screen.dart';
import 'admin_produce_form_models.dart';

class AdminListingLevelWidget extends StatelessWidget {
  final FormVariety variety;
  final FormListing listing;
  final int index;
  final VoidCallback onRemove;

  const AdminListingLevelWidget({
    super.key,
    required this.variety,
    required this.listing,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Listing #${index + 1}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Row(
                children: [
                  Tooltip(
                    message: "Open Price Calculator",
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.calculate_outlined,
                        size: 20,
                        color: scheme.primary,
                      ),
                      onPressed: () => _openCalculator(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(Icons.close, size: 18, color: scheme.error),
                    onPressed: onRemove,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          DuruhaTextField(
            controller: listing.produceForm,
            label: "Produce Form (e.g. Whole, Peeled)",
            icon: Icons.category,
            isRequired: false,
          ),
          Row(
            children: [
              Expanded(
                child: DuruhaTextField(
                  controller: listing.farmerToTraderPrice,
                  label: "Farmer -> Trader",
                  icon: Icons.money,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DuruhaTextField(
                  controller: listing.farmerToDuruhaPrice,
                  label: "Farmer -> Duruha",
                  icon: Icons.account_balance_wallet,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: DuruhaTextField(
                  controller: listing.duruhaToConsumerPrice,
                  label: "Duruha -> Consumer",
                  icon: Icons.storefront,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DuruhaTextField(
                  controller: listing.marketToConsumerPrice,
                  label: "Market -> Consumer",
                  icon: Icons.shopping_basket,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openCalculator(BuildContext context) async {
    // Navigate to PriceCalculatorScreen and await the calculated results
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PriceCalculatorScreen(
          initialMarketPrice: double.tryParse(
            listing.marketToConsumerPrice.text,
          ),
          initialTraderPrice: double.tryParse(listing.farmerToTraderPrice.text),
          initialFarmerPrice: double.tryParse(listing.farmerToDuruhaPrice.text),
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic> && context.mounted) {
      // Update form controllers with calculated prices
      listing.marketToConsumerPrice.text = (result['marketPrice'] as double)
          .toStringAsFixed(2);
      listing.farmerToTraderPrice.text = (result['traderPrice'] as double)
          .toStringAsFixed(2);
      listing.farmerToDuruhaPrice.text = (result['farmerPayout'] as double)
          .toStringAsFixed(2);
      listing.duruhaToConsumerPrice.text = (result['duruhaAppPrice'] as double)
          .toStringAsFixed(2);
    }
  }
}
