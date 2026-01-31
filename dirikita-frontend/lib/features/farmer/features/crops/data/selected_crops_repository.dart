import '../domain/selected_crop_summary.dart';

class SelectedCropsRepository {
  Future<List<SelectedCropSummary>> fetchSelectedCrops() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Return specific mock data as requested
    return [
      SelectedCropSummary(
        id: 'prod_001',
        nameDialect: "Kamatis",
        nameEnglish: "Tomato",
        pledgeCountLabel: "3rd Pledge",
        rank: 1,
        imageUrl:
            "https://images.unsplash.com/photo-1592924357228-91a4daadcfea?q=80&w=300&auto=format&fit=crop",
      ),
      SelectedCropSummary(
        id: 'prod_002',
        nameDialect: "Talong",
        nameEnglish: "Eggplant",
        pledgeCountLabel: "11th Pledge",
        rank: 2,
        imageUrl:
            "https://images.unsplash.com/photo-1604321272882-07c73743be32?q=80&w=300&auto=format&fit=crop",
      ),
      SelectedCropSummary(
        id: 'prod_003',
        nameDialect: "Siling Labuyo",
        nameEnglish: "Bird's Eye Chili",
        pledgeCountLabel: "45th Pledge",
        rank: 3,
        imageUrl:
            "https://images.unsplash.com/photo-1588252303782-cb80119abd6d?q=80&w=300&auto=format&fit=crop",
      ),
      SelectedCropSummary(
        id: 'prod_004',
        nameDialect: "Kalabasa",
        nameEnglish: "Squash",
        pledgeCountLabel: "8th Pledge",
        rank: 4,
        imageUrl:
            "https://images.unsplash.com/photo-1506509531310-8b981665a38a?q=80&w=300&auto=format&fit=crop",
      ),
      SelectedCropSummary(
        id: 'prod_005',
        nameDialect: "Okra",
        nameEnglish: "Lady's Finger",
        pledgeCountLabel: "22nd Pledge",
        rank: 5,
        imageUrl:
            "https://images.unsplash.com/photo-1464454709131-ffd692591ee5?q=80&w=300&auto=format&fit=crop",
      ),
      SelectedCropSummary(
        id: 'prod_006',
        nameDialect: "Sitaw",
        nameEnglish: "String Beans",
        pledgeCountLabel: "15th Pledge",
        rank: 6,
        imageUrl:
            "https://images.unsplash.com/photo-1567191060458-2d60064b013c?q=80&w=300&auto=format&fit=crop",
      ),
      SelectedCropSummary(
        id: 'prod_007',
        nameDialect: "Ampalaya",
        nameEnglish: "Bitter Gourd",
        pledgeCountLabel: "19th Pledge",
        rank: 7,
        imageUrl:
            "https://images.unsplash.com/photo-1622321453401-494b5f979c3d?q=80&w=300&auto=format&fit=crop",
      ),
      SelectedCropSummary(
        id: 'prod_008',
        nameDialect: "Luy-a",
        nameEnglish: "Ginger",
        pledgeCountLabel: "5th Pledge",
        rank: 8,
        imageUrl:
            "https://images.unsplash.com/photo-1599940824399-b87987ceb72a?q=80&w=300&auto=format&fit=crop",
      ),
      SelectedCropSummary(
        id: 'prod_009',
        nameDialect: "Bawang",
        nameEnglish: "Garlic",
        pledgeCountLabel: "30th Pledge",
        rank: 9,
        imageUrl:
            "https://images.unsplash.com/photo-1540148426945-6cf22a6b2383?q=80&w=300&auto=format&fit=crop",
      ),
      SelectedCropSummary(
        id: 'prod_010',
        nameDialect: "Sibuyas",
        nameEnglish: "Onion",
        pledgeCountLabel: "50th Pledge",
        rank: 10,
        imageUrl:
            "https://images.unsplash.com/photo-1508747703725-719777637510?q=80&w=300&auto=format&fit=crop",
      ),
    ];
  }
}
