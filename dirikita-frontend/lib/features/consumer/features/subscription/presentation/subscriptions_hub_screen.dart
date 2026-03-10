import 'package:flutter/material.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/helpers/duruha_color_helper.dart';
import 'package:duruha/core/services/session_service.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/consumer/shared/presentation/consumer_loading_screen.dart';
import '../data/consumer_plan_repository.dart';
import '../domain/consumer_plan_subscription_model.dart';
import 'widgets/subscription_styles.dart';

class SubscriptionsHubScreen extends StatefulWidget {
  const SubscriptionsHubScreen({super.key});

  @override
  State<SubscriptionsHubScreen> createState() => _SubscriptionsHubScreenState();
}

class _SubscriptionsHubScreenState extends State<SubscriptionsHubScreen> {
  final _repository = ConsumerPlanRepository();
  late Future<List<ConsumerPlanSubscription>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _dataFuture = _fetchData();
    });
  }

  Future<List<ConsumerPlanSubscription>> _fetchData() async {
    final consumerId = await SessionService.getRoleId();
    if (consumerId == null) throw Exception('Consumer not found');
    return _repository.getAllPlans(consumerId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DuruhaScaffold(
      appBarTitle: 'My Subscriptions',
      body: FutureBuilder<List<ConsumerPlanSubscription>>(
        future: _dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ConsumerLoadingScreen();
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: cs.error),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load plans\n\${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    DuruhaButton(
                      text: 'Retry',
                      isSmall: true,
                      isOutline: true,
                      isFullWidth: false,
                      onPressed: _loadData,
                    ),
                  ],
                ),
              ),
            );
          }

          final plans = snapshot.data!;
          final active = plans.where((p) => p.isActive).toList();

          return RefreshIndicator(
            onRefresh: () async => _loadData(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Manage your subscriptions',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                if (active.isNotEmpty) ...[
                  _sectionHeader('Active Plan', theme),
                  const SizedBox(height: 12),
                  ...active.map((p) => _buildPlanCard(context, p)),
                  const SizedBox(height: 24),
                ],
                if (plans.isEmpty)
                  _buildEmptyState(context)
                else if (plans.length > active.length) ...[
                  _sectionHeader('History', theme),
                  const SizedBox(height: 12),
                  ...plans
                      .where((p) => !p.isActive)
                      .map((p) => _buildPlanCard(context, p)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title, ThemeData theme) {
    return Text(
      title.toUpperCase(),
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildPlanCard(BuildContext context, ConsumerPlanSubscription plan) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final gradient = SubscriptionStyles.getPlanGradient(plan.planName, cs);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: plan.isActive
              ? cs.primary.withValues(alpha: 0.4)
              : cs.outlineVariant.withValues(alpha: 0.4),
          width: plan.isActive ? 1.5 : 1,
        ),
      ),
      child: DuruhaInkwell(
        variation: InkwellVariation.subtle,
        onTap: () => Navigator.pushNamed(
          context,
          '/consumer/subscriptions/plan_details',
          arguments: plan.cpsId,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.verified_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.planName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Expires: ${DuruhaFormatter.formatDate(plan.endsAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(plan.status),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildInfoChip(
                    context,
                    plan.tier.toUpperCase(),
                    Icons.workspace_premium_outlined,
                  ),
                  _buildInfoChip(
                    context,
                    '${DuruhaFormatter.formatCurrency(plan.billingInterval == 'yearly' ? (plan.monthlyEquivalent ?? plan.fee) : plan.fee)}/mo',
                    Icons.payments_outlined,
                  ),
                  if (plan.qualityLevel != null)
                    _buildInfoChip(
                      context,
                      plan.qualityLevel!,
                      Icons.high_quality_outlined,
                    ),
                ],
              ),
              if (plan.hasCreditLimit && plan.isActive) ...[
                const SizedBox(height: 12),
                _buildCreditBar(plan, theme, cs),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreditBar(
    ConsumerPlanSubscription plan,
    ThemeData theme,
    ColorScheme cs,
  ) {
    final limit = plan.monthlyCreditLimit!;
    final used = limit - plan.remainingCredits;
    final usagePct = limit > 0 ? (used / limit).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Credits',
              style: theme.textTheme.labelSmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            Text(
              '${DuruhaFormatter.formatCurrency(plan.remainingCredits)} remaining',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        DuruhaProgressBar(
          value: usagePct,
          color: usagePct >= 1.0 ? cs.error : cs.secondary,
          backgroundColor: cs.onPrimaryContainer.withValues(alpha: 0.4),
          height: 6,
          borderRadius: BorderRadius.circular(3),
        ),
      ],
    );
  }

  Widget _buildInfoChip(BuildContext context, String label, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color color;
    switch (status.toLowerCase()) {
      case 'active':
        color = isDark
            ? DuruhaColorHelper.completedDark
            : DuruhaColorHelper.completedLight;
        break;
      case 'expired':
        color = isDark
            ? DuruhaColorHelper.pendingDark
            : DuruhaColorHelper.pendingLight;
        break;
      case 'cancelled':
        color = isDark
            ? DuruhaColorHelper.cancelledDark
            : DuruhaColorHelper.cancelledLight;
        break;
      default:
        color = Theme.of(context).colorScheme.onSurfaceVariant;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(
              Icons.card_membership_outlined,
              size: 64,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No Subscriptions Yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "You don't have any active subscription plans.",
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
}
