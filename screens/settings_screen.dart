import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Налаштування'),
          ),
          body: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Загальні налаштування',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ListTile(
              title: const Text('Показати управління'),
              subtitle: const Text('Демонстрація кнопок та джойстика'),
              trailing: const Icon(Icons.play_circle_outline),
              onTap: () => Navigator.pushNamed(context, '/control-guide'),
            ),
            ListTile(
              title: const Text('Тема оформлення'),
              subtitle: const Text('Світла, темна або як у системі'),
              trailing: DropdownButton<String>(
                value: settings.themeModeValue,
                items: const [
                  DropdownMenuItem(value: 'system', child: Text('Системна')),
                  DropdownMenuItem(value: 'light', child: Text('Світла')),
                  DropdownMenuItem(value: 'dark', child: Text('Темна')),
                ],
                onChanged: (v) {
                  if (v != null) settings.setThemeMode(v);
                },
              ),
            ),
            const Divider(),
              ListTile(
                title: const Text('Швидкість оновлення даних'),
                trailing: DropdownButton<String>(
                  value: settings.updateRate,
                  items: const [
                    DropdownMenuItem(
                      value: '0.5',
                      child: Text('0.5 сек'),
                    ),
                    DropdownMenuItem(
                      value: '1',
                      child: Text('1 сек'),
                    ),
                    DropdownMenuItem(
                      value: '2',
                      child: Text('2 сек'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      settings.setUpdateRate(value);
                    }
                  },
                ),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Налаштування руху',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                title: const Text('Швидкість руху за замовчуванням'),
                trailing: DropdownButton<String>(
                  value: settings.defaultSpeed,
                  items: const [
                    DropdownMenuItem(
                      value: '25',
                      child: Text('25%'),
                    ),
                    DropdownMenuItem(
                      value: '50',
                      child: Text('50%'),
                    ),
                    DropdownMenuItem(
                      value: '75',
                      child: Text('75%'),
                    ),
                    DropdownMenuItem(
                      value: '100',
                      child: Text('100%'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      settings.setDefaultSpeed(value);
                    }
                  },
                ),
              ),
              const Divider(),
              ListTile(
                title: const Text('Чутливість джойстика'),
                trailing: DropdownButton<String>(
                  value: settings.joystickSensitivity,
                  items: const [
                    DropdownMenuItem(
                      value: 'low',
                      child: Text('Низька'),
                    ),
                    DropdownMenuItem(
                      value: 'normal',
                      child: Text('Нормальна'),
                    ),
                    DropdownMenuItem(
                      value: 'high',
                      child: Text('Висока'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      settings.setJoystickSensitivity(value);
                    }
                  },
                ),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Налаштування датчиків',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                title: const Text('Поріг чутливості датчиків лінії'),
                trailing: DropdownButton<String>(
                  value: settings.lineSensorThreshold,
                  items: const [
                    DropdownMenuItem(
                      value: 'low',
                      child: Text('Низька'),
                    ),
                    DropdownMenuItem(
                      value: 'medium',
                      child: Text('Середня'),
                    ),
                    DropdownMenuItem(
                      value: 'high',
                      child: Text('Висока'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      settings.setLineSensorThreshold(value);
                    }
                  },
                ),
              ),
              const Divider(),
              ListTile(
                title: const Text('Відстань виявлення перешкод'),
                trailing: DropdownButton<String>(
                  value: settings.obstacleDistance,
                  items: const [
                    DropdownMenuItem(
                      value: '10',
                      child: Text('10 см'),
                    ),
                    DropdownMenuItem(
                      value: '20',
                      child: Text('20 см'),
                    ),
                    DropdownMenuItem(
                      value: '30',
                      child: Text('30 см'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      settings.setObstacleDistance(value);
                    }
                  },
                ),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Налаштування LED',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                title: const Text('Яскравість LED'),
                trailing: DropdownButton<String>(
                  value: settings.ledBrightness,
                  items: const [
                    DropdownMenuItem(
                      value: '25',
                      child: Text('25%'),
                    ),
                    DropdownMenuItem(
                      value: '50',
                      child: Text('50%'),
                    ),
                    DropdownMenuItem(
                      value: '75',
                      child: Text('75%'),
                    ),
                    DropdownMenuItem(
                      value: '100',
                      child: Text('100%'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      settings.setLedBrightness(value);
                    }
                  },
                ),
              ),
              const Divider(),
              ListTile(
                title: const Text('Швидкість LED анімації'),
                trailing: DropdownButton<String>(
                  value: settings.ledAnimationSpeed,
                  items: const [
                    DropdownMenuItem(
                      value: 'slow',
                      child: Text('Повільна'),
                    ),
                    DropdownMenuItem(
                      value: 'normal',
                      child: Text('Нормальна'),
                    ),
                    DropdownMenuItem(
                      value: 'fast',
                      child: Text('Швидка'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      settings.setLedAnimationSpeed(value);
                    }
                  },
                ),
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Додаткові налаштування',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SwitchListTile(
                title: const Text('Автоматичне підключення'),
                subtitle: const Text('Автоматично підключатися до останнього пристрою'),
                value: settings.autoConnect,
                onChanged: (value) {
                  settings.setAutoConnect(value);
                },
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Вібрація при керуванні'),
                subtitle: const Text('Вібрація при натисканні кнопок керування'),
                value: settings.vibration,
                onChanged: (value) {
                  settings.setVibration(value);
                },
              ),
              const Divider(),
              SwitchListTile(
                title: const Text('Звукові ефекти'),
                subtitle: const Text('Звукові ефекти під час керування'),
                value: settings.soundEffects,
                onChanged: (value) {
                  settings.setSoundEffects(value);
                },
              ),
            ],
          ),
        );
      },
    );
  }
} 