class ProduceDialect {
  final String dialectName;
  final String localName;

  ProduceDialect({required this.dialectName, required this.localName});

  factory ProduceDialect.fromJson(Map<String, dynamic> json) {
    return ProduceDialect(
      dialectName: json['dialect_name']?.toString() ?? '',
      localName: json['local_name']?.toString() ?? '',
    );
  }
}
