class CropMarketStudy {
  final List<MarketForecast> localForecasts;
  final List<MarketForecast> nationalForecasts;
  final double localDemandScore;
  final double nationalDemandScore;
  final double priceProjectedMin;
  final double priceProjectedMax;

  CropMarketStudy({
    required this.localForecasts,
    required this.nationalForecasts,
    required this.localDemandScore,
    required this.nationalDemandScore,
    required this.priceProjectedMin,
    required this.priceProjectedMax,
  });
}

class MarketForecast {
  final String month;
  final double demandKg;
  final double fulfilledKg;

  MarketForecast({
    required this.month,
    required this.demandKg,
    required this.fulfilledKg,
  });
}
