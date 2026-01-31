class PledgeStatusHistory {
  final String status;
  final DateTime timestamp;

  const PledgeStatusHistory({required this.status, required this.timestamp});

  Map<String, dynamic> toMap() => {'status': status, 'timestamp': timestamp};
}

class PledgeExpense {
  final String name;
  final String category;
  final double cost;

  const PledgeExpense({
    required this.name,
    required this.category,
    required this.cost,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'category': category,
    'cost': cost,
  };
}

class PledgeScheduleHistory {
  final DateTime oldDate;
  final DateTime newDate;
  final String reason;
  final String notes;
  final DateTime timestamp;

  const PledgeScheduleHistory({
    required this.oldDate,
    required this.newDate,
    required this.reason,
    required this.notes,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'oldDate': oldDate,
    'newDate': newDate,
    'reason': reason,
    'notes': notes,
    'timestamp': timestamp,
  };
}
