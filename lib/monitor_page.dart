import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SensorDashboard extends StatefulWidget {
  @override
  _SensorDashboardState createState() => _SensorDashboardState();
}

class _SensorDashboardState extends State<SensorDashboard> {
  final Random random = Random();
  late Timer timer;

  // Sensor data simulation
  double sulfurDioxide = 20.0;
  double argon = 50.0;
  double fineDust = 35.0;
  double humidity = 60.0;

  // Sensor data history for graphs
  List<double> sulfurHistory = [];
  List<double> argonHistory = [];
  List<double> fineDustHistory = [];
  List<double> humidityHistory = [];

  @override
  void initState() {
    super.initState();

    // Timer to update sensor data every second
    timer = Timer.periodic(Duration(seconds: 1), (_) {
      setState(() {
        sulfurDioxide = random.nextDouble() * 100;
        argon = random.nextDouble() * 100;
        fineDust = random.nextDouble() * 100;
        humidity = random.nextDouble() * 100;

        // Update history
        updateHistory(sulfurHistory, sulfurDioxide);
        updateHistory(argonHistory, argon);
        updateHistory(fineDustHistory, fineDust);
        updateHistory(humidityHistory, humidity);
      });
    });
  }

  void updateHistory(List<double> history, double value) {
    if (history.length >= 10) {
      history.removeAt(0);
    }
    history.add(value);
  }

  @override
  void dispose() {
    timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Sensor Dashboard'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildSensorCard(
                icon: Icons.air,
                color: Colors.red,
                title: 'SO₂',
                value: sulfurDioxide,
                unit: 'ppm',
                history: sulfurHistory,
              ),
              buildSensorCard(
                icon: Icons.flare,
                color: Colors.orange,
                title: 'Argon',
                value: argon,
                unit: '%',
                history: argonHistory,
              ),
              buildSensorCard(
                icon: Icons.cloud,
                color: Colors.green,
                title: 'Fine Dust',
                value: fineDust,
                unit: 'µg/m³',
                history: fineDustHistory,
              ),
              buildSensorCard(
                icon: Icons.water_drop,
                color: Colors.teal,
                title: 'Humidity',
                value: humidity,
                unit: '%',
                history: humidityHistory,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSensorCard({
    required IconData icon,
    required Color color,
    required String title,
    required double value,
    required String unit,
    required List<double> history,
  }) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 36),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              '${value.toStringAsFixed(1)} $unit',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 100,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      isCurved: true,
                      spots: history.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value);
                      }).toList(),
                      color: color,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
