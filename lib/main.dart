import 'package:flutter/material.dart';
import 'screens/dashboard_screen.dart';

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