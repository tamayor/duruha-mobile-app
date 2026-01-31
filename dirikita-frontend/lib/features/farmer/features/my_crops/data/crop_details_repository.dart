import 'package:duruha/shared/produce/data/produce_repository.dart';
import 'package:duruha/core/theme/duruha_status.dart';
import 'package:duruha/features/farmer/features/my_crops/domain/crop_detail_models.dart';

class CropDetailsRepository {
  Future<List<CropPledgeHistoryItem>> getPledgeHistory(String cropId) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Resolve produce to get valid varieties for mocking
    final allProduce = await ProduceRepository().getAllProduce();
    final produce = allProduce.firstWhere(
      (p) => p.id == cropId,
      orElse: () => allProduce[0], // Fallback
    );

    // Return mock data
    return [
      CropPledgeHistoryItem(
        id: 'pl_001',
        date: DateTime.now().subtract(const Duration(days: 2)),
        amount: 500,
        unit: 'kg',
        status: DuruhaStatus.pending,
        variety: produce.availableVarieties.isNotEmpty
            ? produce.availableVarieties.first
            : 'Native',
      ),
      CropPledgeHistoryItem(
        id: 'pl_002',
        date: DateTime.now().subtract(const Duration(days: 15)),
        amount: 300,
        unit: 'kg',
        status: DuruhaStatus.confirmed,
        variety: produce.availableVarieties.length > 1
            ? produce.availableVarieties.last
            : 'Native',
      ),
      CropPledgeHistoryItem(
        id: 'pl_003',
        date: DateTime.now().subtract(const Duration(days: 45)),
        amount: 1200,
        unit: 'kg',
        status: DuruhaStatus.completed,
        variety: produce.availableVarieties.isNotEmpty
            ? produce.availableVarieties.first
            : 'Native',
      ),
    ];
  }
}
