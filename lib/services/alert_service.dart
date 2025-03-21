import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/alert.dart';

class AlertService {
  static const String _alertsKey = 'stockAlerts';
  Map<String, List<StockAlert>> alerts = {};

  Future<void> loadAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final alertsJson = prefs.getString(_alertsKey);

    if (alertsJson != null) {
      final Map<String, dynamic> decoded = jsonDecode(alertsJson);
      alerts.clear();
      
      decoded.forEach((symbol, value) {
        alerts[symbol] = (value as List)
            .map((alert) => StockAlert.fromJson(Map<String, dynamic>.from(alert)))
            .toList();
      });
    }
  }

  Future<void> saveAlerts() async {
    final prefs = await SharedPreferences.getInstance();
    final Map<String, List<Map<String, dynamic>>> encodableAlerts = {};
    
    alerts.forEach((symbol, alertList) {
      encodableAlerts[symbol] = alertList.map((alert) => alert.toJson()).toList();
    });

    await prefs.setString(_alertsKey, jsonEncode(encodableAlerts));
  }

  void addAlert(String symbol, StockAlert alert) {
    if (!alerts.containsKey(symbol)) {
      alerts[symbol] = [];
    }
    alerts[symbol]!.add(alert);
    saveAlerts();
  }

  void removeAlert(String symbol, int index) {
    if (alerts.containsKey(symbol) && alerts[symbol]!.length > index) {
      alerts[symbol]!.removeAt(index);
      if (alerts[symbol]!.isEmpty) {
        alerts.remove(symbol);
      }
      saveAlerts();
    }
  }

  void checkAlerts(String symbol, double currentPrice) {
    if (!alerts.containsKey(symbol)) return;

    for (var alert in alerts[symbol]!) {
      if (!alert.triggered) {
        if ((alert.isAbove && currentPrice >= alert.targetPrice) ||
            (!alert.isAbove && currentPrice <= alert.targetPrice)) {
          alert.triggered = true;
          saveAlerts();
        }
      }
    }
  }
}
