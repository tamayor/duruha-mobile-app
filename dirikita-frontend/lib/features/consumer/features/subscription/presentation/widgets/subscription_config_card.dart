import 'package:flutter/material.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'subscription_styles.dart';

class SubscriptionConfigCard extends StatelessWidget {
  final String title;
  final double fee;
  final String interval;
  final String? description;
  final Map<String, String> details; // e.g., {'Spend Limit': 'P100 - P500'}
  final VoidCallback onSelect;
  final bool isActive;
  final String? activeLabel;
  final Widget? footer;

  const SubscriptionConfigCard({
    super.key,
    required this.title,
    required this.fee,
    required this.interval,
    this.description,
    this.details = const {},
    required this.onSelect,
    this.isActive = false,
    this.activeLabel = 'CURRENT',
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final gradient = SubscriptionStyles.getPlanGradient(title, cs);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: isActive
            ? Border.all(
                color: theme.colorScheme.onPrimaryContainer.withValues(
                  alpha: 0.5,
                ),
                width: 2,
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Background patterns/glass effect
            Positioned(
              right: -50,
              top: -50,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.onSecondary.withValues(alpha: 0.1),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.toUpperCase(),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer
                                  .withValues(alpha: 0.8),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (isActive)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: theme.colorScheme.onPrimaryContainer
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                activeLabel!,
                                style: TextStyle(
                                  color: theme.colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          if (fee > 0) ...[
                            Text(
                              DuruhaFormatter.formatCurrency(fee),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: theme.colorScheme.onTertiaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '/ $interval',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onTertiaryContainer
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer
                            .withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: details.entries
                              .map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        e.key.toUpperCase(),
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSecondaryContainer
                                                  .withValues(alpha: 0.7),
                                              letterSpacing: 1,
                                              fontSize: 9,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        e.value,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSecondaryContainer,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Monospace',
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      if (!isActive)
                        DuruhaInkwell(
                          variation: InkwellVariation.glass,
                          onTap: onSelect,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.primaryContainer
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              'SELECT',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (footer != null) ...[const SizedBox(height: 16), footer!],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
