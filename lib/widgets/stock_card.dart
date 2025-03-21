import 'package:flutter/material.dart';
import '../models/stock_data.dart';

class StockCard extends StatelessWidget {
  final StockData stockData;
  final String symbol;

  const StockCard({
    Key? key,
    required this.stockData,
    required this.symbol,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      symbol,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      stockData.name,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${stockData.price.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Row(
                      children: [
                        Icon(
                          stockData.change >= 0
                              ? Icons.arrow_upward
                              : Icons.arrow_downward,
                          color: stockData.change >= 0 ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        Text(
                          '${stockData.change.toStringAsFixed(2)} (${stockData.changePercentage.toStringAsFixed(2)}%)',
                          style: TextStyle(
                            color:
                                stockData.change >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Prediction',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '\$${stockData.prediction.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Confidence',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${(stockData.confidence * 100).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
