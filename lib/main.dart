import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:yahoo_finance_data_reader/yahoo_finance_data_reader.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:http/http.dart' as http;

void main() {
  runApp(const StockPredictionApp());
}

class StockPredictionApp extends StatelessWidget {
  const StockPredictionApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Stock Prediction',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1E1E2E),
        cardColor: const Color(0xFF2A2D3E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6B8AFD),
          secondary: Color(0xFF49BEFF),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

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

  // Yahoo Finance Service
  final YahooFinanceService _yahooFinanceService = YahooFinanceService();

  // Initial stock data structure
  final Map<String, Map<String, dynamic>> stockData = {
    'AAPL': {
      'name': 'Apple Inc.',
      'price': 0.0,
      'change': 0.0,
      'changePercentage': 0.0,
      'prediction': 0.0,
      'predictionChange': 0.0,
      'predictionChangePercentage': 0.0,
      'confidence': 0.75,
    },
    'MSFT': {
      'name': 'Microsoft Corp.',
      'price': 0.0,
      'change': 0.0,
      'changePercentage': 0.0,
      'prediction': 0.0,
      'predictionChange': 0.0,
      'predictionChangePercentage': 0.0,
      'confidence': 0.75,
    },
    'GOOGL': {
      'name': 'Alphabet Inc.',
      'price': 0.0,
      'change': 0.0,
      'changePercentage': 0.0,
      'prediction': 0.0,
      'predictionChange': 0.0,
      'predictionChangePercentage': 0.0,
      'confidence': 0.75,
    },
    'AMZN': {
      'name': 'Amazon.com Inc.',
      'price': 0.0,
      'change': 0.0,
      'changePercentage': 0.0,
      'prediction': 0.0,
      'predictionChange': 0.0,
      'predictionChangePercentage': 0.0,
      'confidence': 0.75,
    },
  };

  // Chart data
  List<FlSpot> historicalData = [];
  List<FlSpot> predictionData = [];
  double minY = 0;
  double maxY = 0;
  DateTime? startDate;
  Map<String, List<Map<String, dynamic>>> alerts = {};
  List<FlSpot> upperBoundData = []; 
  List<FlSpot> lowerBoundData = []; 
  @override
  void initState() {
    super.initState();
    _fetchAllStockData();
    _loadAlerts();

    // Set up a timer to refresh stock data every 6 minutes
    refreshTimer = Timer.periodic(const Duration(minutes: 1), (Timer t) {
      _fetchAllStockData();
      _checkAlerts(); // Check alerts when refreshing data
    });
  }

  // Load saved alerts from SharedPreferences
  Future<void> _loadAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final alertsJson = prefs.getString('stockAlerts');

    if (alertsJson != null) {
      final Map<String, dynamic> decoded = jsonDecode(alertsJson);

      // Convert back to the correct structure
      final Map<String, List<Map<String, dynamic>>> loadedAlerts = {};
      decoded.forEach((key, value) {
        List<Map<String, dynamic>> stockAlerts = [];
        for (var alert in value) {
          stockAlerts.add(Map<String, dynamic>.from(alert));
        }
        loadedAlerts[key] = stockAlerts;
      });

      setState(() {
        alerts = loadedAlerts;
      });
    }
  }

  // Save alerts to SharedPreferences
  Future<void> _saveAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final alertsJson = jsonEncode(alerts);
    await prefs.setString('stockAlerts', alertsJson);
  }

  // Add new alert
  void _addAlert(String symbol, double targetPrice, bool isAbove) {
    setState(() {
      if (alerts[symbol] == null) {
        alerts[symbol] = [];
      }

      alerts[symbol]!.add({
        'targetPrice': targetPrice,
        'isAbove': isAbove,
        'createdAt': DateTime.now().toIso8601String(),
        'triggered': false,
      });
    });

    _saveAlerts();

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Alert set for $symbol at \$${targetPrice.toStringAsFixed(2)} ${isAbove ? 'above' : 'below'} current price'),
      duration: const Duration(seconds: 2),
    ));
  }

  // Remove alert
  void _removeAlert(String symbol, int index) {
    setState(() {
      if (alerts[symbol] != null && alerts[symbol]!.length > index) {
        alerts[symbol]!.removeAt(index);

        // Remove the symbol key if no alerts left
        if (alerts[symbol]!.isEmpty) {
          alerts.remove(symbol);
        }
      }
    });

    _saveAlerts();
  }

  // Check if any alerts should be triggered
  void _checkAlerts() {
    alerts.forEach((symbol, symbolAlerts) {
      if (stockData.containsKey(symbol)) {
        final currentPrice = stockData[symbol]!['price'];

        for (int i = 0; i < symbolAlerts.length; i++) {
          final alert = symbolAlerts[i];

          if (!alert['triggered']) {
            final targetPrice = alert['targetPrice'];
            final isAbove = alert['isAbove'];

            bool shouldTrigger = false;

            if (isAbove && currentPrice >= targetPrice) {
              shouldTrigger = true;
            } else if (!isAbove && currentPrice <= targetPrice) {
              shouldTrigger = true;
            }

            if (shouldTrigger) {
              _triggerAlert(symbol, i, currentPrice);
            }
          }
        }
      }
    });
  }

  // Trigger an alert
  void _triggerAlert(String symbol, int index, double currentPrice) {
    setState(() {
      alerts[symbol]![index]['triggered'] = true;
    });

    _saveAlerts();

    final alert = alerts[symbol]![index];
    final targetPrice = alert['targetPrice'];
    final isAbove = alert['isAbove'];

    // Show notification
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'ALERT: $symbol has ${isAbove ? 'risen above' : 'fallen below'} \$${targetPrice.toStringAsFixed(2)} (Current: \$${currentPrice.toStringAsFixed(2)})'),
      duration: const Duration(seconds: 5),
      backgroundColor: Colors.red,
      action: SnackBarAction(
        label: 'DISMISS',
        onPressed: () {
          _removeAlert(symbol, index);
        },
      ),
    ));
  }

  // Show alert dialog to set a new alert
  void _showSetAlertDialog(String symbol, double currentPrice) {
    double targetPrice = currentPrice;
    bool isAbove = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Set Price Alert for $symbol'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text('Current Price: '),
                      Text(
                        '\$${currentPrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Alert me when price is '),
                      DropdownButton<bool>(
                        value: isAbove,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              isAbove = value;
                            });
                          }
                        },
                        items: [
                          DropdownMenuItem(
                            value: true,
                            child: Text(
                              'above',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                          DropdownMenuItem(
                            value: false,
                            child: Text(
                              'below',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Target Price: \$'),
                      Expanded(
                        child: TextFormField(
                          initialValue: targetPrice.toStringAsFixed(2),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          onChanged: (value) {
                            try {
                              targetPrice = double.parse(value);
                            } catch (_) {}
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('CANCEL'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _addAlert(symbol, targetPrice, isAbove);
                    Navigator.of(context).pop();
                  },
                  child: const Text('SET ALERT'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Show list of all alerts
  void _showAlertsList() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Your Stock Alerts'),
          content: SizedBox(
            width: double.maxFinite,
            child: alerts.isEmpty
                ? const Center(child: Text('No alerts set'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: alerts.entries.length,
                    itemBuilder: (context, index) {
                      final entry = alerts.entries.elementAt(index);
                      final symbol = entry.key;
                      final symbolAlerts = entry.value;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              '$symbol - ${stockData[symbol]?['name'] ?? ''}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          ...List.generate(symbolAlerts.length, (i) {
                            final alert = symbolAlerts[i];
                            final isAbove = alert['isAbove'];
                            final targetPrice = alert['targetPrice'];
                            final triggered = alert['triggered'];

                            return ListTile(
                              dense: true,
                              title: Text(
                                  '${isAbove ? 'Above' : 'Below'} \$${targetPrice.toStringAsFixed(2)}'),
                              subtitle:
                                  Text(triggered ? 'Triggered' : 'Active'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () {
                                  _removeAlert(symbol, i);
                                  Navigator.of(context).pop();
                                  _showAlertsList();
                                },
                              ),
                            );
                          }),
                          const Divider(),
                        ],
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('CLOSE'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  // Calculate start date based on selected timeframe
  DateTime getStartDateFromTimeframe() {
    final DateTime now = DateTime.now();
    switch (selectedTimeframe) {
      case '1D':
        return DateTime(now.year, now.month, now.day - 1);
      case '1W':
        return DateTime(now.year, now.month, now.day - 7);
      case '1M':
        return DateTime(now.year, now.month - 1, now.day);
      case '3M':
        return DateTime(now.year, now.month - 3, now.day);
      case '1Y':
        return DateTime(now.year - 1, now.month, now.day);
      default:
        return DateTime(now.year, now.month, now.day - 7);
    }
  }

  // Fetch data for all stocks
  Future<void> _fetchAllStockData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      // Fetch data for each stock in our list
      for (String symbol in stockData.keys) {
        await _fetchStockData(symbol);
      }

      // After fetching all stock data, fetch historical data for the selected stock
      await _fetchHistoricalData(selectedStock);

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to fetch stock data: $e';
      });
    }
  }

  // Function to fetch predictions from the AI API
  Future<Map<String, dynamic>> _fetchPrediction(
      String symbol, String horizon) async {
    var headers = {'Content-Type': 'application/json'};

    // Convert our UI horizon to API horizon format
    String apiHorizon = 'short-term';
    if (selectedPredictionHorizon == 'Mid-term') {
      apiHorizon = 'mid-term';
    } else if (selectedPredictionHorizon == 'Long-term') {
      apiHorizon = 'long-term';
    }

    var request = http.Request(
        'POST', Uri.parse('https://b498-34-73-128-36.ngrok-free.app/predict'));
    request.body = json.encode({"symbol": symbol, "horizon": apiHorizon});
    request.headers.addAll(headers);

    try {
      http.StreamedResponse response = await request.send();
      if (response.statusCode == 200) {
        String responseBody = await response.stream.bytesToString();
        return json.decode(responseBody);
      } else {
        print('API Error: ${response.reasonPhrase}');
        throw Exception('Failed to get prediction: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('Error fetching prediction: $e');
      throw Exception('Failed to fetch prediction: $e');
    }
  }

  // Fetch current stock data using Yahoo Finance
  Future<void> _fetchStockData(String symbol) async {
    try {
      // Get the most recent candle data for the symbol
      List<YahooFinanceCandleData> candleData =
          await _yahooFinanceService.getTickerData(symbol);

      if (candleData.isNotEmpty) {
        // Get the most recent candle and previous day's candle
        final YahooFinanceCandleData latestCandle = candleData.last;
        final YahooFinanceCandleData previousCandle = candleData.length > 1
            ? candleData[candleData.length - 2]
            : candleData.last;

        final double price = latestCandle.close;
        final double previousPrice = previousCandle.close;
        final double change = price - previousPrice;
        final double changePercent = (change / previousPrice) * 100;

        // Fetch AI prediction for this symbol
        try {
          final prediction =
              await _fetchPrediction(symbol, selectedPredictionHorizon);

          // Extract prediction data
          final double predictedPrice = prediction['predicted_prices'][0];
          final double lowerBound = prediction['lower_bound'][0];
          final double upperBound = prediction['upper_bound'][0];

          // Calculate confidence based on the range between upper and lower bounds
          // The smaller the range, the higher the confidence
          final double range = upperBound - lowerBound;
          final double maxRange =
              price * 0.1; // Assume 10% of current price is max range
          final double confidence = 1.0 - (range / maxRange).clamp(0.0, 1.0);

          final double predictionChange = predictedPrice - price;
          final double predictionChangePercentage =
              (predictionChange / price) * 100;

          setState(() {
            stockData[symbol]!['price'] = price;
            stockData[symbol]!['change'] = change;
            stockData[symbol]!['changePercentage'] = changePercent;
            stockData[symbol]!['prediction'] = predictedPrice;
            stockData[symbol]!['predictionChange'] = predictionChange;
            stockData[symbol]!['predictionChangePercentage'] =
                predictionChangePercentage;
            stockData[symbol]!['confidence'] = confidence;
            stockData[symbol]!['lowerBound'] = lowerBound;
            stockData[symbol]!['upperBound'] = upperBound;
          });
        } catch (predictionError) {
          // If prediction API fails, fall back to the simple model
          print(
              'Prediction API failed, using fallback for $symbol: $predictionError');

          // Simple prediction model as fallback
          final double predictionFactor =
              selectedPredictionHorizon == 'Short-term'
                  ? 1.05
                  : selectedPredictionHorizon == 'Mid-term'
                      ? 1.1
                      : 1.15;
          final double prediction = price * predictionFactor;
          final double predictionChange = prediction - price;
          final double predictionChangePercentage =
              (predictionChange / price) * 100;

          setState(() {
            stockData[symbol]!['price'] = price;
            stockData[symbol]!['change'] = change;
            stockData[symbol]!['changePercentage'] = changePercent;
            stockData[symbol]!['prediction'] = prediction;
            stockData[symbol]!['predictionChange'] = predictionChange;
            stockData[symbol]!['predictionChangePercentage'] =
                predictionChangePercentage;
          });
        }
      }
    } catch (e) {
      print('Error fetching $symbol data: $e');
    }
  }

  // Fetch historical data for the selected timeframe
  Future<void> _fetchHistoricalData(String symbol) async {
    // Reset chart data
    historicalData = [];
    predictionData = [];


    // Set start date based on selected timeframe
    startDate = getStartDateFromTimeframe();

    try {
      // Get historical data using Yahoo Finance
      List<YahooFinanceCandleData> candleData = await _yahooFinanceService
          .getTickerData(symbol, startDate: startDate, adjust: true);

      if (candleData.isNotEmpty) {
        // Create spots for chart
        List<FlSpot> spots = [];
        for (int i = 0; i < candleData.length; i++) {
          spots.add(FlSpot(i.toDouble(), candleData[i].close));
        }

        // Create prediction data (extend from last historical point)
        List<FlSpot> predictions = [];
        List<FlSpot> upperPredictions = [];
        List<FlSpot> lowerPredictions = [];

        if (spots.isNotEmpty) {
          final lastSpot = spots.last;
          final lastPrice = lastSpot.y;
          final prediction = stockData[symbol]!['prediction'];

          // Check if we have confidence interval bounds
          final bool hasConfidenceInterval =
              stockData[symbol]!.containsKey('lowerBound') &&
                  stockData[symbol]!.containsKey('upperBound');

          final double lowerBound = hasConfidenceInterval
              ? stockData[symbol]!['lowerBound']
              : prediction * 0.98;
          final double upperBound = hasConfidenceInterval
              ? stockData[symbol]!['upperBound']
              : prediction * 1.02;

          // Create prediction curve points
          int predictionPoints = 5;
          double increment = (prediction - lastPrice) / predictionPoints;
          double lowerIncrement = (lowerBound - lastPrice) / predictionPoints;
          double upperIncrement = (upperBound - lastPrice) / predictionPoints;

          for (int i = 0; i <= predictionPoints; i++) {
            double x = lastSpot.x + i;
            double y = lastPrice + (increment * i);
            double lowerY = lastPrice + (lowerIncrement * i);
            double upperY = lastPrice + (upperIncrement * i);

            if (i == 0) {
              // First prediction point is the same as last historical point
              predictions.add(FlSpot(x, lastPrice));
              lowerPredictions.add(FlSpot(x, lastPrice));
              upperPredictions.add(FlSpot(x, lastPrice));
            } else {
              predictions.add(FlSpot(x, y));
              lowerPredictions.add(FlSpot(x, lowerY));
              upperPredictions.add(FlSpot(x, upperY));
            }
          }
        }

        // Find min and max for Y axis
        List<double> allPrices =
            candleData.map((candle) => candle.close).toList();
        if (predictions.isNotEmpty) {
          allPrices.add(predictions.last.y);

          // Add confidence interval bounds to the price range calculation
          if (lowerPredictions.isNotEmpty && upperPredictions.isNotEmpty) {
            allPrices.add(lowerPredictions.last.y);
            allPrices.add(upperPredictions.last.y);
          }
        }
        double minPrice =
            allPrices.reduce((curr, next) => curr < next ? curr : next);
        double maxPrice =
            allPrices.reduce((curr, next) => curr > next ? curr : next);

        // Add some padding to min/max
        double padding = (maxPrice - minPrice) * 0.1;

        setState(() {
          historicalData = spots;
          predictionData = predictions;
          lowerBoundData = lowerPredictions;
          upperBoundData = upperPredictions;
          minY = minPrice - padding;
          maxY = maxPrice + padding;
        });
      }
    } catch (e) {
      print('Error fetching historical data: $e');
      setState(() {
        errorMessage = 'Error fetching historical data: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: isLoading && historicalData.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : errorMessage.isNotEmpty
                ? Center(
                    child: Text('Error: $errorMessage',
                        style: const TextStyle(color: Colors.red)))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      _buildStockCards(),
                      _buildChartSection(),
                      _buildPredictionControls(),
                      _buildPredictionInsights(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'AI Stock Prediction',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Make informed decisions with AI predictions',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _fetchAllStockData,
                  tooltip: 'Refresh Data',
                ),
                CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  child: IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: _showAlertsList,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ));
  }

  Widget _buildStockCards() {
    return Container(
      height: 130,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: stockData.entries.map((entry) {
          final stockSymbol = entry.key;
          final data = entry.value;
          final isSelected = selectedStock == stockSymbol;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedStock = stockSymbol;
              });
              _fetchHistoricalData(stockSymbol);
            },
            child: Container(
              width: 180,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        stockSymbol,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: data['change'] >= 0
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${data['change'] >= 0 ? '+' : ''}${data['changePercentage'].toStringAsFixed(2)}%',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                data['change'] >= 0 ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data['name'],
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[400],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '\$${data['price'].toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${data['change'] >= 0 ? '+' : ''}\$${data['change'].toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          color:
                              data['change'] >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChartSection() {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stockData[selectedStock]!['name'],
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Current: \$${stockData[selectedStock]!['price'].toStringAsFixed(2)} | Predicted: \$${stockData[selectedStock]!['prediction'].toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildTimeframeSelector(),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: historicalData.isEmpty
                  ? const Center(child: Text('No historical data available'))
                  : Container(
                      padding: EdgeInsets.only(bottom: 16, left: 0),
                      child: LineChart(LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          horizontalInterval: 1,
                          verticalInterval: 1,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: const Color(0xFF37434D).withOpacity(0.2),
                              strokeWidth: 1,
                            );
                          },
                          getDrawingVerticalLine: (value) {
                            return FlLine(
                              color: const Color(0xFF37434D).withOpacity(0.2),
                              strokeWidth: 1,
                              dashArray: [5, 5],
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 42,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '\$${value.toStringAsFixed(1)}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                // For demo, show points at regular intervals
                                if (historicalData.isNotEmpty &&
                                    value % 5 == 0 &&
                                    value < historicalData.length) {
                                  return Text(
                                    value.toInt().toString(),
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(
                              color: const Color(0xFF37434D).withOpacity(0.2)),
                        ),
                        minX: historicalData.first.x,
                        maxX: predictionData.isNotEmpty
                            ? predictionData.last.x
                            : historicalData.last.x,
                        minY: minY,
                        maxY: maxY,
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                return LineTooltipItem(
                                  '\$${spot.y.toStringAsFixed(2)}',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        lineBarsData: [
                          // Historical data line
                          LineChartBarData(
                            spots: historicalData,
                            isCurved: true,
                            color: Colors.blue,
                            barWidth: 2,
                            isStrokeCapRound: true,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.blue.withOpacity(0.1),
                            ),
                          ),
                          // Lower bound prediction line
                          if (lowerBoundData.isNotEmpty)
                            LineChartBarData(
                              spots: lowerBoundData,
                              isCurved: true,
                              color: Colors.orange.withOpacity(0.5),
                              barWidth: 1,
                              dashArray: [3, 3],
                              isStrokeCapRound: true,
                              dotData: FlDotData(show: false),
                            ),
                          // Upper bound prediction line
                          if (upperBoundData.isNotEmpty)
                            LineChartBarData(
                              spots: upperBoundData,
                              isCurved: true,
                              color: Colors.orange.withOpacity(0.5),
                              barWidth: 1,
                              dashArray: [3, 3],
                              isStrokeCapRound: true,
                              dotData: FlDotData(show: false),
                            ),
                          // Main prediction line
                          LineChartBarData(
                            spots: predictionData,
                            isCurved: true,
                            color: Colors.orange,
                            barWidth: 2,
                            dashArray: [5, 5],
                            isStrokeCapRound: true,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: stockData[selectedStock]!
                                      .containsKey('lowerBound')
                                  ? false
                                  : true,
                              color: Colors.orange.withOpacity(0.1),
                            ),
                          ),
                        ],
                      )),
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem(Colors.blue, 'Historical'),
                const SizedBox(width: 16),
                _buildLegendItem(Colors.orange, 'Prediction'),
                const SizedBox(width: 16),
                _buildLegendItem(
                    Colors.orange.withOpacity(0.5), 'Confidence Interval'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildTimeframeSelector() {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: ['1D', '1W', '1M', '3M', '1Y'].map((timeframe) {
          final isSelected = selectedTimeframe == timeframe;
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedTimeframe = timeframe;
              });
              _fetchHistoricalData(selectedStock);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                timeframe,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.grey,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPredictionControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedPredictionHorizon,
                  isDense: true,
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down),
                  items: ['Short-term', 'Mid-term', 'Long-term']
                      .map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null &&
                        newValue != selectedPredictionHorizon) {
                      setState(() {
                        selectedPredictionHorizon = newValue;
                      });
                      // Recalculate predictions based on new horizon
                      _fetchAllStockData();
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () => _showSetAlertDialog(
                selectedStock, stockData[selectedStock]!['price']),
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Set Alert'),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionInsights() {
    final currentData = stockData[selectedStock]!;
    final predictionValue = currentData['prediction'];
    final currentValue = currentData['price'];
    final change = currentData['predictionChange'];
    final percentChange = currentData['predictionChangePercentage'];
    final confidence = currentData['confidence'];

    // Get bounds if they exist
    final hasConfidenceInterval = currentData.containsKey('lowerBound') &&
        currentData.containsKey('upperBound');
    final lowerBound = hasConfidenceInterval ? currentData['lowerBound'] : null;
    final upperBound = hasConfidenceInterval ? currentData['upperBound'] : null;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI Prediction Insights',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Predicted Price',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${predictionValue.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${change >= 0 ? '+' : ''}\$${change.toStringAsFixed(2)} (${percentChange.toStringAsFixed(2)}%)',
                      style: TextStyle(
                        fontSize: 14,
                        color: change >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                    if (hasConfidenceInterval) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Range: \$${lowerBound.toStringAsFixed(2)} - \$${upperBound.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Time Horizon',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedPredictionHorizon,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Confidence: ${(confidence * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 14,
                        color: _getConfidenceColor(confidence),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            hasConfidenceInterval
                ? 'Based on our AI prediction model, we forecast ${selectedStock} stock will ${change >= 0 ? 'rise' : 'fall'} by ${percentChange.toStringAsFixed(2)}% over the ${selectedPredictionHorizon.toLowerCase()} period, with a predicted price range of \$${lowerBound.toStringAsFixed(2)} to \$${upperBound.toStringAsFixed(2)}. This prediction has a confidence level of ${(confidence * 100).toStringAsFixed(0)}%.'
                : 'Based on our prediction model, we predict ${selectedStock} stock will ${change >= 0 ? 'rise' : 'fall'} by ${percentChange.toStringAsFixed(2)}% over the ${selectedPredictionHorizon.toLowerCase()} period. This prediction has a confidence level of ${(confidence * 100).toStringAsFixed(0)}%.',
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) {
      return Colors.green;
    } else if (confidence >= 0.6) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
