import 'package:duruha/features/consumer/features/orders/data/order_tracking_repository.dart';
import 'package:flutter/material.dart';
import 'package:duruha/core/helpers/duruha_status_helper.dart';
import 'package:duruha/core/widgets/duruha_scaffold.dart';
import 'package:duruha/features/consumer/features/market/domain/market_order_model.dart';
import 'package:duruha/features/consumer/features/orders/presentation/widgets/order_tracking_card.dart';
import 'package:duruha/features/consumer/shared/presentation/navigation.dart';

class ConsumerOrdersScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ConsumerOrdersScreen({super.key, required this.userData});

  @override
  State<ConsumerOrdersScreen> createState() => _ConsumerOrdersScreenState();
}

enum OrderSortOption { delivery, status, price, created }

class _ConsumerOrdersScreenState extends State<ConsumerOrdersScreen> {
  final OrderTrackingRepository _repository = OrderTrackingRepository();
  late Future<List<MarketOrder>> _ordersFuture;
  OrderSortOption _currentSort = OrderSortOption.created;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _repository.fetchOrders();
  }

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
    final userName = widget.userData['name'] ?? 'Consumer';

    return DuruhaScaffold(
      appBarTitle: 'My Orders',
      showBackButton: false,
      appBarActions: [
        PopupMenuButton<OrderSortOption>(
          icon: const Icon(Icons.sort_rounded, color: Colors.black87),
          onSelected: (option) {
            setState(() {
              _currentSort = option;
            });
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
      body: FutureBuilder<List<MarketOrder>>(
        future: _ordersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading orders: ${snapshot.error}'),
            );
          }

          final orders = snapshot.data ?? [];
          if (orders.isEmpty) {
            return const Center(child: Text('No orders found.'));
          }

          final sortedOrders = _sortOrders(orders);

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sortedOrders.length,
            itemBuilder: (context, index) {
              final order = sortedOrders[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: OrderTrackingCard(order: order),
              );
            },
          );
        },
      ),
      bottomNavigationBar: ConsumerNavigation(
        name: userName,
        currentRoute: '/consumer/orders',
      ),
    );
  }
}
