import 'package:flutter/material.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import '../data/subscription_repository.dart';
import '../domain/price_lock_subscription_model.dart';
import 'package:duruha/features/consumer/shared/presentation/consumer_loading_screen.dart';

class PriceLockSubscriptionsScreen extends StatefulWidget {
  const PriceLockSubscriptionsScreen({super.key});

  @override
  State<PriceLockSubscriptionsScreen> createState() =>
      _PriceLockSubscriptionsScreenState();
}

class _PriceLockSubscriptionsScreenState
    extends State<PriceLockSubscriptionsScreen> {
  final _repository = SubscriptionRepository();
  late Future<List<PriceLockSubscription>> _subscriptionsFuture;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  void _loadSubscriptions() {
    setState(() {
      _subscriptionsFuture = _repository.getConsumerPriceLockSubscriptions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DuruhaScaffold(
      appBarTitle: 'Price Lock Subscriptions',
      body: FutureBuilder<List<PriceLockSubscription>>(
        future: _subscriptionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ConsumerLoadingScreen();
          } else if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Failed to load subscriptions\n${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadSubscriptions,
                    child: const Text('Retry'),
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
    PriceLockSubscription sub,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final totalCredits = sub.monthlyCreditLimit;
    final usagePercent = totalCredits > 0
        ? sub.usedCredits / totalCredits
        : 0.0;

    return Container(
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
            '/consumer/subscriptions/pricelock_details',
            arguments: sub.cplsId,
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
                      sub.cplsId,
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
              Text(
                sub.planName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onPrimary,
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
                value: usagePercent,
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
