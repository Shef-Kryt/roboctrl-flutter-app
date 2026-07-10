import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../models/route.dart' as models;
import '../models/route_step.dart';
import '../models/scheduled_task.dart';
import '../providers/scheduler_provider.dart';
import 'step_editor_dialog.dart';

class RouteEditorScreen extends StatefulWidget {
  final models.Route? existingRoute;
  final ScheduledTask? existingTask;

  const RouteEditorScreen({
    super.key,
    this.existingRoute,
    this.existingTask,
  });

  @override
  State<RouteEditorScreen> createState() => _RouteEditorScreenState();
}

class _RouteEditorScreenState extends State<RouteEditorScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _taskNameController = TextEditingController();
  List<RouteStep> _steps = [];
  DateTime? _scheduledTime;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    if (widget.existingRoute != null) {
      _nameController.text = widget.existingRoute!.name;
      _descriptionController.text = widget.existingRoute!.description ?? '';
      _steps = List.from(widget.existingRoute!.steps);
    }
    if (widget.existingTask != null) {
      _taskNameController.text = widget.existingTask!.name;
      _scheduledTime = widget.existingTask!.scheduledTime;
      _enabled = widget.existingTask!.enabled;
    } else {
      _scheduledTime = DateTime.now().add(const Duration(hours: 1));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _taskNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingRoute != null ? 'Редагувати маршрут' : 'Новий маршрут'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _taskNameController,
            decoration: const InputDecoration(
              labelText: 'Назва задачі',
              hintText: 'Наприклад: Обхід території о 10:00',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Назва маршруту',
              hintText: 'Наприклад: Квадратний обхід',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Опис (необов\'язково)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Час виконання'),
            subtitle: Text(
              _scheduledTime != null
                  ? DateFormat('dd.MM.yyyy HH:mm').format(_scheduledTime!)
                  : 'Не вибрано',
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _scheduledTime ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_scheduledTime ?? DateTime.now()),
                );
                if (time != null) {
                  setState(() {
                    _scheduledTime = DateTime(
                      date.year,
                      date.month,
                      date.day,
                      time.hour,
                      time.minute,
                    );
                  });
                }
              }
            },
          ),
          SwitchListTile(
            title: const Text('Увімкнено'),
            subtitle: const Text('Задача буде виконана в запланований час'),
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Кроки маршруту',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: _addStep,
                icon: const Icon(Icons.add),
                label: const Text('Додати крок'),
              ),
            ],
          ),
          if (_steps.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Додайте кроки маршруту',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...List.generate(_steps.length, (index) {
              return _StepCard(
                step: _steps[index],
                index: index,
                onEdit: () => _editStep(index),
                onDelete: () => _deleteStep(index),
              );
            }),
          const SizedBox(height: 16),
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Оцінка тривалості:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _calculateEstimatedDuration(),
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _canSave() ? _saveTask : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Зберегти задачу'),
          ),
        ],
      ),
    );
  }

  void _addStep() async {
    final step = await showDialog<RouteStep>(
      context: context,
      builder: (context) => const StepEditorDialog(),
    );
    if (step != null) {
      setState(() => _steps.add(step));
    }
  }

  void _editStep(int index) async {
    final step = await showDialog<RouteStep>(
      context: context,
      builder: (context) => StepEditorDialog(existingStep: _steps[index]),
    );
    if (step != null) {
      setState(() => _steps[index] = step);
    }
  }

  void _deleteStep(int index) {
    setState(() => _steps.removeAt(index));
  }

  bool _canSave() {
    return _taskNameController.text.isNotEmpty &&
        _nameController.text.isNotEmpty &&
        _steps.isNotEmpty &&
        _scheduledTime != null;
  }

  String _calculateEstimatedDuration() {
    if (_steps.isEmpty) return '0 хвилин';
    final duration = _steps.fold<Duration>(
      Duration.zero,
      (sum, step) => sum + step.duration,
    );
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '$minutes хв ${seconds > 0 ? '$seconds сек' : ''}';
    } else {
      return '$seconds сек';
    }
  }

  void _saveTask() {
    if (!_canSave()) return;

    final uuid = Uuid();
    final route = models.Route(
      id: widget.existingRoute?.id ?? uuid.v4(),
      name: _nameController.text,
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
      steps: _steps,
      createdAt: widget.existingRoute?.createdAt ?? DateTime.now(),
    );

    final task = ScheduledTask(
      id: widget.existingTask?.id ?? uuid.v4(),
      name: _taskNameController.text,
      route: route,
      scheduledTime: _scheduledTime!,
      enabled: _enabled,
    );

    final scheduler = context.read<SchedulerProvider>();
    if (widget.existingTask != null) {
      scheduler.updateTask(task);
    } else {
      scheduler.addTask(task);
    }

    Navigator.pop(context);
  }
}

class _StepCard extends StatelessWidget {
  final RouteStep step;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StepCard({
    required this.step,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          child: Text('${index + 1}'),
        ),
        title: Text(step.displayName),
        subtitle: Text(
          'Швидкість: ${step.speed}%, Тривалість: ${_formatDuration(step.duration)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}с';
    } else {
      return '${duration.inMinutes}хв';
    }
  }
}
