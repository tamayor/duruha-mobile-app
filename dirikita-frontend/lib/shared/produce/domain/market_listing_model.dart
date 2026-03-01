class MarketListing {
  final String listingId;
  final String? produceForm;
  final double farmerToTraderPrice;
  final double farmerToDuruhaPrice;
  final double duruhaToConsumerPrice;
  final double marketToConsumerPrice;
  final double remainingQuantity;

  MarketListing({
    required this.listingId,
    this.produceForm,
    required this.farmerToTraderPrice,
    required this.farmerToDuruhaPrice,
    required this.duruhaToConsumerPrice,
    required this.marketToConsumerPrice,
    this.remainingQuantity = 0.0,
  });

  factory MarketListing.fromJson(Map<String, dynamic> json) {
    return MarketListing(
      listingId: json['listing_id']?.toString() ?? '',
      produceForm: json['produce_form']?.toString(),
      farmerToTraderPrice: json['farmer_to_trader_price']?.toDouble() ?? 0.0,
      farmerToDuruhaPrice: json['farmer_to_duruha_price']?.toDouble() ?? 0.0,
      duruhaToConsumerPrice:
          json['duruha_to_consumer_price']?.toDouble() ?? 0.0,
      marketToConsumerPrice:
          json['market_to_consumer_price']?.toDouble() ?? 0.0,
      remainingQuantity: json['remaining_quantity']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'listing_id': listingId,
      'produce_form': produceForm,
      'farmer_to_trader_price': farmerToTraderPrice,
      'farmer_to_duruha_price': farmerToDuruhaPrice,
      'duruha_to_consumer_price': duruhaToConsumerPrice,
      'market_to_consumer_price': marketToConsumerPrice,
      'remaining_quantity': remainingQuantity,
    };
  }
}
