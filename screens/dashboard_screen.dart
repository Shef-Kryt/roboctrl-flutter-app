import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/scheduler_provider.dart';
import '../providers/bluetooth_provider.dart';
import '../models/scheduled_task.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Статистика'),
      ),
      body: Consumer2<SchedulerProvider, BluetoothProvider>(
        builder: (context, scheduler, bluetooth, child) {
          final tasks = scheduler.tasks;
          final completedTasks = tasks.where((t) => t.status == TaskStatus.completed).toList();
          final failedTasks = tasks.where((t) => t.status == TaskStatus.failed).toList();
          final totalReadings = completedTasks.fold<int>(
            0,
            (sum, task) => sum + (task.sensorData?.length ?? 0),
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ConnectionStatusCard(bluetooth: bluetooth),
              const SizedBox(height: 16),
              _TasksOverviewCard(
                total: tasks.length,
                completed: completedTasks.length,
                failed: failedTasks.length,
                pending: tasks.where((t) => t.status == TaskStatus.pending).length,
              ),
              const SizedBox(height: 16),
              if (completedTasks.isNotEmpty) ...[
                _DataCollectionCard(totalReadings: totalReadings),
                const SizedBox(height: 16),
                _RecentTasksCard(tasks: completedTasks.take(5).toList()),
              ],
              const SizedBox(height: 16),
              _QuickActionsCard(),
            ],
          );
        },
      ),
    );
  }
}

class _ConnectionStatusCard extends StatelessWidget {
  final BluetoothProvider bluetooth;

  const _ConnectionStatusCard({required this.bluetooth});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: bluetooth.isConnected ? Colors.green.shade50 : Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              bluetooth.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: bluetooth.isConnected ? Colors.green : Colors.orange,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bluetooth.isConnected ? 'Підключено' : 'Не підключено',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    bluetooth.activeDeviceName ?? 'Немає пристрою',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            if (bluetooth.isConnected)
              Column(
                children: [
                  Text(
                    '${bluetooth.batteryPercentage}%',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const Text('Батарея', style: TextStyle(fontSize: 12)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _TasksOverviewCard extends StatelessWidget {
  final int total;
  final int completed;
  final int failed;
  final int pending;

  const _TasksOverviewCard({
    required this.total,
    required this.completed,
    required this.failed,
    required this.pending,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Огляд задач',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatBox('Всього', total.toString(), Colors.blue),
                _StatBox('Завершено', completed.toString(), Colors.green),
                _StatBox('Очікує', pending.toString(), Colors.orange),
                _StatBox('Помилки', failed.toString(), Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox(this.label, this.value, this.color);

  Color _getShade50(Color color) {
    return Color.fromRGBO(
      (color.red * 0.9).round(),
      (color.green * 0.9).round(),
      (color.blue * 0.9).round(),
      0.2,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getShade50(color),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _DataCollectionCard extends StatelessWidget {
  final int totalReadings;

  const _DataCollectionCard({required this.totalReadings});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Зібрані дані',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  totalReadings.toString(),
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                const Text(
                  'зчитувань датчиків',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: totalReadings > 0 ? 1.0 : 0.0,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentTasksCard extends StatelessWidget {
  final List<ScheduledTask> tasks;

  const _RecentTasksCard({required this.tasks});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Останні виконані задачі',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...tasks.map((task) {
              return ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(task.name),
                subtitle: Text(
                  task.executedAt != null
                      ? DateFormat('dd.MM.yyyy HH:mm').format(task.executedAt!)
                      : 'Не виконано',
                ),
                trailing: task.sensorData != null
                    ? Chip(
                        label: Text('${task.sensorData!.length}'),
                        avatar: const Icon(Icons.sensors, size: 16),
                      )
                    : null,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Швидкі дії',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ActionButton(
                  icon: Icons.schedule,
                  label: 'Планувальник',
                  onPressed: () => Navigator.pushNamed(context, '/scheduler'),
                ),
                _ActionButton(
                  icon: Icons.sensors,
                  label: 'Датчики',
                  onPressed: () => Navigator.pushNamed(context, '/sensors-realtime'),
                ),
                _ActionButton(
                  icon: Icons.show_chart,
                  label: 'Телеметрія',
                  onPressed: () => Navigator.pushNamed(context, '/telemetry'),
                ),
                _ActionButton(
                  icon: Icons.settings,
                  label: 'Налаштування',
                  onPressed: () => Navigator.pushNamed(context, '/settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
