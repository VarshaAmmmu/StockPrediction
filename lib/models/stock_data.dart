class StockData {
  final String name;
  double price;
  double change;
  double changePercentage;
  double prediction;
  double predictionChange;
  double predictionChangePercentage;
  double confidence;

  StockData({
    required this.name,
    this.price = 0.0,
    this.change = 0.0,
    this.changePercentage = 0.0,
    this.prediction = 0.0,
    this.predictionChange = 0.0,
    this.predictionChangePercentage = 0.0,
    this.confidence = 0.75,
  });

  factory StockData.fromJson(Map<String, dynamic> json) {
    return StockData(
      name: json['name'],
      price: json['price'].toDouble(),
      change: json['change'].toDouble(),
      changePercentage: json['changePercentage'].toDouble(),
      prediction: json['prediction'].toDouble(),
      predictionChange: json['predictionChange'].toDouble(),
      predictionChangePercentage: json['predictionChangePercentage'].toDouble(),
      confidence: json['confidence'].toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'change': change,
      'changePercentage': changePercentage,
      'prediction': prediction,
      'predictionChange': predictionChange,
      'predictionChangePercentage': predictionChangePercentage,
      'confidence': confidence,
    };
  }
}
