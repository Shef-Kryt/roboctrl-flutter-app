import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';

class ControlGuideScreen extends StatefulWidget {
  const ControlGuideScreen({super.key});

  @override
  State<ControlGuideScreen> createState() => _ControlGuideScreenState();
}

class _ControlGuideScreenState extends State<ControlGuideScreen> {
  double _joystickX = 0;
  double _joystickY = 0;
  String _action = 'Режим очікування';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Гайд з управління'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _buildTips(),
          const SizedBox(height: 16),
          _buildJoystickDemo(),
          const SizedBox(height: 16),
          _buildButtonsDemo(),
          const SizedBox(height: 16),
          _buildStatusCard(),
        ],
      ),
    );
  }

  Widget _buildTips() {
    final tips = [
    ];

    return Column(
      children: tips
          .map(
            (tip) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(tip.$1),
                title: Text(tip.$2),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildJoystickDemo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Джойстик',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const SizedBox(height: 16),
            Joystick(
              onStickDragEnd: () {
                setState(() {
                  _joystickX = 0;
                  _joystickY = 0;
                  _action = 'Режим очікування';
                });
              },
              listener: (details) {
                setState(() {
                  _joystickX = details.x;
                  _joystickY = details.y;
                  _action = _describeDirection(details.x, details.y);
                });
              },
            ),
            const SizedBox(height: 12),
            Text(
              'X: ${_joystickX.toStringAsFixed(2)}, Y: ${_joystickY.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButtonsDemo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            const SizedBox(height: 1),
            const SizedBox(height: 1),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDemoButton('Вперед', Icons.arrow_upward),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildDemoButton('Вліво', Icons.arrow_back),
                    const SizedBox(width: 7),
                    _buildDemoButton('Стоп', Icons.stop_circle, color: Colors.red),
                    const SizedBox(width: 4),
                    _buildDemoButton('Вправо', Icons.arrow_forward),
                  ],
                ),
                _buildDemoButton('Назад', Icons.arrow_downward),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Поточна дія',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _action,
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  String _describeDirection(double x, double y) {
    final magnitude = (x * x + y * y);
    if (magnitude < 0.42 * 0.42) return 'Очікування (мертва зона)';
    if (y.abs() > x.abs()) {
      return y < 0 ? 'Рух вперед' : 'Рух назад';
    } else {
      return x > 0 ? 'Поворот вправо' : 'Поворот вліво';
    }
  }

  Widget _buildDemoButton(String label, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          backgroundColor: color,
        ),
        onPressed: () {
          setState(() {
            _action = label;
          });
        },
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

