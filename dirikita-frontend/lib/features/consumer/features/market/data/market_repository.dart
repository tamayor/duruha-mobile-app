import 'package:duruha/features/consumer/features/market/domain/market_order_model.dart';
import 'package:duruha/shared/produce/data/produce_repository.dart';

class MarketRepository {
  final ProduceRepository _produceRepository = ProduceRepository();

  Future<List<MarketProduceItem>> getConsumerProduce() async {
    // Fetch all produce from the shared repository
    final allProduce = await _produceRepository.getAllProduce();

    // Simulate local availability - mark 6 out of 10 as locally available
    // In a real app, this would come from the backend based on farmer inventory
    final localProduceIds = [
      'prod_001', // Tomato
      'prod_002', // Eggplant
      'prod_004', // Squash
      'prod_006', // String Beans
      'prod_007', // Bitter Gourd
      'prod_010', // Onion
    ];

    // Create MarketProduceItem for each produce
    final marketItems = allProduce.map((produce) {
      final isLocal = localProduceIds.contains(produce.id);
      return MarketProduceItem(
        produce: produce,
        isLocallyAvailable: isLocal,
        farmerLocation: isLocal ? 'Tubungan, Iloilo' : 'Other Region',
        estimatedHarvestDate: isLocal
            ? DateTime.now().add(Duration(days: produce.growingCycleDays))
            : null,
        availableQuantityKg: isLocal
            ? (20.0 +
                  (produce.id.hashCode % 130)) // Mock quantity between 20-150kg
            : null,
      );
    }).toList();

    // Sort: locally available first, then by name
    marketItems.sort((a, b) {
      if (a.isLocallyAvailable != b.isLocallyAvailable) {
        return a.isLocallyAvailable ? -1 : 1;
      }
      return a.produce.nameEnglish.compareTo(b.produce.nameEnglish);
    });

    return marketItems;
  }

  Future<MarketOrder> createOrder(List<OrderItem> items) async {
    // Simulate API call to create order
    await Future.delayed(const Duration(milliseconds: 500));

    // Generate a mock order ID
    final orderId = 'ORD_${DateTime.now().millisecondsSinceEpoch}';

    return MarketOrder(
      id: orderId,
      batchId: 'BCH-${DateTime.now().millisecond}',
      items: items,
      createdAt: DateTime.now(),
      status: 'pending',
    );
  }

  Future<bool> submitPayment(MarketOrder order) async {
    // Simulate payment processing
    await Future.delayed(const Duration(seconds: 2));

    // Mock successful payment
    return true;
  }
}
