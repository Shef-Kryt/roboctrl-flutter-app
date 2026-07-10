import 'package:flutter/material.dart';
import '../models/route_step.dart';

class StepEditorDialog extends StatefulWidget {
  final RouteStep? existingStep;

  const StepEditorDialog({super.key, this.existingStep});

  @override
  State<StepEditorDialog> createState() => _StepEditorDialogState();
}

class _StepEditorDialogState extends State<StepEditorDialog> {
  MovementDirection _direction = MovementDirection.forward;
  int _speed = 50;
  int _durationSeconds = 2;
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existingStep != null) {
      _direction = widget.existingStep!.direction;
      _speed = widget.existingStep!.speed;
      _durationSeconds = widget.existingStep!.duration.inSeconds;
      _descriptionController.text = widget.existingStep!.description ?? '';
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingStep != null ? 'Редагувати крок' : 'Новий крок'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<MovementDirection>(
              value: _direction,
              decoration: const InputDecoration(
                labelText: 'Напрямок',
                border: OutlineInputBorder(),
              ),
              items: MovementDirection.values.map((dir) {
                return DropdownMenuItem(
                  value: dir,
                  child: Text(_getDirectionLabel(dir)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _direction = value);
              },
            ),
            const SizedBox(height: 16),
            Text('Швидкість: $_speed%'),
            Slider(
              value: _speed.toDouble(),
              min: 10,
              max: 100,
              divisions: 9,
              label: '$_speed%',
              onChanged: (value) => setState(() => _speed = value.round()),
            ),
            const SizedBox(height: 16),
            Text('Тривалість: $_durationSeconds сек'),
            Slider(
              value: _durationSeconds.toDouble(),
              min: 1,
              max: 30,
              divisions: 29,
              label: '$_durationSeconds сек',
              onChanged: (value) => setState(() => _durationSeconds = value.round()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Опис (необов\'язково)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Скасувати'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Зберегти'),
        ),
      ],
    );
  }

  String _getDirectionLabel(MovementDirection dir) {
    switch (dir) {
      case MovementDirection.forward:
        return 'Вперед';
      case MovementDirection.backward:
        return 'Назад';
      case MovementDirection.left:
        return 'Вліво';
      case MovementDirection.right:
        return 'Вправо';
      case MovementDirection.stop:
        return 'Стоп';
    }
  }

  void _save() {
    final step = RouteStep(
      direction: _direction,
      speed: _speed,
      duration: Duration(seconds: _durationSeconds),
      description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
    );
    Navigator.pop(context, step);
  }
}
