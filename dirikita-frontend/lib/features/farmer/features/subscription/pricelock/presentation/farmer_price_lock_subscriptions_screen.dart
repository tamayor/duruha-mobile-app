import 'package:flutter/material.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import '../data/farmer_subscription_repository.dart';
import '../domain/farmer_price_lock_subscription_model.dart';
import 'package:duruha/features/farmer/shared/presentation/farmer_loading_screen.dart';

class FarmerPriceLockSubscriptionsScreen extends StatefulWidget {
  const FarmerPriceLockSubscriptionsScreen({super.key});

  @override
  State<FarmerPriceLockSubscriptionsScreen> createState() =>
      _FarmerPriceLockSubscriptionsScreenState();
}

class _FarmerPriceLockSubscriptionsScreenState
    extends State<FarmerPriceLockSubscriptionsScreen> {
  final _repository = FarmerSubscriptionRepository();
  late Future<List<FarmerPriceLockSubscription>> _subscriptionsFuture;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  void _loadSubscriptions() {
    setState(() {
      _subscriptionsFuture = _repository.getFarmerPriceLockSubscriptions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DuruhaScaffold(
      appBarTitle: 'Price Lock Subscriptions',
      body: FutureBuilder<List<FarmerPriceLockSubscription>>(
        future: _subscriptionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const FarmerLoadingScreen();
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load subscriptions\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  DuruhaButton(
                    text: 'Retry',
                    isSmall: true,
                    isOutline: true,
                    isFullWidth: false,
                    onPressed: _loadSubscriptions,
                  ),
                ],
              ),
            );
          }

          final subscriptions = snapshot.data ?? [];

          if (subscriptions.isEmpty) {
            return const Center(
              child: Text("You have no active subscriptions."),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: subscriptions.length,
            itemBuilder: (context, index) {
              return _buildSubscriptionCard(context, subscriptions[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildSubscriptionCard(
    BuildContext context,
    FarmerPriceLockSubscription sub,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final totalCredits = sub.monthlyCreditLimit;
    final usagePercent = totalCredits > 0
        ? sub.usedCredits / totalCredits
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline),
      ),
      child: DuruhaInkwell(
        variation: InkwellVariation.subtle,
        onTap: () {
          Navigator.pushNamed(
            context,
            '/farmer/subscriptions/pricelock_details',
            arguments: sub.fplsId,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      sub.fplsId,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        color: cs.onSecondary,
                      ),
                    ),
                  ),
                  _buildStatusChip(sub.status, theme),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                sub.planName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              _buildDateRow(
                theme,
                Icons.calendar_today,
                'Starts:',
                sub.startsAt,
              ),
              const SizedBox(height: 4),
              _buildDateRow(theme, Icons.event, 'Ends:', sub.endsAt),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Credits Usage',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${DuruhaFormatter.formatCurrency(sub.usedCredits.toDouble())} / ${DuruhaFormatter.formatCurrency(totalCredits.toDouble())}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: usagePercent >= 1.0 ? Colors.red : cs.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DuruhaProgressBar(
                value: usagePercent.toDouble(),
                color: usagePercent >= 1.0
                    ? Colors.red
                    : cs.onTertiaryContainer,
                backgroundColor: cs.surfaceContainerHighest,
                height: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateRow(
    ThemeData theme,
    IconData icon,
    String label,
    DateTime date,
  ) {
    return Row(
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          DuruhaFormatter.formatDate(date),
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status, ThemeData theme) {
    Color bgColor;
    Color fgColor;

    switch (status.toLowerCase()) {
      case 'active':
        bgColor = Colors.green.withValues(alpha: 0.1);
        fgColor = Colors.green[700]!;
        break;
      case 'expired':
        bgColor = Colors.orange.withValues(alpha: 0.1);
        fgColor = Colors.orange[800]!;
        break;
      case 'cancelled':
        bgColor = Colors.red.withValues(alpha: 0.1);
        fgColor = Colors.red[700]!;
        break;
      default:
        bgColor = theme.colorScheme.surfaceContainerHighest;
        fgColor = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: fgColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
