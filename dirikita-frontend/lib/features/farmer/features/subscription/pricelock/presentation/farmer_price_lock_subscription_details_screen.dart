import 'package:flutter/material.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import '../data/farmer_subscription_repository.dart';
import '../domain/farmer_price_lock_usage_model.dart';
import 'package:duruha/features/farmer/shared/presentation/farmer_loading_screen.dart';

class FarmerPriceLockSubscriptionDetailsScreen extends StatefulWidget {
  final String fplsId;
  const FarmerPriceLockSubscriptionDetailsScreen({
    super.key,
    required this.fplsId,
  });

  @override
  State<FarmerPriceLockSubscriptionDetailsScreen> createState() =>
      _FarmerPriceLockSubscriptionDetailsScreenState();
}

class _FarmerPriceLockSubscriptionDetailsScreenState
    extends State<FarmerPriceLockSubscriptionDetailsScreen> {
  final _repository = FarmerSubscriptionRepository();
  late Future<FarmerPriceLockUsageDetail> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  void _loadDetails() {
    setState(() {
      _detailsFuture = _repository.getFarmerPriceLockUsageById(widget.fplsId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DuruhaScaffold(
      appBarTitle: 'Subscription Details',
      body: FutureBuilder<FarmerPriceLockUsageDetail>(
        future: _detailsFuture,
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
                    'Failed to load details\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  DuruhaButton(
                    text: 'Retry',
                    isSmall: true,
                    isOutline: true,
                    isFullWidth: false,
                    onPressed: _loadDetails,
                  ),
                ],
              ),
            );
          }

          final detail = snapshot.data;
          if (detail == null) {
            return const Center(child: Text("Details not found."));
          }

          return RefreshIndicator(
            onRefresh: () async => _loadDetails(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  _buildHeaderSheet(context, detail),
                  const SizedBox(height: 16),
                  _buildUsageList(context, detail),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderSheet(
    BuildContext context,
    FarmerPriceLockUsageDetail detail,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final usagePercent = detail.monthlyCreditLimit > 0
        ? detail.usedCredits / detail.monthlyCreditLimit
        : 0.0;

    return Container(
      width: double.infinity,
      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  detail.planName,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(detail.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getStatusColor(detail.status)),
                ),
                child: Text(
                  detail.status.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _getStatusColor(detail.status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Plan Details Row
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  theme,
                  Icons.calendar_month,
                  'Billing',
                  detail.billingInterval,
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  theme,
                  Icons.payments_outlined,
                  'Fee',
                  DuruhaFormatter.formatCurrency(detail.fee.toDouble()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  theme,
                  Icons.play_circle_outline,
                  'Starts',
                  DuruhaFormatter.formatDate(detail.startsAt),
                ),
              ),
              Expanded(
                child: _buildInfoItem(
                  theme,
                  Icons.stop_circle_outlined,
                  'Ends',
                  DuruhaFormatter.formatDate(detail.endsAt),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // Credits Usage Section
          Text(
            'Usage this period',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Used Credits',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              Text(
                'Total Limit',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DuruhaFormatter.formatCurrency(detail.usedCredits.toDouble()),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: usagePercent >= 1.0 ? Colors.red : cs.onSurface,
                ),
              ),
              Text(
                DuruhaFormatter.formatCurrency(
                  detail.monthlyCreditLimit.toDouble(),
                ),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DuruhaProgressBar(
            value: usagePercent.toDouble(),
            color: usagePercent >= 1.0 ? Colors.red : cs.primary,
            backgroundColor: cs.surfaceContainerHighest,
            height: 12,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  theme,
                  'Remaining Credits',
                  DuruhaFormatter.formatCurrency(
                    detail.remainingCredits.toDouble(),
                  ),
                  Icons.account_balance_wallet_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsageList(
    BuildContext context,
    FarmerPriceLockUsageDetail detail,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final usages = detail.usage;

    if (usages.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.history_toggle_off,
                size: 48,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'No usage recorded for this subscription yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Text(
              'Locked Offers',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: usages.length,
            itemBuilder: (context, index) {
              final usage = usages[index];
              return _buildUsageCard(context, usage);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUsageCard(BuildContext context, FarmerOfferUsage usage) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: DuruhaInkwell(
        onTap: () async {
          final result = await Navigator.pushNamed(
            context,
            '/farmer/manage/offer',
            arguments: usage.offerId,
          );
          if (result == true && mounted) {
            _loadDetails();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: cs.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          usage.varietyName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                usage.produceName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                            if (usage.allocationsCount >= 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.link,
                                      size: 12,
                                      color: cs.onPrimaryContainer,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${usage.allocationsCount}',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: cs.onPrimaryContainer,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '- ${DuruhaFormatter.formatCurrency(usage.totalPriceLockCredit.toDouble())}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.error,
                        ),
                      ),
                      Text(
                        'Credits Locked',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSmallInfo(
                    theme,
                    'Qty Locked',
                    '${DuruhaFormatter.formatCompactNumber(usage.quantity.toDouble())} ${usage.baseUnit}',
                  ),
                  _buildSmallInfo(
                    theme,
                    'Qty Remaining',
                    '${DuruhaFormatter.formatCompactNumber(usage.remainingQuantity.toDouble())} ${usage.baseUnit}',
                  ),
                  _buildSmallInfo(
                    theme,
                    'Credits Unused',
                    DuruhaFormatter.formatCurrency(
                      usage.remainingPriceLockCredit.toDouble(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    ThemeData theme,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallInfo(ThemeData theme, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    ThemeData theme,
    String label,
    String value,
    IconData icon,
  ) {
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'expired':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
