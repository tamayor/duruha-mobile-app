class FarmerPerformance {
  final int trustScore;
  final String trustSubtitle;
  final int cropPoints;
  final String pointsSubtitle;
  final String currentRankName;
  final double rankProgress;
  final String rankNextGoal;

  const FarmerPerformance({
    required this.trustScore,
    required this.trustSubtitle,
    required this.cropPoints,
    required this.pointsSubtitle,
    required this.currentRankName,
    required this.rankProgress,
    required this.rankNextGoal,
  });
}
