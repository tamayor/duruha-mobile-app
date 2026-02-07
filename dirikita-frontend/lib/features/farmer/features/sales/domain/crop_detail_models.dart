class CropPledgeHistoryItem {
  final String id;
  final DateTime date;
  final double amount;
  final String unit;
  final String status;
  final String variety;
  final double? price;

  CropPledgeHistoryItem({
    required this.id,
    required this.date,
    required this.amount,
    required this.unit,
    required this.status,
    required this.variety,
    this.price,
  });
}
