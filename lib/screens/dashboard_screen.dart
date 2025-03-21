import 'package:flutter/material.dart';
import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import '../models/stock_data.dart';
import '../models/alert.dart';
import '../services/yahoo_finance_service.dart';
import '../services/alert_service.dart';
import '../widgets/stock_chart.dart';
import '../widgets/stock_card.dart';
import '../widgets/alert_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String selectedStock = 'AAPL';
  String selectedTimeframe = '1W';
  String selectedPredictionHorizon = 'Short-term';
  bool isLoading = true;
  String errorMessage = '';
  Timer? refreshTimer;

  final YahooFinanceService _yahooFinanceService = YahooFinanceService();
  final AlertService _alertService = AlertService();

  final Map<String, StockData> stockData = {
    'AAPL': StockData(name: 'Apple Inc.'),
    'MSFT': StockData(name: 'Microsoft Corp.'),
    'GOOGL': StockData(name: 'Alphabet Inc.'),
    'AMZN': StockData(name: 'Amazon.com Inc.'),
  };

  List<FlSpot> historicalData = [];
  List<FlSpot> predictionData = [];
  double minY = 0;
  double maxY = 0;
  DateTime? startDate;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _alertService.loadAlerts();
    _fetchAllStockData();
    
    refreshTimer = Timer.periodic(const Duration(minutes: 1), (Timer t) {
      _fetchAllStockData();
      _checkAlerts();
    });
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAllStockData() async {
    try {
      setState(() => isLoading = true);

      for (var symbol in stockData.keys) {
        final data = await _yahooFinanceService.fetchStockData(symbol);
        setState(() {
          stockData[symbol]!.price = data['price'];
          stockData[symbol]!.change = data['change'];
          stockData[symbol]!.changePercentage = data['changePercentage'];
          // Mock prediction data for demo
          stockData[symbol]!.prediction = data['price'] * 1.02;
          stockData[symbol]!.predictionChange = data['price'] * 0.02;
          stockData[symbol]!.predictionChangePercentage = 2.0;
        });
      }

      await _updateChartData();
      setState(() => isLoading = false);
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> _updateChartData() async {
    try {
      final historicalDataPoints = await _yahooFinanceService.fetchHistoricalData(
        selectedStock,
        selectedTimeframe,
      );

      setState(() {
        historicalData = historicalDataPoints
            .map((data) => FlSpot(
                data['date'].millisecondsSinceEpoch.toDouble(),
                data['close'].toDouble()))
            .toList();

        // Calculate min and max Y values
        final allYValues = historicalData.map((spot) => spot.y).toList();
        minY = allYValues.reduce((min, value) => value < min ? value : min);
        maxY = allYValues.reduce((max, value) => value > max ? value : max);

        // Add some padding to min/max values
        final padding = (maxY - minY) * 0.1;
        minY -= padding;
        maxY += padding;
      });
    } catch (e) {
      setState(() => errorMessage = e.toString());
    }
  }

  void _checkAlerts() {
    for (var entry in stockData.entries) {
      _alertService.checkAlerts(entry.key, entry.value.price);
    }
  }

  void _showAddAlertDialog() {
    showDialog(
      context: context,
      builder: (context) => AddAlertDialog(
        stockSymbol: selectedStock,
        currentPrice: stockData[selectedStock]!.price,
        onAddAlert: (targetPrice, isAbove) {
          _alertService.addAlert(
            selectedStock,
            StockAlert(
              targetPrice: targetPrice,
              isAbove: isAbove,
              createdAt: DateTime.now(),
            ),
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Alert set for $selectedStock at \$${targetPrice.toStringAsFixed(2)} ${isAbove ? 'above' : 'below'} current price',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Stock Prediction'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: _showAddAlertDialog,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty
              ? Center(child: Text(errorMessage))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: StockCard(
                                stockData: stockData[selectedStock]!,
                                symbol: selectedStock,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StockChart(
                        historicalData: historicalData,
                        predictionData: predictionData,
                        minY: minY,
                        maxY: maxY,
                        onTimeframeChanged: (timeframe) {
                          setState(() {
                            selectedTimeframe = timeframe;
                            _updateChartData();
                          });
                        },
                      ),
                      // Add more widgets as needed
                    ],
                  ),
                ),
    );
  }
}
