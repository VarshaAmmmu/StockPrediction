import 'package:yahoo_finance_data_reader/yahoo_finance_data_reader.dart';
import '../models/stock_data.dart';

class YahooFinanceService {
  final YahooFinanceService _yahooFinanceService = YahooFinanceService();

  Future<Map<String, dynamic>> fetchStockData(String symbol) async {
    try {
      final data = await _yahooFinanceService.getStockData(symbol);
      return {
        'price': data.currentPrice,
        'change': data.change,
        'changePercentage': data.changePercentage,
      };
    } catch (e) {
      throw Exception('Failed to fetch stock data: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchHistoricalData(String symbol, String timeframe) async {
    try {
      final DateTime now = DateTime.now();
      DateTime startDate;
      
      switch (timeframe) {
        case '1D':
          startDate = now.subtract(const Duration(days: 1));
          break;
        case '1W':
          startDate = now.subtract(const Duration(days: 7));
          break;
        case '1M':
          startDate = now.subtract(const Duration(days: 30));
          break;
        case '3M':
          startDate = now.subtract(const Duration(days: 90));
          break;
        default:
          startDate = now.subtract(const Duration(days: 7));
      }

      final historicalData = await _reader.getHistoricalData(
        symbol,
        startDate,
        now,
      );

      return historicalData.map((data) => {
        'date': data.date,
        'close': data.close,
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch historical data: $e');
    }
  }
}
