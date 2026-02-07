import 'package:duruha/core/helpers/duruha_status_helper.dart';
import 'package:duruha/core/widgets/duruha_modal_bottom_sheet.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:duruha/features/consumer/features/market/domain/market_order_model.dart';
import 'package:duruha/features/consumer/features/orders/presentation/widgets/order_tracking_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class OrderTrackingCard extends StatelessWidget {
  final MarketOrder order;

  const OrderTrackingCard({super.key, required this.order});

  static const Color duruhaGreen = Color(0xFF2E7D32);
  static const Color ledgerPaperColor = Color(0xFFFDFBF7);

  @override
  Widget build(BuildContext context) {
    // Find the current active (incomplete) batch
    final currentBatch = order.batches?.firstWhere(
      (b) => b['status'] != DuruhaOrderStatus.done,
      orElse: () => order.batches != null && order.batches!.isNotEmpty
          ? order.batches!.last
          : {},
    );

    final currentBatchStatus =
        currentBatch?['status'] as DuruhaOrderStatus? ?? order.orderStatus;

    final statusLabel = DuruhaStatus.getOrderStatusLabel(currentBatchStatus);
    final statusColor = DuruhaStatus.getOrderStatusColor(
      context,
      currentBatchStatus,
    );
    final frequencyLabel = order.supplySchedule?.frequency.label ?? 'Once';

    // Calculate delivery progress
    final completedDeliveries =
        order.batches
            ?.where((b) => b['status'] == DuruhaOrderStatus.done)
            .length ??
        0;
    final totalDeliveries = order.supplySchedule?.occurrences ?? 1;
    final displayTotal = totalDeliveries == -1 ? '∞' : '$totalDeliveries';

    final progressLabel = '$completedDeliveries / $displayTotal deliveries';

    final isRange = order.minSubtotal != order.subtotal;
    final pricingLabel = isRange
        ? '${DuruhaFormatter.formatCurrency(order.minSubtotal)} - ${DuruhaFormatter.formatCurrency(order.subtotal)}'
        : DuruhaFormatter.formatCurrency(order.subtotal);

    final isBatchPaused =
        currentBatch != null &&
        (currentBatch['status'] == DuruhaOrderStatus.paused);
    final currentBatchDate = currentBatch?['date'] as DateTime?;

    return Card(
      elevation: 2,
      color: ledgerPaperColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: InkWell(
        onTap: () => DuruhaModalBottomSheet.show(
          context: context,
          title: 'Order Tracking',
          subtitle: 'Batch #${order.batchId}',
          icon: Icons.track_changes,
          child: OrderTrackingDetailSheet(order: order),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order ID',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '#${order.id.split('_').last}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ordered: ${DateFormat('MMM dd, yyyy').format(order.createdAt)}',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  _buildStatusChip(statusLabel, statusColor),
                ],
              ),
              const SizedBox(height: 16),

              // Produce Summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.items
                              .map((i) => i.produce.nameEnglish)
                              .join(' & '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$frequencyLabel • $progressLabel',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildProgressGrid(context, currentBatchStatus),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        pricingLabel,
                        style: GoogleFonts.poppins(
                          fontSize: isRange ? 13 : 15,
                          fontWeight: FontWeight.bold,
                          color: duruhaGreen,
                        ),
                      ),
                      if (isRange)
                        Text(
                          'Estimated Range',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Estimated Delivery / Paused Status (Current Batch)
              Row(
                children: [
                  if (isBatchPaused)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.pause_circle_outline,
                            size: 14,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'DELIVERY PAUSED',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange[800],
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (currentBatchDate != null)
                    Row(
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Est. Delivery: ${DateFormat('MMM dd, yyyy').format(currentBatchDate)}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                ],
              ),

              const Divider(height: 32),

              // Action Link
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tap to view tracking history',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: duruhaGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: duruhaGreen,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildProgressGrid(
    BuildContext context,
    DuruhaOrderStatus currentStatus,
  ) {
    final stages = [
      DuruhaOrderStatus.matched,
      DuruhaOrderStatus.harvestSecured,
      DuruhaOrderStatus.toSupply,
      DuruhaOrderStatus.done,
    ];

    // If searching/processing, they are "before" the dots
    int activeIndex = stages.indexOf(currentStatus);
    if (currentStatus == DuruhaOrderStatus.searching ||
        currentStatus == DuruhaOrderStatus.processing) {
      activeIndex = -1;
    }

    return Row(
      children: stages.asMap().entries.map((entry) {
        final index = entry.key;
        final stage = entry.value;
        final isPast = index <= activeIndex;

        return Expanded(
          child: Container(
            height: 3,
            margin: EdgeInsets.only(right: index == stages.length - 1 ? 0 : 4),
            decoration: BoxDecoration(
              color: isPast
                  ? DuruhaStatus.getOrderStatusColor(context, stage)
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }).toList(),
    );
  }
}
