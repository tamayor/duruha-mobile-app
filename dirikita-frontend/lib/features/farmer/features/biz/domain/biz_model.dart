class BizInsights {
  final double monthlyGrowth;
  final String topPerformingCrop;
  final String marketDemandNearby;
  final double totalRevenue;
  final int totalSalesCount;

  BizInsights({
    required this.monthlyGrowth,
    required this.topPerformingCrop,
    required this.marketDemandNearby,
    required this.totalRevenue,
    required this.totalSalesCount,
  });

  factory BizInsights.empty() {
    return BizInsights(
      monthlyGrowth: 0.0,
      topPerformingCrop: 'None',
      marketDemandNearby: 'Low',
      totalRevenue: 0.0,
      totalSalesCount: 0,
    );
  }
}
