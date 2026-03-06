import 'package:flutter/material.dart';
import '../../../../../core/widgets/duruha_widgets.dart';

class SubscriptionsHubScreen extends StatelessWidget {
  const SubscriptionsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DuruhaScaffold(
      appBarTitle: 'My Subscriptions',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              'Manage your subscriptions',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            _buildSubscriptionOption(
              context,
              title: "Price Lock",
              subtitle:
                  "View your active and past price lock subscriptions for crops.",
              icon: Icons.lock_outline,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/consumer/subscriptions/pricelock',
                );
              },
            ),
            _buildSubscriptionOption(
              context,
              title: "Future Plan",
              subtitle: "Track and manage your upcoming Future Plans.",
              icon: Icons.calendar_month_outlined,
              onTap: () {
                Navigator.pushNamed(context, '/consumer/subscriptions/cfp');
              },
            ),
            // We can easily add more subscription types here later.
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: DuruhaInkwell(
        variation: InkwellVariation.subtle,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: cs.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
