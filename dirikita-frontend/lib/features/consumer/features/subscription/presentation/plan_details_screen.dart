import 'package:flutter/material.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/helpers/duruha_color_helper.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/consumer/shared/presentation/consumer_loading_screen.dart';
import '../data/consumer_plan_repository.dart';
import '../domain/consumer_plan_subscription_model.dart';
import 'widgets/subscription_config_card.dart';

class ConsumerPlanDetailsScreen extends StatefulWidget {
  final String cpsId;

  const ConsumerPlanDetailsScreen({super.key, required this.cpsId});

  @override
  State<ConsumerPlanDetailsScreen> createState() =>
      _ConsumerPlanDetailsScreenState();
}

class _ConsumerPlanDetailsScreenState extends State<ConsumerPlanDetailsScreen> {
  // We fetch all plans and find by ID since the view only shows the active one
  bool _isLoading = true;
  String? _error;
  ConsumerPlanSubscription? _plan;

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
      final response = await ConsumerPlanRepository().getSubscriptionById(
        widget.cpsId,
      );
      if (mounted) {
        setState(() {
          _plan = response;
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
        appBarTitle: 'Plan Details',
        body: ConsumerLoadingScreen(),
      );
    }

    if (_error != null || _plan == null) {
      return DuruhaScaffold(
        appBarTitle: 'Plan Details',
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text('Error: \${_error ?? \'Unknown error\'}'),
              const SizedBox(height: 16),
              DuruhaButton(
                text: 'Retry',
                isSmall: true,
                isOutline: true,
                isFullWidth: false,
                onPressed: _fetchData,
              ),
            ],
          ),
        ),
      );
    }

    final plan = _plan!;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DuruhaScaffold(
      appBarTitle: 'Plan Details',
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SubscriptionConfigCard(
                    title: plan.planName,
                    fee: plan.billingInterval == 'yearly'
                        ? (plan.monthlyEquivalent ?? plan.fee)
                        : plan.fee,
                    interval: 'month',
                    isActive: plan.isActive,
                    activeLabel: plan.status.toUpperCase(),
                    details: {
                      'Tier': plan.tier,
                      'Billing': plan.billingInterval,
                      'Valid From': DuruhaFormatter.formatDate(plan.startsAt),
                      'Expires On': DuruhaFormatter.formatDate(plan.endsAt),
                    },
                    onSelect: () {},
                  ),
                  const SizedBox(height: 16),
                  if (plan.hasCreditLimit) ...[
                    _buildCreditCard(plan, theme, cs),
                    const SizedBox(height: 16),
                  ],
                  if (plan.hasOrderValueLimits || plan.qualityLevel != null)
                    _buildBenefitsCard(plan, theme, cs),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditCard(
    ConsumerPlanSubscription plan,
    ThemeData theme,
    ColorScheme cs,
  ) {
    final limit = plan.monthlyCreditLimit!;
    final used = limit - plan.remainingCredits;
    final usagePct = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Monthly Credits',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${DuruhaFormatter.formatNumber(used.toInt())} / ${DuruhaFormatter.formatNumber(limit.toInt())}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DuruhaProgressBar(
              value: usagePct,
              color: usagePct >= 1.0 ? cs.error : cs.primary,
              backgroundColor: cs.surfaceContainerHighest,
              height: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${DuruhaFormatter.formatCurrency(plan.remainingCredits)} remaining',
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

  Widget _buildBenefitsCard(
    ConsumerPlanSubscription plan,
    ThemeData theme,
    ColorScheme cs,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Plan Benefits',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 24),
            if (plan.qualityLevel != null)
              _detailRow(
                'Quality Level',
                plan.qualityLevel!,
                theme,
                cs,
                icon: Icons.high_quality_outlined,
              ),
            if (plan.minOrderValue != null && plan.minOrderValue! > 0)
              _detailRow(
                'Min Order Value',
                DuruhaFormatter.formatCurrency(plan.minOrderValue!),
                theme,
                cs,
                icon: Icons.arrow_downward,
              ),
            if (plan.maxOrderValue != null && plan.maxOrderValue! > 0)
              _detailRow(
                'Max Order Value',
                DuruhaFormatter.formatCurrency(plan.maxOrderValue!),
                theme,
                cs,
                icon: Icons.arrow_upward,
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value,
    ThemeData theme,
    ColorScheme cs, {
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: cs.primary),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
