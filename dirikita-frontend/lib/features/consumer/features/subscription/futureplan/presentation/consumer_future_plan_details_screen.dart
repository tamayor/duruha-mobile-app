import 'package:flutter/material.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/features/consumer/shared/presentation/consumer_loading_screen.dart';
import '../data/cfp_subscription_repository.dart';
import '../domain/consumer_future_plan_subscription_model.dart';

class ConsumerFuturePlanDetailsScreen extends StatefulWidget {
  final String cfpsId;
  final ConsumerFuturePlanSubscription? subscription;

  const ConsumerFuturePlanDetailsScreen({
    super.key,
    required this.cfpsId,
    this.subscription,
  });

  @override
  State<ConsumerFuturePlanDetailsScreen> createState() =>
      _ConsumerFuturePlanDetailsScreenState();
}

class _ConsumerFuturePlanDetailsScreenState
    extends State<ConsumerFuturePlanDetailsScreen> {
  final _repository = ConsumerFuturePlanRepository();
  bool _isLoadingUsage = true;
  String? _error;
  FuturePlanUsage? _usage;
  ConsumerFuturePlanSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = widget.subscription;
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      if (_sub == null) {
        // Fallback or refresh subscriptions if needed,
        // but for now we expect the sub or we might need a fetchById
        // For simplicity, let's assume we fetch all and find it,
        // or just rely on passed sub for header.
        final subs = await _repository.fetchAllFuturePlanSubscriptions();
        _sub = subs.firstWhere((element) => element.cfpsId == widget.cfpsId);
      }

      final usage = await _repository.fetchFuturePlanUsage(widget.cfpsId);

      if (mounted) {
        setState(() {
          _usage = usage;
          _isLoadingUsage = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoadingUsage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (_sub == null && _isLoadingUsage) {
      return const DuruhaScaffold(
        appBarTitle: 'Plan Details',
        body: ConsumerLoadingScreen(),
      );
    }

    return DuruhaScaffold(
      appBarTitle: _sub?.planName ?? 'Plan Details',
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_sub != null) _buildHeaderCard(context, _sub!),
                    const SizedBox(height: 24),
                    Text(
                      'Plan Usage',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingUsage)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_error != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text(
                            'Error loading usage: $_error',
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else if (_usage == null || _usage!.orders.isEmpty)
                      _buildEmptyUsage(context)
                    else
                      ..._usage!.orders.map(
                        (order) => _buildOrderSection(context, order),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    ConsumerFuturePlanSubscription sub,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInfoRow(
              context,
              Icons.date_range,
              'Expires On',
              sub.formattedExpiry,
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              Icons.savings_outlined,
              'Expected Value',
              sub.formattedValueRange ?? 'No limits',
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              context,
              Icons.autorenew,
              'Billing Interval',
              sub.formattedBillingInterval,
            ),
          ],
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
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 12),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyUsage(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No items ordered under this plan yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSection(BuildContext context, FuturePlanOrder order) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              Navigator.pushNamed(
                context,
                '/consumer/manage/order',
                arguments: order.orderId,
              );
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.shopping_bag_outlined,
                      size: 20,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${order.orderShortId}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${order.formattedDate} • ${order.paymentMethod}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Produces',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${order.totalProduces}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...order.produces.map(
                  (produce) => _buildProduceItem(context, produce),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProduceItem(BuildContext context, FuturePlanProduce produce) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(Icons.eco_outlined, size: 16, color: cs.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              produce.produceName,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (produce.quality != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: cs.secondaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                produce.quality!,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cs.onSecondaryContainer,
                  fontSize: 10,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            'x${produce.recurrence}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: cs.onTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
