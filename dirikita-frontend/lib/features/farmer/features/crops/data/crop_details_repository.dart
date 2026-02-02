import 'package:duruha/features/farmer/shared/data/pledge_repository.dart';
import 'package:duruha/features/farmer/features/crops/domain/crop_detail_models.dart';

class CropDetailsRepository {
  Future<List<CropPledgeHistoryItem>> getPledgeHistory(String cropId) async {
    // Fetch all pledges from the repository
    final allPledges = await PledgeRepository().fetchMyPledges();

    // Filter for sold pledges matching this crop
    final soldPledges = allPledges.where((pledge) {
      return pledge.cropId == cropId && pledge.currentStatus == 'Sold';
    }).toList();

    // Sort by harvest date (most recent first)
    soldPledges.sort((a, b) => b.harvestDate.compareTo(a.harvestDate));

    // Convert HarvestPledge to CropPledgeHistoryItem
    return soldPledges.map((pledge) {
      // Calculate price per unit if sellingPrice is available
      double? pricePerUnit;
      if (pledge.sellingPrice != null && pledge.quantity > 0) {
        pricePerUnit = pledge.sellingPrice! / pledge.quantity;
      }

      return CropPledgeHistoryItem(
        id: pledge.id ?? 'unknown',
        date: pledge.harvestDate,
        amount: pledge.quantity,
        unit: pledge.unit,
        status: pledge.currentStatus,
        variety: pledge.variants.isNotEmpty ? pledge.variants.first : 'Unknown',
        price: pricePerUnit,
      );
    }).toList();
  }
}
