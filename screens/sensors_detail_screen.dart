import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/sensor_reading.dart';

class SensorsDetailScreen extends StatelessWidget {
  final List<SensorReading> sensorData;
  final String taskName;

  const SensorsDetailScreen({
    super.key,
    required this.sensorData,
    required this.taskName,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Датчики: $taskName'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Батарея'),
              Tab(text: 'Температура'),
              Tab(text: 'Відстань'),
              Tab(text: 'Лінія'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _BatteryTab(sensorData: sensorData),
            _TemperatureTab(sensorData: sensorData),
            _DistanceTab(sensorData: sensorData),
            _LineSensorsTab(sensorData: sensorData),
          ],
        ),
      ),
    );
  }
}

class _BatteryTab extends StatelessWidget {
  final List<SensorReading> sensorData;

  const _BatteryTab({required this.sensorData});

  @override
  Widget build(BuildContext context) {
    if (sensorData.isEmpty) {
      return const Center(child: Text('Немає даних'));
    }

    final voltageSpots = sensorData.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.batteryVoltage);
    }).toList();

    final percentageSpots = sensorData.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.batteryPercentage.toDouble());
    }).toList();

    final voltages = sensorData.map((r) => r.batteryVoltage).toList();
    final percentages = sensorData.map((r) => r.batteryPercentage).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ChartCard(
          title: 'Напруга батареї (V)',
          spots: voltageSpots,
          color: Colors.blue,
          minY: voltages.reduce((a, b) => a < b ? a : b) - 0.5,
          maxY: voltages.reduce((a, b) => a > b ? a : b) + 0.5,
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Відсоток заряду (%)',
          spots: percentageSpots,
          color: Colors.green,
          minY: 0,
          maxY: 100,
        ),
        const SizedBox(height: 16),
        _StatsCard(
          title: 'Статистика батареї',
          stats: {
            'Середня напруга': '${(voltages.reduce((a, b) => a + b) / voltages.length).toStringAsFixed(2)} V',
            'Мінімальна напруга': '${voltages.reduce((a, b) => a < b ? a : b).toStringAsFixed(2)} V',
            'Максимальна напруга': '${voltages.reduce((a, b) => a > b ? a : b).toStringAsFixed(2)} V',
            'Середній відсоток': '${(percentages.reduce((a, b) => a + b) / percentages.length).toStringAsFixed(1)}%',
            'Мінімальний відсоток': '${percentages.reduce((a, b) => a < b ? a : b)}%',
            'Максимальний відсоток': '${percentages.reduce((a, b) => a > b ? a : b)}%',
          },
        ),
      ],
    );
  }
}

class _TemperatureTab extends StatelessWidget {
  final List<SensorReading> sensorData;

  const _TemperatureTab({required this.sensorData});

  @override
  Widget build(BuildContext context) {
    if (sensorData.isEmpty) {
      return const Center(child: Text('Немає даних'));
    }

    final tempSpots = sensorData.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.temperature);
    }).toList();

    final temps = sensorData.map((r) => r.temperature).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ChartCard(
          title: 'Температура (°C)',
          spots: tempSpots,
          color: Colors.orange,
          minY: temps.reduce((a, b) => a < b ? a : b) - 2,
          maxY: temps.reduce((a, b) => a > b ? a : b) + 2,
        ),
        const SizedBox(height: 16),
        _StatsCard(
          title: 'Статистика температури',
          stats: {
            'Середня температура': '${(temps.reduce((a, b) => a + b) / temps.length).toStringAsFixed(2)} °C',
            'Мінімальна': '${temps.reduce((a, b) => a < b ? a : b).toStringAsFixed(2)} °C',
            'Максимальна': '${temps.reduce((a, b) => a > b ? a : b).toStringAsFixed(2)} °C',
          },
        ),
      ],
    );
  }
}

class _DistanceTab extends StatelessWidget {
  final List<SensorReading> sensorData;

  const _DistanceTab({required this.sensorData});

  @override
  Widget build(BuildContext context) {
    if (sensorData.isEmpty) {
      return const Center(child: Text('Немає даних'));
    }

    final distSpots = sensorData.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.distance);
    }).toList();

    final distances = sensorData.map((r) => r.distance).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ChartCard(
          title: 'Відстань до перешкод (см)',
          spots: distSpots,
          color: Colors.purple,
          minY: 0,
          maxY: distances.reduce((a, b) => a > b ? a : b) + 10,
        ),
        const SizedBox(height: 16),
        _StatsCard(
          title: 'Статистика відстані',
          stats: {
            'Середня відстань': '${(distances.reduce((a, b) => a + b) / distances.length).toStringAsFixed(2)} см',
            'Мінімальна': '${distances.reduce((a, b) => a < b ? a : b).toStringAsFixed(2)} см',
            'Максимальна': '${distances.reduce((a, b) => a > b ? a : b).toStringAsFixed(2)} см',
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Виявлення перешкод',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Ліва перешкода: ${sensorData.where((r) => r.leftObstacle).length} разів'),
                Text('Права перешкода: ${sensorData.where((r) => r.rightObstacle).length} разів'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LineSensorsTab extends StatelessWidget {
  final List<SensorReading> sensorData;

  const _LineSensorsTab({required this.sensorData});

  @override
  Widget build(BuildContext context) {
    if (sensorData.isEmpty) {
      return const Center(child: Text('Немає даних'));
    }

    final sensor1Spots = sensorData.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.lineSensors[0].toDouble());
    }).toList();
    final sensor2Spots = sensorData.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.lineSensors[1].toDouble());
    }).toList();
    final sensor3Spots = sensorData.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.lineSensors[2].toDouble());
    }).toList();
    final sensor4Spots = sensorData.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.lineSensors[3].toDouble());
    }).toList();
    final sensor5Spots = sensorData.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.lineSensors[4].toDouble());
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ChartCard(
          title: 'Датчик 1',
          spots: sensor1Spots,
          color: Colors.red,
          minY: 0,
          maxY: 1023,
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Датчик 2',
          spots: sensor2Spots,
          color: Colors.orange,
          minY: 0,
          maxY: 1023,
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Датчик 3',
          spots: sensor3Spots,
          color: Colors.yellow,
          minY: 0,
          maxY: 1023,
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Датчик 4',
          spots: sensor4Spots,
          color: Colors.green,
          minY: 0,
          maxY: 1023,
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'Датчик 5',
          spots: sensor5Spots,
          color: Colors.blue,
          minY: 0,
          maxY: 1023,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Візуалізація датчиків лінії',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...sensorData.take(10).map((reading) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          DateFormat('HH:mm:ss').format(reading.timestamp),
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        ...reading.lineSensors.map((value) {
                          return Container(
                            width: 30,
                            height: 20,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: value > 500 ? Colors.black : Colors.white,
                              border: Border.all(),
                            ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final List<FlSpot> spots;
  final Color color;
  final double minY;
  final double maxY;

  const _ChartCard({
    required this.title,
    required this.spots,
    required this.color,
    required this.minY,
    required this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: spots.isEmpty
                  ? const Center(child: Text('Немає даних'))
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: true),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(show: true),
                        minY: minY,
                        maxY: maxY,
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            color: color,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)),
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

class _StatsCard extends StatelessWidget {
  final String title;
  final Map<String, String> stats;

  const _StatsCard({required this.title, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...stats.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key),
                    Text(
                      entry.value,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
