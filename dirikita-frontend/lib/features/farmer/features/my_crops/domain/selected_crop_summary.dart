class SelectedCropSummary {
  final String nameDialect;
  final String nameEnglish;
  final String pledgeCountLabel; // e.g., "11th Pledge"
  final int rank; // e.g., 2
  final String? imageUrl; // Added for UI compatibility if needed
  final String id;
  SelectedCropSummary({
    required this.nameDialect,
    required this.nameEnglish,
    required this.pledgeCountLabel,
    required this.rank,
    this.imageUrl,
    required this.id,
  });
}
