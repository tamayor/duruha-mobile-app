import 'package:flutter/material.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/consumer/shared/presentation/consumer_loading_screen.dart';

import '../data/cfp_subscription_repository.dart';
import '../domain/consumer_future_plan_subscription_model.dart';

class ConsumerFuturePlanSubscriptionsScreen extends StatefulWidget {
  const ConsumerFuturePlanSubscriptionsScreen({super.key});

  @override
  State<ConsumerFuturePlanSubscriptionsScreen> createState() =>
      _ConsumerFuturePlanSubscriptionsScreenState();
}

class _ConsumerFuturePlanSubscriptionsScreenState
    extends State<ConsumerFuturePlanSubscriptionsScreen> {
  final _repository = ConsumerFuturePlanRepository();

  bool _isLoading = true;
  String? _error;
  List<ConsumerFuturePlanSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _fetchSubscriptions();
  }

  Future<void> _fetchSubscriptions() async {
    try {
      final subscriptions = await _repository.fetchAllFuturePlanSubscriptions();

      if (mounted) {
        setState(() {
          _subscriptions = subscriptions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const DuruhaScaffold(
        appBarTitle: 'Active Plans',
        body: ConsumerLoadingScreen(),
      );
    }

    if (_error != null) {
      return DuruhaScaffold(
        appBarTitle: 'Active Plans',
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              'Error loading plans:\n$_error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      );
    }

    return DuruhaScaffold(
      appBarTitle: 'Active Plans',
      body: _subscriptions.isEmpty
          ? _buildEmptyState(context)
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _subscriptions.length,
              itemBuilder: (context, index) {
                return _buildSubscriptionCard(context, _subscriptions[index]);
              },
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_month_outlined,
            size: 64,
            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Active Future Plans',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You are not subscribed to any Future Plans yet.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(
    BuildContext context,
    ConsumerFuturePlanSubscription sub,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(
            context,
            '/consumer/subscriptions/cfp_details',
            arguments: {'cfpsId': sub.cfpsId, 'subscription': sub},
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      sub.planName ?? 'Future Plan Subscription',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Active',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                context,
                Icons.date_range,
                'Expires On',
                sub.formattedExpiry,
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                context,
                Icons.savings_outlined,
                'Expected Value',
                sub.formattedValueRange ?? 'No limits',
              ),
              const SizedBox(height: 8),
              _buildInfoRow(
                context,
                Icons.autorenew,
                'Billing Interval',
                sub.formattedBillingInterval,
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View Details & Usage',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios, size: 12, color: cs.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }
}
