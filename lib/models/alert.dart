class StockAlert {
  final double targetPrice;
  final bool isAbove;
  final DateTime createdAt;
  bool triggered;

  StockAlert({
    required this.targetPrice,
    required this.isAbove,
    required this.createdAt,
    this.triggered = false,
  });

  factory StockAlert.fromJson(Map<String, dynamic> json) {
    return StockAlert(
      targetPrice: json['targetPrice'].toDouble(),
      isAbove: json['isAbove'],
      createdAt: DateTime.parse(json['createdAt']),
      triggered: json['triggered'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'targetPrice': targetPrice,
      'isAbove': isAbove,
      'createdAt': createdAt.toIso8601String(),
      'triggered': triggered,
    };
  }
}
