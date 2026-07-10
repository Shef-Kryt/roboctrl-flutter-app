import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/scheduler_provider.dart';
import '../providers/bluetooth_provider.dart';
import '../models/scheduled_task.dart';
import '../models/route.dart' as models;
import '../models/route_step.dart';
import 'route_editor_screen.dart';
import 'task_details_screen.dart';
import '../utils/bluetooth_error_dialog.dart';

class SchedulerScreen extends StatelessWidget {
  const SchedulerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Планувальник задач'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Додати задачу',
            onPressed: () => _showAddTaskDialog(context),
          ),
        ],
      ),
      body: Consumer<SchedulerProvider>(
        builder: (context, scheduler, child) {
          if (scheduler.tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.schedule, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Немає запланованих задач',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _showAddTaskDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Створити задачу'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              if (scheduler.isExecuting)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.blue.shade50,
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Виконується: ${scheduler.currentlyExecuting?.name ?? "..."}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: () => scheduler.cancelExecution(),
                        child: const Text('Скасувати'),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: scheduler.tasks.length,
                  itemBuilder: (context, index) {
                    final task = scheduler.tasks[index];
                    return _TaskCard(task: task);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const RouteEditorScreen(),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final ScheduledTask task;

  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final scheduler = context.watch<SchedulerProvider>();
    final isOverdue = task.isOverdue;
    final timeUntil = task.scheduledTime.difference(DateTime.now());

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: _getStatusColor(task.status),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskDetailsScreen(task: task),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Switch(
                    value: task.enabled,
                    onChanged: (value) => scheduler.toggleTask(task.id),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 16,
                    color: isOverdue ? Colors.red : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd.MM.yyyy HH:mm').format(task.scheduledTime),
                    style: TextStyle(
                      color: isOverdue ? Colors.red : null,
                      fontWeight: isOverdue ? FontWeight.bold : null,
                    ),
                  ),
                  if (!isOverdue && timeUntil.inDays == 0)
                    Text(
                      ' (через ${_formatDuration(timeUntil)})',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.route, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Маршрут: ${task.route.name}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${task.route.steps.length} кроків)',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _StatusChip(status: task.status),
                  const Spacer(),
                  if (task.sensorData != null && task.sensorData!.isNotEmpty)
                    Chip(
                      avatar: const Icon(Icons.sensors, size: 16),
                      label: Text('${task.sensorData!.length} зчитувань'),
                      backgroundColor: Colors.green.shade100,
                    ),
                ],
              ),
              if (task.errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, size: 16, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          task.errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (task.status == TaskStatus.pending || task.status == TaskStatus.failed) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final bluetooth = context.read<BluetoothProvider>();
                      if (!bluetooth.isConnected) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Потрібне підключення до робота')),
                        );
                        return;
                      }
                      await scheduler.executeTask(task, bluetoothProvider: bluetooth);
                      if (!context.mounted) return;
                      final updated = scheduler.tasks.firstWhere((t) => t.id == task.id);
                      if (updated.status == TaskStatus.failed && updated.errorMessage != null) {
                        showBluetoothConnectionErrorDialog(context, updated.errorMessage!);
                      }
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Запустити зараз'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.pending:
        return Colors.white;
      case TaskStatus.running:
        return Colors.blue.shade50;
      case TaskStatus.completed:
        return Colors.green.shade50;
      case TaskStatus.failed:
        return Colors.red.shade50;
      case TaskStatus.cancelled:
        return Colors.grey.shade200;
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours} год ${duration.inMinutes % 60} хв';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} хв';
    } else {
      return '${duration.inSeconds} сек';
    }
  }
}

class _StatusChip extends StatelessWidget {
  final TaskStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = _getStatusInfo(status);
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
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
