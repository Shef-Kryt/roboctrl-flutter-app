import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/bluetooth_provider.dart';
import '../models/line_sensor.dart';

class SensorsRealtimeScreen extends StatefulWidget {
  const SensorsRealtimeScreen({super.key});

  @override
  State<SensorsRealtimeScreen> createState() => _SensorsRealtimeScreenState();
}

class _SensorsRealtimeScreenState extends State<SensorsRealtimeScreen> {
  final LineSensor _lineSensor = LineSensor();
  bool _isCalibrating = false;
  List<double> _recentVoltages = [];
  List<double> _recentTemps = [];
  List<double> _recentDistances = [];
  static const int _maxHistoryPoints = 50;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Датчики в реальному часі'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Оновити дані',
            onPressed: () => _requestSensorData(context),
          ),
        ],
      ),
      body: Consumer<BluetoothProvider>(
        builder: (context, provider, child) {
          if (!provider.isConnected) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Потрібне підключення до робота для перегляду датчиків',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            );
          }

          _updateHistory(provider);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _QuickStatsCard(provider: provider),
              const SizedBox(height: 16),
              _LineSensorsCard(
                provider: provider,
                lineSensor: _lineSensor,
                isCalibrating: _isCalibrating,
                onCalibrate: () => _startCalibration(provider),
                onStopCalibration: () => _stopCalibration(),
              ),
              const SizedBox(height: 16),
              _ObstacleSensorsCard(provider: provider),
              const SizedBox(height: 16),
              if (_recentVoltages.isNotEmpty) ...[
                _MiniChartCard(
                  title: 'Напруга батареї',
                  values: _recentVoltages,
                  color: Colors.blue,
                  unit: 'V',
                ),
                const SizedBox(height: 16),
                _MiniChartCard(
                  title: 'Температура',
                  values: _recentTemps,
                  color: Colors.orange,
                  unit: '°C',
                ),
                const SizedBox(height: 16),
                _MiniChartCard(
                  title: 'Відстань',
                  values: _recentDistances,
                  color: Colors.purple,
                  unit: 'см',
                ),
              ],
            ],
          );
        },
      ),
      floatingActionButton: Consumer<BluetoothProvider>(
        builder: (context, provider, child) {
          if (!provider.isConnected) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _requestSensorData(context),
            icon: const Icon(Icons.sensors),
            label: const Text('Запит даних'),
          );
        },
      ),
    );
  }

  void _requestSensorData(BuildContext context) {
    final provider = context.read<BluetoothProvider>();
    if (!provider.isConnected) return;

    provider.requestStatus();
    provider.requestDistance();
    provider.requestLineSensors();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Запит даних відправлено'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _updateHistory(BluetoothProvider provider) {
    if (_recentVoltages.length >= _maxHistoryPoints) {
      _recentVoltages.removeAt(0);
      _recentTemps.removeAt(0);
      _recentDistances.removeAt(0);
    }
    _recentVoltages.add(provider.batteryVoltage);
    _recentTemps.add(provider.temperature);
    _recentDistances.add(provider.distance);
  }

  void _startCalibration(BluetoothProvider provider) {
    setState(() => _isCalibrating = true);
    _lineSensor.resetCalibration();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Калібрування розпочато. Рухайте роботом по різних поверхнях.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _stopCalibration() {
    setState(() => _isCalibrating = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _lineSensor.isCalibrationValid()
              ? 'Калібрування завершено успішно'
              : 'Калібрування некоректне. Спробуйте ще раз.',
        ),
      ),
    );
  }
}

class _QuickStatsCard extends StatelessWidget {
  final BluetoothProvider provider;

  const _QuickStatsCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  icon: Icons.battery_full,
                  label: 'Батарея',
                  value: '${provider.batteryPercentage}%',
                  color: Colors.green,
                ),
                _StatItem(
                  icon: Icons.thermostat,
                  label: 'Температура',
                  value: '${provider.temperature.toStringAsFixed(1)}°C',
                  color: Colors.orange,
                ),
                _StatItem(
                  icon: Icons.square_foot,
                  label: 'Відстань',
                  value: '${provider.distance.toStringAsFixed(1)} см',
                  color: Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

class _LineSensorsCard extends StatelessWidget {
  final BluetoothProvider provider;
  final LineSensor lineSensor;
  final bool isCalibrating;
  final VoidCallback onCalibrate;
  final VoidCallback onStopCalibration;

  const _LineSensorsCard({
    required this.provider,
    required this.lineSensor,
    required this.isCalibrating,
    required this.onCalibrate,
    required this.onStopCalibration,
  });

  @override
  Widget build(BuildContext context) {
    final sensors = provider.lineSensors;
    final (position, calibrated) = lineSensor.getLinePosition(sensors);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Датчики лінії',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (isCalibrating)
                  ElevatedButton.icon(
                    onPressed: onStopCalibration,
                    icon: const Icon(Icons.stop, size: 16),
                    label: const Text('Зупинити'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: onCalibrate,
                    icon: const Icon(Icons.tune, size: 16),
                    label: const Text('Калібрувати'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) {
                final value = sensors[index];
                final isActive = value > 500;
                return Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isActive ? Colors.black : Colors.white,
                        border: Border.all(color: Colors.grey, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isActive ? Colors.white : Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$value',
                      style: TextStyle(
                        fontSize: 10,
                        color: isActive ? Colors.black : Colors.grey,
                      ),
                    ),
                  ],
                );
              }),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Позиція лінії:'),
                  Text(
                    '${(position / 1000).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            if (lineSensor.isCalibrated)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'Калібровано',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ObstacleSensorsCard extends StatelessWidget {
  final BluetoothProvider provider;

  const _ObstacleSensorsCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Датчики перешкод',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ObstacleIndicator(
                  label: 'Ліва',
                  detected: provider.leftObstacle,
                ),
                _ObstacleIndicator(
                  label: 'Права',
                  detected: provider.rightObstacle,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Відстань: ${provider.distance.toStringAsFixed(1)} см',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _ObstacleIndicator extends StatelessWidget {
  final String label;
  final bool detected;

  const _ObstacleIndicator({required this.label, required this.detected});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: detected ? Colors.red.shade100 : Colors.green.shade100,
            shape: BoxShape.circle,
            border: Border.all(
              color: detected ? Colors.red : Colors.green,
              width: 3,
            ),
          ),
          child: Icon(
            detected ? Icons.warning : Icons.check_circle,
            color: detected ? Colors.red : Colors.green,
            size: 32,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          detected ? 'Перешкода!' : 'Чисто',
          style: TextStyle(
            color: detected ? Colors.red : Colors.green,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _MiniChartCard extends StatelessWidget {
  final String title;
  final List<double> values;
  final Color color;
  final String unit;

  const _MiniChartCard({
    required this.title,
    required this.values,
    required this.color,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();

    final spots = values.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value);
    }).toList();

    final minY = values.reduce((a, b) => a < b ? a : b) - 1;
    final maxY = values.reduce((a, b) => a > b ? a : b) + 1;
    final currentValue = values.last;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${currentValue.toStringAsFixed(1)} $unit',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: color,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: color.withOpacity(0.1),
                      ),
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
