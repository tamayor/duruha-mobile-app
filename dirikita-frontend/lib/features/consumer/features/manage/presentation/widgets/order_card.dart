import 'package:duruha/core/widgets/badge/duruha_delivery_status_badge.dart';
import 'package:duruha/core/constants/delivery_statuses.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/core/helpers/duruha_color_helper.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:flutter/material.dart';
import '../../domain/order_details_model.dart';
import '../../data/orders_repository.dart';
import '../order_details_screen.dart';

class OrderCard extends StatelessWidget {
  final ConsumerOrderMatch match;

  const OrderCard({super.key, required this.match});

  Widget _buildPaymentWidget(BuildContext context) {
    final pm = match.paymentMethod.toLowerCase();
    final color = Theme.of(context).colorScheme.onSurfaceVariant;

    if (pm.isEmpty || pm == 'not paid') {
      return Text(
        'Pay Now',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: DuruhaColorHelper.getColor(context, 'pending'),
          fontWeight: FontWeight.bold,
        ),
      );
    } else if (pm == 'cash') {
      return Icon(Icons.attach_money, size: 16, color: color);
    } else if (pm == 'card') {
      return Icon(Icons.credit_card, size: 16, color: color);
    } else {
      return Icon(Icons.payment, size: 16, color: color);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final note = match.note;
    final produceNames = match.produceItems
        .map((item) => item.produceEnglishName)
        .toList();
    // Build frequency map: { 'Rice': 2, 'Coconut': 5 }
    final produceCount = <String, int>{};
    for (final name in produceNames) {
      produceCount[name] = (produceCount[name] ?? 0) + 1;
    }

    // Format: "Rice x2, Coconut x5"
    final produceDisplay = produceCount.entries
        .map((e) => e.value > 1 ? '${e.key} (x${e.value})' : e.key)
        .join(', ');

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: DuruhaInkwell(
        variation: InkwellVariation.subtle,
        onTap: () async {
          try {
            final fullMatch = await OrdersRepository().fetchOrderDetails(
              match.order.orderId,
            );
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderDetailsScreen(match: fullMatch),
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              DuruhaSnackBar.showError(
                context,
                'Failed to load order details: $e',
              );
            }
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${match.order.orderId.trimRight().substring(0, 8)} - ${DuruhaFormatter.formatDate(DateTime.parse(match.order.createdAt))}', // Truncate long order IDs
                      maxLines: 1,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSecondary.withValues(alpha: 0.8),
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (match.isPlan)
                        DuruhaStatusBadge(
                          size: BadgeSize.tiny,
                          label: 'PLAN',
                          color: colorScheme
                              .onPrimary, // Using a distinct color for Plan
                          isOutlined: false,
                        ),
                      if (match.isPlan) const SizedBox(width: 8),
                      _buildPaymentWidget(context),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),

              if (note != null && note.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.note_outlined,
                        size: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          note,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              DuruhaTextEmphasis(
                text: produceDisplay,
                breaker: '()',
                mainColor: theme.colorScheme.onPrimary,
                subColor: theme.colorScheme.onSecondary,
                mainWeight: FontWeight.bold,
                subSize: 12,
              ),
              const SizedBox(height: 12),
              if (match.stats != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Payment stats
                    if (match.stats!.paidCount > 0)
                      DuruhaStatusBadge(
                        size: BadgeSize.tiny,
                        color: DuruhaColorHelper.getColor(context, 'completed'),
                        label: "PAID: ${match.stats!.paidCount}",
                        isOutlined: true,
                      ),
                    if (match.stats!.unpaidCount > 0)
                      DuruhaStatusBadge(
                        size: BadgeSize.tiny,
                        color: colorScheme.onError,
                        label: "UNPAID: ${match.stats!.unpaidCount}",
                        isOutlined: true,
                      ),

                    if ((match.stats!.paidCount > 0 ||
                            match.stats!.unpaidCount > 0) &&
                        match.stats!.statusCounts.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          "•",
                          style: TextStyle(
                            color: colorScheme.outlineVariant,
                            fontSize: 10,
                          ),
                        ),
                      ),

                    // Status stats
                    ...match.stats!.statusCounts.entries.map((e) {
                      return DuruhaStatusBadge(
                        size: BadgeSize.tiny,
                        status: e.key,
                        label:
                            "${DeliveryStatus.getDisplayLabel(e.key)}: ${e.value}",
                        isOutlined: true,
                      );
                    }),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
