import 'package:duruha/core/faq/faq.dart';
import 'package:flutter/material.dart';

class TransactionReviewFaq {
  static void show(BuildContext context) {
    final theme = Theme.of(context);

    final content = FaqContent(
      title: 'Pricing & Planning FAQ',
      groups: [
        const FaqGroup(
          sections: [
            FaqSection(
              title: 'Order Mode & Price Lock',
              content:
                  'Order Mode is for immediate needs or scheduling within a 30-day window. '
                  'Prices are estimates based on current market listings. To protect '
                  'yourself from price fluctuations, you can use "Price Lock." '
                  'Immediate payment automatically locks the rate for your scheduled date.',
            ),
            FaqSection(
              title: 'Consumer Future Plan (CFP)',
              content:
                  'CFP Mode is a subscription-based service allowing you to plan for '
                  '1, 3, 6, or 12 months ahead. This signals your demand to farmers '
                  'to secure "Pledges." Pricing is based on market ranges, ensuring '
                  'farmers receive fair value while you secure your long-term supply.',
            ),
            FaqSection(
              title: 'Reliability & Extensions',
              content:
                  'We value your trust. If a planned item (like Rice or Kamote) fails '
                  'to receive a farmer pledge, we refund the amount to your balance '
                  'and automatically extend your Consumer Future Plan subscription '
                  'by 1 month as an apology for the inconvenience.',
            ),
          ],
        ),
      ],
      additionalContent: _buildComparisonTable(theme),
    );

    DuruhaFaqModal.show(context, content);
  }

  static Widget _buildComparisonTable(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Table(
            border: TableBorder.symmetric(
              inside: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
            columnWidths: const {
              0: FlexColumnWidth(1.2),
              1: FlexColumnWidth(1.8),
              2: FlexColumnWidth(1.2),
            },
            children: [
              _tableHeaderRow(theme),
              _tableRow(
                theme,
                'Order (Locked)',
                'Up to 30 days window.',
                'Fixed via immediate pay.',
              ),
              _tableRow(
                theme,
                'Order (Cash)',
                'Up to 30 days window.',
                'Market price at Dispatch.',
              ),
              _tableRow(
                theme,
                'Future Plan',
                'Up to 12 months horizon.',
                'Min/Max Cap applies.',
              ),
              _tableRow(
                theme,
                'Failed Pledge',
                '+1 Month Sub Extension.',
                'Full refund to balance.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  static TableRow _tableHeaderRow(ThemeData theme) {
    return TableRow(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      ),
      children: [
        _tableHeaderCell(theme, 'Feature'),
        _tableHeaderCell(theme, 'Planning Horizon'),
        _tableHeaderCell(theme, 'Price / Protection'),
      ],
    );
  }

  static Widget _tableHeaderCell(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w900,
          fontSize: 9,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  static TableRow _tableRow(
    ThemeData theme,
    String scenario,
    String when,
    String change,
  ) {
    return TableRow(
      children: [
        _tableCell(theme, scenario, isBold: true),
        _tableCell(theme, when),
        _tableCell(theme, change),
      ],
    );
  }

  static Widget _tableCell(
    ThemeData theme,
    String text, {
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 9,
          fontWeight: isBold ? FontWeight.bold : null,
          color: theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}
