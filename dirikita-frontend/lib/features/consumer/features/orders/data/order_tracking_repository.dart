import 'package:duruha/features/consumer/features/market/domain/market_order_model.dart';
import 'package:duruha/core/helpers/duruha_status_helper.dart';
import 'package:duruha/shared/produce/domain/produce_model.dart';

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
              nameEnglish: 'Kadyos',
              nameScientific: 'Cajanus cajan',
              category: ProduceCategory.legume,
              namesByDialect: {'Hiligaynon': 'Kadyos'},
              availableVarieties: [
                ProduceVariety(
                  id: 'v1',
                  name: 'Black',
                  isLocallyGrown: true,
                  sourcingProvinces: ['Iloilo'],
                  pricingModel: 'dynamic',
                  priceModifier: 10,
                ),
                ProduceVariety(
                  id: 'v2',
                  name: 'White',
                  isLocallyGrown: true,
                  sourcingProvinces: ['Iloilo'],
                  pricingModel: 'fixed',
                  priceModifier: 0,
                ),
              ],
              imageHeroUrl: '',
              imageThumbnailUrl: '',
              iconUrl: '',
              gradeGuideUrl: '',
              unitOfMeasure: 'kg',
              pricingEconomics: PricingEconomics(
                duruhaConsumerPrice: 120,
                duruhaFarmerPayout: 90,
                marketBenchmarkRetail: 130,
                marketBenchmarkFarmgate: 80,
                priceTrendSignal: 'stable',
              ),
              perishabilityIndex: 2,
              shelfLifeDays: 30,
              requiresColdChain: false,
              growingCycleDays: 180,
              seasonality: Seasonality(
                peakMonths: ['Dec', 'Jan', 'Feb'],
                leanMonths: ['Mar', 'Apr'],
                offSeason: ['May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov'],
              ),
              yieldPerSqm: 1.2,
              standardPackType: 'Sack',
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
              nameEnglish: 'Eggplant',
              nameScientific: 'Solanum melongena',
              category: ProduceCategory.fruitVeg,
              namesByDialect: {'Hiligaynon': 'Talong'},
              availableVarieties: [
                ProduceVariety(
                  id: 'v3',
                  name: 'Long Purple',
                  isLocallyGrown: true,
                  sourcingProvinces: ['Iloilo'],
                  pricingModel: 'dynamic',
                  priceModifier: 0,
                ),
                ProduceVariety(
                  id: 'v4',
                  name: 'Round Green',
                  isLocallyGrown: true,
                  sourcingProvinces: ['Iloilo'],
                  pricingModel: 'dynamic',
                  priceModifier: -5,
                ),
              ],
              imageHeroUrl: '',
              imageThumbnailUrl: '',
              iconUrl: '',
              gradeGuideUrl: '',
              unitOfMeasure: 'kg',
              pricingEconomics: PricingEconomics(
                duruhaConsumerPrice: 80,
                duruhaFarmerPayout: 60,
                marketBenchmarkRetail: 90,
                marketBenchmarkFarmgate: 55,
                priceTrendSignal: 'downward',
              ),
              perishabilityIndex: 3,
              shelfLifeDays: 7,
              requiresColdChain: true,
              growingCycleDays: 60,
              seasonality: Seasonality(
                peakMonths: ['Year-round'],
                leanMonths: [],
                offSeason: [],
              ),
              yieldPerSqm: 2.5,
              standardPackType: 'Crate',
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
              nameEnglish: 'Kadyos',
              nameScientific: 'Cajanus cajan',
              category: ProduceCategory.legume,
              namesByDialect: {'Hiligaynon': 'Kadyos'},
              availableVarieties: [
                ProduceVariety(
                  id: 'v1',
                  name: 'Black',
                  isLocallyGrown: true,
                  sourcingProvinces: ['Iloilo'],
                  pricingModel: 'dynamic',
                  priceModifier: 10,
                ),
              ],
              imageHeroUrl: '',
              imageThumbnailUrl: '',
              iconUrl: '',
              gradeGuideUrl: '',
              unitOfMeasure: 'kg',
              pricingEconomics: PricingEconomics(
                duruhaConsumerPrice: 120,
                duruhaFarmerPayout: 90,
                marketBenchmarkRetail: 130,
                marketBenchmarkFarmgate: 80,
                priceTrendSignal: 'stable',
              ),
              perishabilityIndex: 2,
              shelfLifeDays: 30,
              requiresColdChain: false,
              growingCycleDays: 180,
              seasonality: Seasonality(
                peakMonths: ['Dec', 'Jan', 'Feb'],
                leanMonths: ['Mar', 'Apr'],
                offSeason: ['May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov'],
              ),
              yieldPerSqm: 1.2,
              standardPackType: 'Sack',
            ),
            selectedVarieties: ['Black'],
            selectedClasses: [ProduceClass.A],
            quantityKg: 1.5,
            paymentOption: PaymentOption.fullPayment,
          ),
          OrderItem(
            produce: Produce(
              id: 'p3',
              nameEnglish: 'String Beans',
              nameScientific: 'Vigna unguiculata',
              category: ProduceCategory.legume,
              namesByDialect: {'Hiligaynon': 'Lutay'},
              availableVarieties: [
                ProduceVariety(
                  id: 'v5',
                  name: 'Standard',
                  isLocallyGrown: true,
                  sourcingProvinces: ['Antique'],
                  pricingModel: 'dynamic',
                  priceModifier: 0,
                ),
              ],
              imageHeroUrl: '',
              imageThumbnailUrl: '',
              iconUrl: '',
              gradeGuideUrl: '',
              unitOfMeasure: 'kg',
              pricingEconomics: PricingEconomics(
                duruhaConsumerPrice: 60,
                duruhaFarmerPayout: 45,
                marketBenchmarkRetail: 70,
                marketBenchmarkFarmgate: 40,
                priceTrendSignal: 'stable',
              ),
              perishabilityIndex: 4,
              shelfLifeDays: 5,
              requiresColdChain: false,
              growingCycleDays: 60,
              seasonality: Seasonality(
                peakMonths: ['Year-round'],
                leanMonths: [],
                offSeason: [],
              ),
              yieldPerSqm: 0.8,
              standardPackType: 'Bundle',
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
