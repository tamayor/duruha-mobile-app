import 'package:duruha/features/consumer/features/manage/domain/market_order_model.dart';
import 'package:duruha/core/helpers/duruha_status_helper.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';
import 'package:duruha/shared/produce/domain/produce_variety.dart';

class OrderTrackingRepository {
  /// Fetches the list of orders for the current user.
  Future<List<MarketOrder>> fetchOrders() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Mock orders
    final orders = [
      MarketOrder(
        id: 'ORD_123456789',
        batchId: 'B-7721',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        status: 'confirmed',
        orderStatus: DuruhaOrderStatus.toSupply,
        farmerName: 'Tatay Berto',
        estimatedDeliveryDate: DateTime.now().add(const Duration(days: 4)),
        supplySchedule: SupplySchedule(
          preferredStartDate: DateTime.now().subtract(const Duration(days: 7)),
          frequency: DeliveryFrequency.weekly,
          preferredEndDate: DateTime.now().add(const Duration(days: 21)),
        ),
        items: [
          OrderItem(
            produce: Produce(
              id: 'p1',
              englishName: 'Kadyos',
              scientificName: 'Cajanus cajan',
              category: 'Legume',
              baseUnit: 'kg',
              varieties: [
                ProduceVariety(id: 'v1', name: 'Black'),
                ProduceVariety(id: 'v2', name: 'White'),
              ],
            ),
            selectedVarieties: ['Black', 'White'],
            selectedClasses: [ProduceClass.A, ProduceClass.B],
            quantityKg: 2.5,
            paymentOption: PaymentOption.downPayment,
          ),
        ],
      ),
      MarketOrder(
        id: 'ORD_987654321',
        batchId: 'B-6610',
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
        status: 'delivered',
        orderStatus: DuruhaOrderStatus.done,
        estimatedDeliveryDate: DateTime.now().subtract(const Duration(days: 5)),
        supplySchedule: SupplySchedule(
          preferredStartDate: DateTime.now().subtract(const Duration(days: 15)),
          frequency: DeliveryFrequency.weekly,
          preferredEndDate: null, // Infinity
        ),
        items: [
          OrderItem(
            produce: Produce(
              id: 'p2',
              englishName: 'Eggplant',
              scientificName: 'Solanum melongena',
              category: "legume",
              baseUnit: 'kg',
              varieties: [
                ProduceVariety(id: 'v3', name: 'Long Purple'),
                ProduceVariety(id: 'v4', name: 'Round Green'),
              ],
            ),
            selectedVarieties: ['Long Purple', 'Round Green'],
            selectedClasses: [ProduceClass.B, ProduceClass.C],
            quantityKg: 5.0,
            paymentOption: PaymentOption.fullPayment,
          ),
        ],
      ),
      MarketOrder(
        id: 'ORD_112233445',
        batchId: 'B-8809',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        status: 'confirmed',
        orderStatus: DuruhaOrderStatus.matched,
        farmerName: 'Manang Rosa',
        estimatedDeliveryDate: DateTime.now().add(const Duration(days: 10)),
        supplySchedule: SupplySchedule(
          preferredStartDate: DateTime.now().add(const Duration(days: 5)),
          frequency: DeliveryFrequency.weekly,
          preferredEndDate: DateTime.now().add(const Duration(days: 45)),
        ),
        items: [
          OrderItem(
            produce: Produce(
              id: 'p1',
              englishName: 'Kadyos',
              scientificName: 'Cajanus cajan',
              category: 'Legume',
              baseUnit: 'kg',
              varieties: [ProduceVariety(id: 'v1', name: 'Standard')],
            ),
            selectedVarieties: ['Black'],
            selectedClasses: [ProduceClass.A],
            quantityKg: 1.5,
            paymentOption: PaymentOption.fullPayment,
          ),
          OrderItem(
            produce: Produce(
              id: 'p3',
              englishName: 'String Beans',
              scientificName: 'Vigna unguiculata',
              category: 'Legume',
              baseUnit: 'kg',
              varieties: [ProduceVariety(id: 'v5', name: 'Standard')],
            ),
            selectedVarieties: ['Standard'],
            selectedClasses: [ProduceClass.B],
            quantityKg: 2.0,
            paymentOption: PaymentOption.fullPayment,
          ),
        ],
      ),
    ];

    // Populate batches for each order
    return orders.map((o) {
      final batches = _generateOrderBatches(o);
      return MarketOrder(
        id: o.id,
        batchId: o.batchId,
        items: o.items,
        createdAt: o.createdAt,
        status: o.status,
        orderStatus: o.orderStatus,
        farmerName: o.farmerName,
        estimatedDeliveryDate: o.estimatedDeliveryDate,
        supplySchedule: o.supplySchedule,
        batches: batches,
      );
    }).toList();
  }

  /// Fetches a single order by its ID, including simulated batch details.
  ///
  /// @api-doc
  /// Endpoint: GET /api/v1/orders/{orderId}
  /// Response:
  /// {
  ///   "id": "ORD_123456789",
  ///   "status": "confirmed",
  ///   "batches": [
  ///     {
  ///       "id": 1,
  ///       "status": "Paid", // Will be enum value string or int in real JSON, simplified here
  ///       "date": "2023-10-25T10:00:00Z",
  ///       "listedPrice": 1500.0,
  ///       "paidPrice": 1500.0,
  ///       "items": [...]
  ///     }
  ///   ],
  ///   ...
  /// }
  Future<MarketOrder?> fetchOrder(String orderId) async {
    final orders = await fetchOrders();
    try {
      final order = orders.firstWhere((o) => o.id == orderId);
      final batches = _generateOrderBatches(order);

      // Return a new MarketOrder with batches populated
      return MarketOrder(
        id: order.id,
        batchId: order.batchId,
        items: order.items,
        createdAt: order.createdAt,
        status: order.status,
        orderStatus: order.orderStatus,
        farmerName: order.farmerName,
        estimatedDeliveryDate: order.estimatedDeliveryDate,
        supplySchedule: order.supplySchedule,
        batches: batches,
      );
    } catch (_) {
      return null;
    }
  }

  /// Fetches the batch tracking details for a given order.
  ///
  /// @api-doc
  /// Endpoint: GET /api/v1/orders/{orderId}/batches
  Future<List<Map<String, dynamic>>> fetchOrderBatches(
    MarketOrder order,
  ) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));
    return _generateOrderBatches(order);
  }

  /// Internal helper to generate mock batches based on order details
  List<Map<String, dynamic>> _generateOrderBatches(MarketOrder order) {
    final isInfinity = order.supplySchedule?.occurrences == -1;
    final displayCount = isInfinity
        ? 3
        : (order.supplySchedule?.occurrences ?? 1);

    // Mock Item Distribution Logic based on the order
    return List.generate(displayCount, (i) {
      final batchIdx = i + 1;
      DuruhaOrderStatus status = DuruhaOrderStatus.searching;
      DateTime? date;
      double listedPrice = 0;
      double paidPrice = 0;
      List<Map<String, dynamic>> batchItems = [];

      // Logic: Done -> Active (To Supply/Harvest Secured/Matched) -> Searching
      if (batchIdx == 1) {
        status = DuruhaOrderStatus.done;
        date = order.createdAt.add(const Duration(days: 3));
      } else if (batchIdx == 2) {
        status = order.orderStatus;
        date = order.estimatedDeliveryDate?.add(Duration(days: i * 7));
      } else {
        status = DuruhaOrderStatus.searching;
        date = order.estimatedDeliveryDate?.add(Duration(days: i * 7));
      }

      // Fill items for the batch (except if it's purely searching/pending with no details yet)
      if (status != DuruhaOrderStatus.searching) {
        batchItems = order.items.map((item) {
          final variety = item.selectedVarieties.isNotEmpty
              ? item.selectedVarieties.first
              : 'Standard';
          final unitPrice = item.produce.pricingEconomics.duruhaConsumerPrice;
          final qty = item.quantityKg;

          return {
            'name': item.produce.nameEnglish,
            'variety': variety,
            'qty': qty,
            'unit': item.produce.unitOfMeasure,
            'class_grade': item.selectedClasses.isNotEmpty
                ? item.selectedClasses.first.code
                : 'A',
            'subPrice': qty * unitPrice,
          };
        }).toList();
      }

      // Calculate realistic listed prices
      if (batchItems.isNotEmpty) {
        listedPrice = batchItems.fold(0.0, (sum, item) {
          return sum + ((item['subPrice'] as double?) ?? 0.0);
        });

        if (status == DuruhaOrderStatus.done) {
          paidPrice = listedPrice;
        } else {
          paidPrice = 0;
        }
      }

      return {
        'id': batchIdx,
        'status': status,
        'date': date,
        'listedPrice': listedPrice,
        'paidPrice': paidPrice,
        'items': batchItems,
      };
    });
  }
}
