import 'package:flutter/material.dart';
import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:duruha/core/widgets/duruha_button.dart';
import 'pledge_small_components.dart';

class PledgeHeaderSummary extends StatelessWidget {
  final int daysRemaining;
  final HarvestPledge pledge;
  final double totalInputs;
  final String currentStatus;
  final Produce? produce;
  final VoidCallback onRecordExpenses;

  const PledgeHeaderSummary({
    super.key,
    required this.daysRemaining,
    required this.pledge,
    required this.totalInputs,
    required this.currentStatus,
    this.produce,
    required this.onRecordExpenses,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    double calculatePotentialEarnings() {
      if (produce == null || produce!.availableVarieties.isEmpty) return 0.0;

      // If we have specific varieties for this pledge, use their average price
      if (pledge.variants.isNotEmpty) {
        final selectedPrices = produce!.availableVarieties
            .where((v) => pledge.variants.contains(v.name))
            .map((v) => v.price)
            .toList();

        if (selectedPrices.isNotEmpty) {
          final avgPrice =
              selectedPrices.reduce((a, b) => a + b) / selectedPrices.length;
          return avgPrice * pledge.quantity;
        }
      }

      // Fallback to first variety price
      return produce!.availableVarieties.first.price * pledge.quantity;
    }

    final double earnings = (currentStatus == 'Sold' || currentStatus == 'Done')
        ? (pledge.sellingPrice ?? 0.0)
        : calculatePotentialEarnings();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withAlpha(40),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              daysRemaining > 0
                  ? Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              "$daysRemaining",
                              style: theme.textTheme.displayLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 64,
                                letterSpacing: -2,
                                height: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "DAYS",
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white.withAlpha(180),
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          "UNTIL HARVEST",
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white.withAlpha(150),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Icon(
                          pledge.currentStatus == "Sold"
                              ? Icons.check_circle_outline_rounded
                              : Icons.auto_awesome_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          pledge.currentStatus == "Sold"
                              ? "SOLD"
                              : "HARVEST READY",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  PledgeStat(
                    label: "Min. Quantity",
                    value:
                        "${pledge.quantity.toStringAsFixed(0)} ${pledge.unit}",
                    icon: Icons.shopping_basket_outlined,
                  ),
                  PledgeStat(
                    label: "Invested",
                    value: "₱${totalInputs.toStringAsFixed(0)}",
                    icon: Icons.payments_outlined,
                  ),
                ],
              ),
              if (produce != null) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(color: Colors.white24, height: 1),
                ),
                Column(
                  children: [
                    Text(
                      (currentStatus == 'Sold' || currentStatus == 'Done')
                          ? "Total Earnings"
                          : "Potential Earnings",
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimary.withAlpha(150),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "₱${(earnings - totalInputs).toStringAsFixed(0)}",
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 32,
                      ),
                    ),
                    Text(
                      (currentStatus == 'Sold' || currentStatus == 'Done')
                          ? "Based on final sale price minus expenses"
                          : "Based on current market guide price",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimary.withAlpha(180),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        DuruhaButton(
          text: "Record Farming Expenses",
          isOutline: true,
          onPressed: onRecordExpenses,
        ),
      ],
    );
  }
}
