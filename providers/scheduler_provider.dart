import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scheduled_task.dart';
import '../models/route.dart';
import '../models/route_step.dart';
import '../models/sensor_reading.dart';
import '../providers/bluetooth_provider.dart';
import '../utils/logger.dart';

class SchedulerProvider extends ChangeNotifier {
  final List<ScheduledTask> _tasks = [];
  ScheduledTask? _currentlyExecuting;
  Timer? _schedulerTimer;
  SharedPreferences? _prefs;
  final Logger _logger = Logger();

  List<ScheduledTask> get tasks => List.unmodifiable(_tasks);
  ScheduledTask? get currentlyExecuting => _currentlyExecuting;
  bool get isExecuting => _currentlyExecuting != null;

  SchedulerProvider() {
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadTasks();
    _startScheduler();
  }

  Future<void> _loadTasks() async {
    try {
      final tasksJson = _prefs?.getStringList('scheduled_tasks') ?? [];
      _tasks.clear();
      for (final taskJson in tasksJson) {
        try {
          final task = ScheduledTask.fromJson(jsonDecode(taskJson) as Map<String, dynamic>);
          _tasks.add(task);
        } catch (e) {
          _logger.error('Failed to load task: $e');
        }
      }
      notifyListeners();
    } catch (e) {
      _logger.error('Failed to load tasks: $e');
    }
  }

  Future<void> _saveTasks() async {
    try {
      final tasksJson = _tasks.map((t) => jsonEncode(t.toJson())).toList();
      await _prefs?.setStringList('scheduled_tasks', tasksJson);
    } catch (e) {
      _logger.error('Failed to save tasks: $e');
    }
  }

  void _startScheduler() {
    _schedulerTimer?.cancel();
    // Перевірка відбувається кожні 10 секунд, але для автоматичного запуску
    // потрібен доступ до BluetoothProvider, який ми отримаємо через navigatorKey
    _schedulerTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkScheduledTasks();
    });
  }

  Future<void> _checkScheduledTasks() async {
    final now = DateTime.now();
    for (final task in _tasks) {
      if (task.canExecute && 
          now.isAfter(task.scheduledTime.subtract(const Duration(seconds: 5))) &&
          now.isBefore(task.scheduledTime.add(const Duration(seconds: 5))) &&
          _currentlyExecuting == null) {
        _logger.info('Executing scheduled task: ${task.name}');
        // Для автоматичного запуску потрібен BluetoothProvider з контексту
        // Це буде реалізовано через navigatorKey або інший механізм
        // Поки що автоматичний запуск вимагає ручного запуску через UI
        break;
      }
    }
  }

  Future<void> addTask(ScheduledTask task) async {
    _tasks.add(task);
    await _saveTasks();
    notifyListeners();
    _logger.info('Added task: ${task.name}');
  }

  Future<void> updateTask(ScheduledTask updatedTask) async {
    final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
    if (index != -1) {
      _tasks[index] = updatedTask;
      await _saveTasks();
      notifyListeners();
      _logger.info('Updated task: ${updatedTask.name}');
    }
  }

  Future<void> deleteTask(String taskId) async {
    _tasks.removeWhere((t) => t.id == taskId);
    await _saveTasks();
    notifyListeners();
    _logger.info('Deleted task: $taskId');
  }

  Future<void> toggleTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks[index] = _tasks[index].copyWith(enabled: !_tasks[index].enabled);
      await _saveTasks();
      notifyListeners();
    }
  }

  Future<void> executeTask(ScheduledTask task, {required BluetoothProvider bluetoothProvider}) async {
    if (_currentlyExecuting != null) {
      _logger.warning('Task already executing');
      return;
    }

    _currentlyExecuting = task.copyWith(status: TaskStatus.running);
    final index = _tasks.indexWhere((t) => t.id == task.id);
    if (index != -1) {
      _tasks[index] = _currentlyExecuting!;
    }
    notifyListeners();

    final List<SensorReading> sensorData = [];
    final bp = bluetoothProvider;

    try {
      if (!bp.isConnected) {
        throw Exception('Bluetooth не підключено');
      }

      _logger.info('Starting route execution: ${task.route.name}');

      for (int i = 0; i < task.route.steps.length; i++) {
        final step = task.route.steps[i];
        _logger.info('Step ${i + 1}/${task.route.steps.length}: ${step.displayName}');

        if (step.direction == MovementDirection.stop) {
          await bp.stop();
        } else {
          final motionKey = switch (step.direction) {
            MovementDirection.forward => 'Forward',
            MovementDirection.backward => 'Backward',
            MovementDirection.left => 'Left',
            MovementDirection.right => 'Right',
            MovementDirection.stop => 'Forward',
          };

          await bp.motionDown(motionKey, speedPercent: step.speed);

          final readingsPerStep = (step.duration.inMilliseconds / 500).ceil().clamp(1, 20);
          final stepDuration = step.duration.inMilliseconds / readingsPerStep;

          for (int j = 0; j < readingsPerStep; j++) {
            await Future.delayed(Duration(milliseconds: stepDuration.round()));
            sensorData.add(SensorReading(
              timestamp: DateTime.now(),
              batteryVoltage: bp.batteryVoltage,
              batteryPercentage: bp.batteryPercentage,
              temperature: bp.temperature,
              distance: bp.distance,
              lineSensors: List.from(bp.lineSensors),
              leftObstacle: bp.leftObstacle,
              rightObstacle: bp.rightObstacle,
            ));
          }

          await bp.motionUp(motionKey);
        }

        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Завершуємо виконання
      await bp.stop();
      
      final completedTask = task.copyWith(
        status: TaskStatus.completed,
        executedAt: DateTime.now(),
        sensorData: sensorData,
      );

      _currentlyExecuting = null;
      final taskIndex = _tasks.indexWhere((t) => t.id == task.id);
      if (taskIndex != -1) {
        _tasks[taskIndex] = completedTask;
      }
      
      await _saveTasks();
      notifyListeners();

      _logger.info('Task completed: ${task.name}, collected ${sensorData.length} readings');
      
      // Логуємо дані датчиків
      _logger.info('=== Sensor Data Summary ===');
      _logger.info('Total readings: ${sensorData.length}');
      if (sensorData.isNotEmpty) {
        final avgVoltage = sensorData.map((r) => r.batteryVoltage).reduce((a, b) => a + b) / sensorData.length;
        final avgTemp = sensorData.map((r) => r.temperature).reduce((a, b) => a + b) / sensorData.length;
        final avgDist = sensorData.map((r) => r.distance).reduce((a, b) => a + b) / sensorData.length;
        _logger.info('Avg Battery: ${avgVoltage.toStringAsFixed(2)}V');
        _logger.info('Avg Temperature: ${avgTemp.toStringAsFixed(2)}°C');
        _logger.info('Avg Distance: ${avgDist.toStringAsFixed(2)}cm');
      }
      _logger.info('==========================');

    } catch (e) {
      _logger.error('Task execution failed: $e');
      
      final failedTask = task.copyWith(
        status: TaskStatus.failed,
        executedAt: DateTime.now(),
        sensorData: sensorData.isNotEmpty ? sensorData : null,
        errorMessage: e.toString(),
      );

      _currentlyExecuting = null;
      final taskIndex = _tasks.indexWhere((t) => t.id == task.id);
      if (taskIndex != -1) {
        _tasks[taskIndex] = failedTask;
      }
      
      await _saveTasks();
      notifyListeners();
    }
  }

  Future<void> cancelExecution() async {
    if (_currentlyExecuting != null) {
      _logger.info('Cancelling task execution');
      _currentlyExecuting = _currentlyExecuting!.copyWith(status: TaskStatus.cancelled);
      final index = _tasks.indexWhere((t) => t.id == _currentlyExecuting!.id);
      if (index != -1) {
        _tasks[index] = _currentlyExecuting!;
      }
      _currentlyExecuting = null;
      await _saveTasks();
      notifyListeners();
    }
  }

  String exportTaskDataToCsv(String taskId) {
    final task = _tasks.firstWhere((t) => t.id == taskId, orElse: () => throw Exception('Task not found'));
    if (task.sensorData == null || task.sensorData!.isEmpty) {
      throw Exception('No sensor data available');
    }

    final buffer = StringBuffer();
    buffer.writeln(SensorReading.csvHeader());
    for (final reading in task.sensorData!) {
      buffer.writeln(reading.toCsvRow());
    }
    return buffer.toString();
  }

  String exportTaskDataToJson(String taskId) {
    final task = _tasks.firstWhere((t) => t.id == taskId, orElse: () => throw Exception('Task not found'));
    return jsonEncode(task.toJson());
  }

  @override
  void dispose() {
    _schedulerTimer?.cancel();
    super.dispose();
  }
}
