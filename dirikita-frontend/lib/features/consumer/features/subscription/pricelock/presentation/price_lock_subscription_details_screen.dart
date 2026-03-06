import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:flutter/material.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/core/widgets/text/duruha_scrollable_text_wrapper.dart';
import '../data/subscription_repository.dart';
import '../domain/price_lock_subscription_model.dart';
import 'package:duruha/features/consumer/shared/presentation/consumer_loading_screen.dart';
import 'package:intl/intl.dart';

class PriceLockSubscriptionDetailsScreen extends StatefulWidget {
  final String cplsId;

  const PriceLockSubscriptionDetailsScreen({super.key, required this.cplsId});

  @override
  State<PriceLockSubscriptionDetailsScreen> createState() =>
      _PriceLockSubscriptionDetailsScreenState();
}

class _PriceLockSubscriptionDetailsScreenState
    extends State<PriceLockSubscriptionDetailsScreen> {
  final SubscriptionRepository _repository = SubscriptionRepository();
  bool _isLoading = true;
  String? _error;
  PriceLockUsageResponse? _data;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await _repository.getConsumerPriceLockUsage(widget.cplsId);
      setState(() {
        _data = res;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const DuruhaScaffold(
        appBarTitle: 'Price Lock Details',
        body: ConsumerLoadingScreen(),
      );
    }

    if (_error != null || _data == null) {
      return DuruhaScaffold(
        appBarTitle: 'Price Lock Details',
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: ${_error ?? 'Unknown error'}'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _fetchData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final d = _data!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textTheme = theme.textTheme;

    return DuruhaScaffold(
      appBarTitle: 'Price Lock Details',
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeaderCard(d, theme, cs),
                  const SizedBox(height: 16),
                  _buildUsageSummaryCard(d, theme, cs),
                  const SizedBox(height: 24),
                  Text(
                    'Usage Details',
                    style: textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (d.usage.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          'No usage data found for this subscription yet.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ...d.usage.map(
                    (item) => _buildUsageItemCard(item, theme, cs),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(
    PriceLockUsageResponse d,
    ThemeData theme,
    ColorScheme cs,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
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
                    d.planName,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(d.status).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getStatusColor(d.status)),
                  ),
                  child: Text(
                    d.status.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _getStatusColor(d.status),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow(
              theme,
              Icons.calendar_today,
              'Valid',
              '${DateFormat('MMM dd, yyyy').format(d.startsAt)} - ${DateFormat('MMM dd, yyyy').format(d.endsAt)}',
            ),
            const SizedBox(height: 8),
            _infoRow(
              theme,
              Icons.payment,
              'Fee',
              '${DuruhaFormatter.formatCurrency(d.fee)} / ${d.billingInterval}',
            ),
            if (d.lastResetDate != null) ...[
              const SizedBox(height: 8),
              _infoRow(
                theme,
                Icons.refresh,
                'Last Reset',
                DateFormat('MMM dd, yyyy • hh:mm a').format(d.lastResetDate!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUsageSummaryCard(
    PriceLockUsageResponse d,
    ThemeData theme,
    ColorScheme cs,
  ) {
    double usagePercent = d.monthlyCreditLimit > 0
        ? d.usedCredits / d.monthlyCreditLimit
        : 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Credits Used',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${DuruhaFormatter.formatNumber(d.usedCredits)} / ${DuruhaFormatter.formatNumber(d.monthlyCreditLimit)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: cs.onSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DuruhaProgressBar(
              value: usagePercent,
              color: usagePercent >= 1.0 ? Colors.red : cs.onTertiaryContainer,
              backgroundColor: cs.surfaceContainerHighest,
              height: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${DuruhaFormatter.formatNumber(d.remainingCredits)} credits remaining',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageItemCard(
    PriceLockUsageItem item,
    ThemeData theme,
    ColorScheme cs,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 16,
                      color: cs.onPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.form.isNotEmpty ? item.form : 'Item Details',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (item.dateNeeded != null)
                  Text(
                    DateFormat('MMM dd').format(item.dateNeeded!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Qty: ${item.quantity}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (item.isAny)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cs.tertiaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Any Variety',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onTertiaryContainer,
                      ),
                    ),
                  ),
                const Spacer(),
                Text(
                  '-${item.groupCreditsUsed} credits',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.red[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            if (item.selectedVarieties.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'Selected Varieties:',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              ...item.selectedVarieties.map(
                (v) => _buildVarietyRow(v, theme, cs),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVarietyRow(
    PriceLockSelectedVariety v,
    ThemeData theme,
    ColorScheme cs,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DuruhaInkwell(
                variation: InkwellVariation.subtle,
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/consumer/manage/order',
                    arguments: v.orderId,
                  );
                },
                child: Row(
                  children: [
                    Text(
                      'Order ID: ${v.orderId.substring(0, 12)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSecondary,

                        fontSize: 10,
                      ),
                    ),
                    Icon(Icons.arrow_forward, size: 12, color: cs.onSecondary),
                  ],
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DuruhaScrollableTextWrapper(
                  child: Row(
                    children: [
                      Icon(Icons.eco, size: 14, color: cs.onSecondary),
                      const SizedBox(width: 4),
                      Text(
                        v.produceName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSecondary,
                        ),
                      ),
                      Text(
                        ' - ',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onSecondary,
                        ),
                      ),
                      Text(
                        v.varietyName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (v.priceLock != null)
                Text(
                  'Locked: ${DuruhaFormatter.formatCurrency(v.priceLock!)}/${v.baseUnit}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: cs.onTertiary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (v.hasPaid && v.finalPrice != null)
                Text(
                  'Paid: ${DuruhaFormatter.formatCurrency(v.finalPrice!)}/${v.baseUnit}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.green,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(ThemeData t, IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: t.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: t.textTheme.bodyMedium?.copyWith(
            color: t.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: t.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'paused':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}
