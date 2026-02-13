import 'package:duruha/features/farmer/shared/domain/pledge_model.dart';

class ManageOfferRepository {
  /// Fetches harvest offers with simulation delay.
  Future<List<HarvestOffer>> fetchMyOffers() async {
    await Future.delayed(const Duration(milliseconds: 800));
    return [
      HarvestOffer(
        id: "OFF-2026-001",
        cropName: "Tomato",
        variants: ["Roma", "Cherry"],
        varietyQuantities: {"Roma": 500.0, "Cherry": 200.0},
        startDate: DateTime.now().subtract(const Duration(days: 5)),
        disposalDate: DateTime.now().add(const Duration(days: 10)),
        totalHarvestQty: 700.0,
        reservedQty: 350.0,
        imageUrl:
            "https://images.unsplash.com/photo-1518977676601-b53f02bad673?q=80&w=2070&auto=format&fit=crop",
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      HarvestOffer(
        id: "OFF-2026-002",
        cropName: "Bell Pepper",
        variants: ["Red", "Yellow", "Green"],
        varietyQuantities: {"Red": 100.0, "Yellow": 100.0, "Green": 100.0},
        startDate: DateTime.now().subtract(const Duration(days: 2)),
        disposalDate: DateTime.now().add(const Duration(days: 15)),
        totalHarvestQty: 300.0,
        reservedQty: 50.0,
        imageUrl:
            "https://images.unsplash.com/photo-1566384842113-ad8970871cbd?q=80&w=1974&auto=format&fit=crop",
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      HarvestOffer(
        id: "OFF-2026-003",
        cropName: "Eggplant",
        variants: ["Long Purple"],
        varietyQuantities: {"Long Purple": 400.0},
        startDate: DateTime.now().add(const Duration(days: 5)),
        disposalDate: DateTime.now().add(const Duration(days: 25)),
        totalHarvestQty: 400.0,
        reservedQty: 0.0,
        imageUrl:
            "https://images.unsplash.com/photo-1528131312450-93bfb06603a1?q=80&w=1974&auto=format&fit=crop",
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }
}
