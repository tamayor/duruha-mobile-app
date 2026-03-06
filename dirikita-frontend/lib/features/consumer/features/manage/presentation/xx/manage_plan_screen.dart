import 'package:flutter/material.dart';
import 'package:duruha/core/widgets/duruha_widgets.dart';
import 'package:duruha/core/helpers/duruha_status_helper.dart';
import 'package:duruha/features/consumer/features/manage/presentation/xx/market_order_model.dart';
import 'package:duruha/features/consumer/features/manage/presentation/xx/plan_tracking_card.dart';

class ConsumerPlansScreen extends StatefulWidget {
  final List<MarketOrder> plans;
  const ConsumerPlansScreen({super.key, required this.plans});

  @override
  State<ConsumerPlansScreen> createState() => _ConsumerPlansScreenState();
}

enum OrderSortOption { delivery, status, price, created }

class _ConsumerPlansScreenState extends State<ConsumerPlansScreen> {
  OrderSortOption _currentSort = OrderSortOption.created;

  List<MarketOrder> _sortOrders(List<MarketOrder> orders) {
    final sortedList = List<MarketOrder>.from(orders);
    switch (_currentSort) {
      case OrderSortOption.delivery:
        sortedList.sort((a, b) {
          final aDate = _getCurrentBatchDate(a) ?? DateTime(9999);
          final bDate = _getCurrentBatchDate(b) ?? DateTime(9999);
          return aDate.compareTo(bDate);
        });
        break;
      case OrderSortOption.status:
        sortedList.sort(
          (a, b) => a.orderStatus.index.compareTo(b.orderStatus.index),
        );
        break;
      case OrderSortOption.price:
        sortedList.sort(
          (a, b) => b.subtotal.compareTo(a.subtotal),
        ); // High to Low
        break;
      case OrderSortOption.created:
        sortedList.sort(
          (a, b) => b.createdAt.compareTo(a.createdAt),
        ); // Newest first
        break;
    }
    return sortedList;
  }

  DateTime? _getCurrentBatchDate(MarketOrder order) {
    if (order.batches == null || order.batches!.isEmpty) return null;
    final firstActive = order.batches!.firstWhere(
      (b) => b['status'] != DuruhaOrderStatus.done,
      orElse: () => {},
    );
    return firstActive['date'] as DateTime?;
  }

  @override
  Widget build(BuildContext context) {
    final sortedOrders = _sortOrders(widget.plans);

    return DuruhaScrollHideWrapper(
      hideHeight: 56, // Height of the sort header area
      bar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'ORDER HISTORY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey[500],
                letterSpacing: 0.5,
              ),
            ),
            PopupMenuButton<OrderSortOption>(
              icon: const Icon(
                Icons.sort_rounded,
                color: Colors.black87,
                size: 20,
              ),
              onSelected: (option) {
                setState(() => _currentSort = option);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: OrderSortOption.delivery,
                  child: Text('Sort by Delivery'),
                ),
                const PopupMenuItem(
                  value: OrderSortOption.status,
                  child: Text('Sort by Status'),
                ),
                const PopupMenuItem(
                  value: OrderSortOption.price,
                  child: Text('Sort by Price'),
                ),
                const PopupMenuItem(
                  value: OrderSortOption.created,
                  child: Text('Sort by Date Ordered'),
                ),
              ],
            ),
          ],
        ),
      ),
      body: sortedOrders.isEmpty
          ? const Center(child: Text('No orders found.'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: sortedOrders.length,
              itemBuilder: (context, index) {
                final order = sortedOrders[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: OrderTrackingCard(order: order),
                );
              },
            ),
    );
  }
}
