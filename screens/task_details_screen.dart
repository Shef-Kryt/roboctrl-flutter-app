import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/scheduled_task.dart';
import '../models/sensor_reading.dart';
import '../models/route.dart' as models;
import '../providers/scheduler_provider.dart';
import '../providers/bluetooth_provider.dart';
import 'sensors_detail_screen.dart';

class TaskDetailsScreen extends StatelessWidget {
  final ScheduledTask task;

  const TaskDetailsScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(task.name),
        actions: [
          if (task.sensorData != null && task.sensorData!.isNotEmpty)
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'export_csv',
                  child: Row(
                    children: [
                      Icon(Icons.file_download),
                      SizedBox(width: 8),
                      Text('Експорт CSV'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export_json',
                  child: Row(
                    children: [
                      Icon(Icons.file_download),
                      SizedBox(width: 8),
                      Text('Експорт JSON'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) async {
                final scheduler = context.read<SchedulerProvider>();
                try {
                  String content;
                  String extension;
                  if (value == 'export_csv') {
                    content = scheduler.exportTaskDataToCsv(task.id);
                    extension = 'csv';
                  } else {
                    content = scheduler.exportTaskDataToJson(task.id);
                    extension = 'json';
                  }

                  final directory = await getApplicationDocumentsDirectory();
                  final fileName = 'task_${task.id}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.$extension';
                  final file = File('${directory.path}/$fileName');
                  await file.writeAsString(content);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Файл збережено: $fileName'),
                        action: SnackBarAction(
                          label: 'Відкрити',
                          onPressed: () {

                          },
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Помилка експорту: $e')),
                    );
                  }
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _InfoCard(
            title: 'Статус',
            child: _StatusInfo(task: task),
          ),
          const SizedBox(height: 16),
          _InfoCard(
            title: 'Маршрут',
            child: _RouteInfo(route: task.route),
          ),
          const SizedBox(height: 16),
          if (task.sensorData != null && task.sensorData!.isNotEmpty) ...[
            _InfoCard(
              title: 'Дані датчиків',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Всього зчитувань: ${task.sensorData!.length}'),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SensorsDetailScreen(
                            sensorData: task.sensorData!,
                            taskName: task.name,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.sensors),
                    label: const Text('Детальний перегляд датчиків'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _InfoCard(
              title: 'Статистика',
              child: _StatisticsInfo(sensorData: task.sensorData!),
            ),
          ],
          if (task.errorMessage != null) ...[
            const SizedBox(height: 16),
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.error, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Помилка виконання',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(task.errorMessage!),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _InfoCard({required this.title, required this.child});

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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatusInfo extends StatelessWidget {
  final ScheduledTask task;

  const _StatusInfo({required this.task});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StatusChip(status: task.status),
            const SizedBox(width: 8),
            if (!task.enabled)
              const Chip(
                label: Text('Вимкнено'),
                backgroundColor: Colors.grey,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text('Заплановано: ${DateFormat('dd.MM.yyyy HH:mm').format(task.scheduledTime)}'),
        if (task.executedAt != null)
          Text('Виконано: ${DateFormat('dd.MM.yyyy HH:mm:ss').format(task.executedAt!)}'),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final TaskStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _getStatusInfo(status);
    return Chip(
      label: Text(label),
      backgroundColor: color.shade100,
      avatar: Icon(_getStatusIcon(status), size: 16, color: color),
    );
  }

  (String, MaterialColor) _getStatusInfo(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return ('Очікує', Colors.orange);
      case TaskStatus.running:
        return ('Виконується', Colors.blue);
      case TaskStatus.completed:
        return ('Завершено', Colors.green);
      case TaskStatus.failed:
        return ('Помилка', Colors.red);
      case TaskStatus.cancelled:
        return ('Скасовано', Colors.grey);
    }
  }

  IconData _getStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return Icons.schedule;
      case TaskStatus.running:
        return Icons.play_circle_outline;
      case TaskStatus.completed:
        return Icons.check_circle;
      case TaskStatus.failed:
        return Icons.error;
      case TaskStatus.cancelled:
        return Icons.cancel;
    }
  }
}

class _RouteInfo extends StatelessWidget {
  final models.Route route;

  const _RouteInfo({required this.route});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Назва: ${route.name}'),
        if (route.description != null) Text('Опис: ${route.description}'),
        const SizedBox(height: 8),
        Text('Кроків: ${route.steps.length}'),
        Text('Тривалість: ${_formatDuration(route.estimatedDuration)}'),
        const SizedBox(height: 8),
        const Text('Кроки:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        ...route.steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          return Padding(
            padding: const EdgeInsets.only(left: 16, top: 4),
            child: Text('${index + 1}. ${step.displayName} - ${step.speed}% - ${_formatDuration(step.duration)}'),
          );
        }),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '$minutes хв ${seconds > 0 ? '$seconds сек' : ''}';
    } else {
      return '$seconds сек';
    }
  }
}

class _StatisticsInfo extends StatelessWidget {
  final List<SensorReading> sensorData;

  const _StatisticsInfo({required this.sensorData});

  @override
  Widget build(BuildContext context) {
    if (sensorData.isEmpty) return const SizedBox.shrink();

    final voltages = sensorData.map((r) => r.batteryVoltage).toList();
    final temps = sensorData.map((r) => r.temperature).toList();
    final distances = sensorData.map((r) => r.distance).toList();

    double avg(List<double> values) => values.reduce((a, b) => a + b) / values.length;
    double min(List<double> values) => values.reduce((a, b) => a < b ? a : b);
    double max(List<double> values) => values.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatRow('Батарея (V)', avg(voltages), min(voltages), max(voltages)),
        _StatRow('Температура (°C)', avg(temps), min(temps), max(temps)),
        _StatRow('Відстань (см)', avg(distances), min(distances), max(distances)),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final double avg;
  final double min;
  final double max;

  const _StatRow(this.label, this.avg, this.min, this.max);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text('Серед: ${avg.toStringAsFixed(2)} | Мін: ${min.toStringAsFixed(2)} | Макс: ${max.toStringAsFixed(2)}'),
        ],
      ),
    );
  }
}
