class ProduceBasicInfo {
  final String id;
  final String englishName;
  final String imageUrl;
  final String localName;
  final String scientificName;
  final int varietyCount;

  ProduceBasicInfo({
    required this.id,
    required this.englishName,
    required this.imageUrl,
    required this.localName,
    required this.scientificName,
    this.varietyCount = 0,
  });

  factory ProduceBasicInfo.fromJson(Map<String, dynamic> json) {
    return ProduceBasicInfo(
      id: json['id']?.toString() ?? '',
      englishName: json['english_name']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      localName: json['local_name']?.toString() ?? '',
      scientificName: json['scientific_name']?.toString() ?? '',
      varietyCount: (json['variety_count'] as num?)?.toInt() ?? 0,
    );
  }
}
