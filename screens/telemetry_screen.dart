import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/bluetooth_provider.dart';

class TelemetryScreen extends StatelessWidget {
  const TelemetryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Телеметрія'),
      ),
      body: Consumer<BluetoothProvider>(
        builder: (context, provider, child) {
          if (!provider.isConnected) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Потрібне підключення до робота, щоб бачити графіки.'),
              ),
            );
          }

          final voltage = provider.voltageHistory;
          final temp = provider.temperatureHistory;
          final distance = provider.distanceHistory;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ChartCard(
                title: 'Напруга батареї (V)',
                spots: _indexed(voltage),
                lineColor: Colors.blue,
              ),
              const SizedBox(height: 12),
              _ChartCard(
                title: 'Температура (°C)',
                spots: _indexed(temp),
                lineColor: Colors.orange,
              ),
              const SizedBox(height: 12),
              _ChartCard(
                title: 'Відстань (см)',
                spots: _indexed(distance),
                lineColor: Colors.green,
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  title: const Text('Очистити історію'),
                  subtitle: const Text('Скине дані графіків (без впливу на робота)'),
                  trailing: const Icon(Icons.delete_outline),
                  onTap: () => provider.clearTelemetryHistory(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

List<FlSpot> _indexed(List<double> values) {
  // X — просто індекс точки; для диплома цього зазвичай достатньо,
  // а точний час можна додати пізніше.
  return List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i]));
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.spots,
    required this.lineColor,
  });

  final String title;
  final List<FlSpot> spots;
  final Color lineColor;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: spots.isEmpty
                  ? const Center(child: Text('Немає даних'))
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: true),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: lineColor,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
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

