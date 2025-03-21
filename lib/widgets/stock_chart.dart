import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class StockChart extends StatelessWidget {
  final List<FlSpot> historicalData;
  final List<FlSpot> predictionData;
  final double minY;
  final double maxY;
  final Function(String) onTimeframeChanged;

  const StockChart({
    Key? key,
    required this.historicalData,
    required this.predictionData,
    required this.minY,
    required this.maxY,
    required this.onTimeframeChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  minY: minY,
                  maxY: maxY,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      // tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final date = DateTime.fromMillisecondsSinceEpoch(
                              spot.x.toInt());
                          return LineTooltipItem(
                            '${DateFormat.yMMMd().format(date)}\n\$${spot.y.toStringAsFixed(2)}',
                            const TextStyle(color: Colors.white),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final date = DateTime.fromMillisecondsSinceEpoch(
                              value.toInt());
                          return Text(
                            DateFormat.MMMd().format(date),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          );
                        },
                        interval: _getInterval(),
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '\$${value.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          );
                        },
                        interval: (maxY - minY) / 6,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: historicalData,
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                    ),
                    if (predictionData.isNotEmpty)
                      LineChartBarData(
                        spots: predictionData,
                        isCurved: true,
                        color: Theme.of(context).colorScheme.secondary,
                        barWidth: 2,
                        dotData: FlDotData(show: false),
                        dashArray: [5, 5],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TimeframeButton(
                  label: '1D',
                  onPressed: () => onTimeframeChanged('1D'),
                ),
                _TimeframeButton(
                  label: '1W',
                  onPressed: () => onTimeframeChanged('1W'),
                ),
                _TimeframeButton(
                  label: '1M',
                  onPressed: () => onTimeframeChanged('1M'),
                ),
                _TimeframeButton(
                  label: '3M',
                  onPressed: () => onTimeframeChanged('3M'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _getInterval() {
    if (historicalData.isEmpty) return 1;
    final timeRange = historicalData.last.x - historicalData.first.x;
    return timeRange / 5;
  }
}

class _TimeframeButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _TimeframeButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: TextButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
