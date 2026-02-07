import 'package:duruha/core/helpers/duruha_status_helper.dart';
import 'package:duruha/features/consumer/features/market/domain/market_order_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:duruha/core/helpers/duruha_formatter.dart';
import 'package:intl/intl.dart';
import 'package:duruha/features/consumer/features/orders/data/order_tracking_repository.dart';

class OrderTrackingDetailSheet extends StatefulWidget {
  final MarketOrder order;

  const OrderTrackingDetailSheet({super.key, required this.order});

  @override
  State<OrderTrackingDetailSheet> createState() =>
      _OrderTrackingDetailSheetState();
}

class _OrderTrackingDetailSheetState extends State<OrderTrackingDetailSheet> {
  static const Color duruhaGreen = Color(0xFF2E7D32);
  final ScrollController _batchScrollController = ScrollController();

  // Track if we've already done the initial scroll
  bool _hasScrolledToLatest = false;

  // Map to store keys for each batch card for precise scrolling
  final Map<int, GlobalKey> _batchKeys = {};

  @override
  void dispose() {
    _batchScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Produce Info Section
        _buildProduceInfo(),
        const Divider(height: 32),

        // Batches Section (Replaces the top timeline)
        _buildNestedBatchList(context),
      ],
    );
  }

  Widget _buildProduceInfo() {
    final paymentLabel = widget.order.items.isNotEmpty
        ? widget.order.items.first.paymentOption.label
        : 'Payment Details';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paymentLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue[600],
                  ),
                ),
              ],
            ),
            Text(
              'Total: ${DuruhaFormatter.formatCurrency(widget.order.subtotal)}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: duruhaGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'ORDER ITEMS',
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey[500],
            letterSpacing: 0.5,
          ),
        ),
        ...widget.order.items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.produce.nameEnglish,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Class ${item.selectedClasses.map((c) => c.code).join(', ')}',
                              style: GoogleFonts.poppins(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[800],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${item.quantityKg} ${item.produce.unitOfMeasure}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  DuruhaFormatter.formatCurrency(item.totalPrice),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        if (widget.order.supplySchedule != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Colors.blue[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${DateFormat('MMM dd, yyyy').format(widget.order.supplySchedule!.preferredStartDate)} — ${widget.order.supplySchedule!.preferredEndDate != null ? DateFormat('MMM dd, yyyy').format(widget.order.supplySchedule!.preferredEndDate!) : 'Until Cancelled (Infinity)'}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.local_shipping_outlined,
                      size: 14,
                      color: Colors.blue[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.order.supplySchedule!.occurrences == -1
                          ? 'Deliveries: ${_getCompletedDeliveries(widget.order)} / ∞'
                          : 'Deliveries: ${_getCompletedDeliveries(widget.order)} / ${widget.order.supplySchedule!.occurrences}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  int _getCompletedDeliveries(MarketOrder order) {
    if (order.batches == null) return 0;
    return order.batches!
        .where((b) => b['status'] == DuruhaOrderStatus.done)
        .length;
  }

  Widget _buildNestedBatchList(BuildContext context) {
    final repository = OrderTrackingRepository();

    return FutureBuilder<MarketOrder?>(
      future: repository.fetchOrder(widget.order.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(color: duruhaGreen),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading batches: ${snapshot.error}'),
          );
        }

        final fetchedOrder = snapshot.data;
        final batches = fetchedOrder?.batches ?? [];

        if (batches.isEmpty) return const SizedBox.shrink();

        double totalOrderPaid = 0;

        // Sorting: Future -> Latest -> Past
        // We'll prepare the list in this order: [Future Batches (reversed)], [Latest Active], [Past Batches (reversed)]
        // But the user said: "on top of the scroll hidden are the nect batcches to work on"
        // This implies [Future] is at the physical top of the list.

        List<Map<String, dynamic>> futureBatches = [];
        List<Map<String, dynamic>> activeBatches = [];
        List<Map<String, dynamic>> pastBatches = [];

        for (int i = 0; i < batches.length; i++) {
          final b = batches[i];
          final s = b['status'] as DuruhaOrderStatus;

          if (s == DuruhaOrderStatus.done) {
            totalOrderPaid += (b['paidPrice'] as double);
            pastBatches.add(b);
          } else if (s == DuruhaOrderStatus.processing ||
              s == DuruhaOrderStatus.searching) {
            futureBatches.add(b);
          } else {
            activeBatches.add(b);
          }
        }

        // Final list: Future -> Active -> Past
        // We reverse future and past to keep standard chronological logic within groups if needed?
        // Actually let's just do: [Future (Desc)], [Active], [Past (Desc)]
        final displayBatches = [
          ...futureBatches.reversed,
          ...activeBatches,
          ...pastBatches.reversed,
        ];

        // Find which batch ID to scroll to
        int targetBatchId = -1;
        if (activeBatches.isNotEmpty) {
          targetBatchId = activeBatches.first['id'];
        } else if (futureBatches.isNotEmpty) {
          targetBatchId = futureBatches.last['id'];
        }

        // Trigger scroll once data is built
        if (!_hasScrolledToLatest && targetBatchId != -1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToLatest(targetBatchId);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total Paid Summary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: duruhaGreen.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: duruhaGreen.withValues(alpha: 0.1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Paid to Order',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      DuruhaFormatter.formatCurrency(totalOrderPaid),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: duruhaGreen,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Vertical Scrollable Overflow List
            SizedBox(
              height: 500, // Constrained height for overflow
              child: SingleChildScrollView(
                controller: _batchScrollController,
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  children: displayBatches.asMap().entries.map((entry) {
                    final batch = entry.value;
                    final batchId = batch['id'] as int;

                    // Create or retrieve key for this batch
                    final key = _batchKeys.putIfAbsent(
                      batchId,
                      () => GlobalKey(),
                    );

                    return Padding(
                      key: key,
                      padding: const EdgeInsets.only(
                        bottom: 16,
                        left: 4,
                        right: 4,
                      ),
                      child: _buildBatchCard(context, batch),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _scrollToLatest(int batchId) {
    if (_batchScrollController.hasClients) {
      final key = _batchKeys[batchId];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.0, // This puts the item at the TOP of the viewport
        );
        _hasScrolledToLatest = true;
      }
    }
  }

  Widget _buildBatchCard(BuildContext context, Map<String, dynamic> batch) {
    final status = batch['status'] as DuruhaOrderStatus;
    final isPaid = status == DuruhaOrderStatus.done;
    final isTransit = status == DuruhaOrderStatus.toSupply;
    final isPreparing = status == DuruhaOrderStatus.matched;
    final isReady = status == DuruhaOrderStatus.harvestSecured;
    final isPaused = status == DuruhaOrderStatus.paused;

    final hasDetails = isPaid || isTransit || isPreparing || isReady;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Batch # | Status (with icon)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _getStatusIcon(status),
                    size: 18,
                    color: _getStatusColor(status),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Batch ${batch['id']}',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              _buildSmallStatusChip(status),
            ],
          ),
          const SizedBox(height: 8),

          // Mini Status Stepper
          _buildMiniBatchStepper(context, status),
          const SizedBox(height: 12),

          if (batch['date'] != null)
            Text(
              isPaid
                  ? 'Paid ${DateFormat('MMM dd, yyyy').format(batch['date'] as DateTime)}'
                  : isPaused
                  ? 'Resuming ${DateFormat('MMM dd, yyyy').format(batch['date'] as DateTime)}'
                  : 'Expected ${DateFormat('MMM dd, yyyy').format(batch['date'] as DateTime)}',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
            ),

          const Divider(height: 24),

          // Details or Placeholder
          if (hasDetails)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Packing List Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'PACKING LIST',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[500],
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (isPaid)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: duruhaGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'PAID',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: duruhaGreen,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Items
                ...(batch['items'] as List<Map<String, dynamic>>).map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'],
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (item['class_grade'] != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Class ${item['class_grade']}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 9,
                                          color: Colors.orange[800],
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    '${item['qty']} ${item['unit']}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              if (item['variety'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    item['variety'],
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      color: Colors.blue[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (item['subPrice'] != null)
                          Text(
                            DuruhaFormatter.formatCurrency(
                              item['subPrice'] as double,
                            ),
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  );
                }),

                const Divider(height: 24),

                // Pricing Breakdown
                if (!isPaid)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Listed',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        DuruhaFormatter.formatCurrency(
                          batch['listedPrice'] as double,
                        ),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Paid',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: duruhaGreen,
                        ),
                      ),
                      Text(
                        DuruhaFormatter.formatCurrency(
                          batch['paidPrice'] as double,
                        ),
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: duruhaGreen,
                        ),
                      ),
                    ],
                  ),
              ],
            )
          else if (isPaused)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.pause_circle_outline,
                    size: 32,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Extended indefinitely because no eggplant is available in the market.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.orange[800],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            )
          else
            // Pending
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule, size: 40, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    'Pending Schedule',
                    style: GoogleFonts.poppins(color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniBatchStepper(
    BuildContext context,
    DuruhaOrderStatus status,
  ) {
    // Mini stages within a batch: Matched -> Secured -> Supplying -> Done
    final batchStages = [
      DuruhaOrderStatus.matched,
      DuruhaOrderStatus.harvestSecured,
      DuruhaOrderStatus.toSupply,
      DuruhaOrderStatus.done,
    ];

    int currentIdx = batchStages.indexOf(status);
    if (currentIdx == -1) {
      if (status == DuruhaOrderStatus.searching ||
          status == DuruhaOrderStatus.processing) {
        currentIdx = -1; // Not started
      } else {
        currentIdx = batchStages.length - 1; // Completed
      }
    }

    return Row(
      children: batchStages.asMap().entries.map((entry) {
        final idx = entry.key;
        final stage = entry.value;
        final isPast = idx < currentIdx;
        final isActive = idx == currentIdx;
        final isLast = idx == batchStages.length - 1;

        final color = isPast || isActive
            ? _getStatusColor(stage)
            : Colors.grey[300]!;

        return Expanded(
          child: Row(
            children: [
              Icon(_getStatusIcon(stage), size: 14, color: color),
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: isPast ? color : Colors.grey[200],
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  IconData _getStatusIcon(DuruhaOrderStatus status) {
    switch (status) {
      case DuruhaOrderStatus.done:
        return Icons.check_circle_outline;
      case DuruhaOrderStatus.toSupply:
        return Icons.local_shipping_outlined;
      case DuruhaOrderStatus.harvestSecured:
        return Icons.inventory_2_outlined;
      case DuruhaOrderStatus.matched:
        return Icons.handshake_outlined;
      case DuruhaOrderStatus.searching:
        return Icons.pause_circle_outline;
      case DuruhaOrderStatus.processing:
        return Icons.schedule;
      case DuruhaOrderStatus.paused:
        return Icons.pause_circle_outline;
    }
  }

  Color _getStatusColor(DuruhaOrderStatus status) {
    switch (status) {
      case DuruhaOrderStatus.done:
        return duruhaGreen;
      case DuruhaOrderStatus.toSupply:
        return Colors.blue;
      case DuruhaOrderStatus.harvestSecured:
        return Colors.cyan;
      case DuruhaOrderStatus.matched:
        return Colors.orange;
      case DuruhaOrderStatus.searching:
        return Colors.red;
      case DuruhaOrderStatus.processing:
        return Colors.grey;
      case DuruhaOrderStatus.paused:
        return Colors.red;
    }
  }

  Widget _buildSmallStatusChip(DuruhaOrderStatus status) {
    Color color = _getStatusColor(status);
    String label = 'PENDING';
    IconData icon = _getStatusIcon(status);

    switch (status) {
      case DuruhaOrderStatus.done:
        label = 'DONE';
        break;
      case DuruhaOrderStatus.toSupply:
        label = 'TO SUPPLY';
        break;
      case DuruhaOrderStatus.harvestSecured:
        label = 'HARVEST SECURED';
        break;
      case DuruhaOrderStatus.matched:
        label = 'MATCHED';
        break;
      case DuruhaOrderStatus.searching:
        label = 'SEARCHING';
        break;
      case DuruhaOrderStatus.processing:
        label = 'PROCESSING';
        break;
      case DuruhaOrderStatus.paused:
        label = 'PAUSED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
