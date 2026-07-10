import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/settings_provider.dart';
import 'dart:async';
import 'dart:math' show sqrt;
import '../widgets/direction_control.dart';
import '../utils/bluetooth_error_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  Timer? _statusTimer;
  late TabController _tabController;
  Duration _pollInterval = const Duration(seconds: 1);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final settings = context.read<SettingsProvider>();
      if (settings.autoConnect) {
        try {
          await context.read<BluetoothProvider>().reconnectToLastKnown();
        } catch (e) {
          if (mounted) showBluetoothConnectionErrorDialog(context, e);
        }
      }
      _updatePollingFromSettings(settings);
    });
  }

  Future<void> _tryReconnectLastDevice(BuildContext context) async {
    try {
      await context.read<BluetoothProvider>().reconnectToLastKnown();
    } catch (e) {
      if (!context.mounted) return;
      showBluetoothConnectionErrorDialog(context, e);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // На випадок, якщо SettingsProvider підвантажився пізніше.
    _updatePollingFromSettings(context.read<SettingsProvider>());
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _startStatusTimer() {
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final provider = context.read<BluetoothProvider>();
      if (provider.isConnected) {
        provider.requestStatus();
      }
    });
  }

  void _restartStatusTimer(Duration interval) {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(interval, (timer) {
      final provider = context.read<BluetoothProvider>();
      if (provider.isConnected) {
        provider.requestStatus();
      }
    });
  }

  void _updatePollingFromSettings(SettingsProvider settings) {
    final parsed = double.tryParse(settings.updateRate);
    final seconds = (parsed == null || parsed <= 0) ? 1.0 : parsed;
    final interval = Duration(milliseconds: (seconds * 1000).round());
    if (interval != _pollInterval) {
      _pollInterval = interval;
      _restartStatusTimer(_pollInterval);
    } else if (_statusTimer == null) {
      _restartStatusTimer(_pollInterval);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Контролер'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Меню',
            onSelected: (value) {
              switch (value) {
                case 'dashboard':
                  Navigator.pushNamed(context, '/dashboard');
                  break;
                case 'sensors':
                  Navigator.pushNamed(context, '/sensors-realtime');
                  break;
                case 'scheduler':
                  Navigator.pushNamed(context, '/scheduler');
                  break;
                case 'telemetry':
                  Navigator.pushNamed(context, '/telemetry');
                  break;
                case 'logs':
                  Navigator.pushNamed(context, '/logs');
                  break;
                case 'devices-history':
                  Navigator.pushNamed(context, '/devices-history');
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'dashboard',
                child: Row(
                  children: [
                    Icon(Icons.dashboard, size: 20),
                    SizedBox(width: 12),
                    Text('Статистика'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'sensors',
                child: Row(
                  children: [
                    Icon(Icons.sensors, size: 20),
                    SizedBox(width: 12),
                    Text('Датчики'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'scheduler',
                child: Row(
                  children: [
                    Icon(Icons.schedule, size: 20),
                    SizedBox(width: 12),
                    Text('Планувальник'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'telemetry',
                child: Row(
                  children: [
                    Icon(Icons.show_chart, size: 20),
                    SizedBox(width: 12),
                    Text('Телеметрія'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'devices-history',
                child: Row(
                  children: [
                    Icon(Icons.devices, size: 20),
                    SizedBox(width: 12),
                    Text('Мої пристрої'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logs',
                child: Row(
                  children: [
                    Icon(Icons.article_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Логи'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Налаштування',
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
          IconButton(
            icon: const Icon(Icons.bluetooth),
            tooltip: 'Bluetooth',
            onPressed: () => _showBluetoothDevices(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Джойстик'),
            Tab(text: 'Кнопки'),
          ],
        ),
      ),
      body: Consumer<BluetoothProvider>(
        builder: (context, provider, child) {
          if (!provider.isConnected) {
            return Column(
              children: [
                _buildConnectionBanner(context),
                Expanded(child: _buildDisconnectedState(context)),
              ],
            );
          }

          return Column(
            children: [
              _buildConnectionBanner(context, compact: true),
              _buildModeSwitches(context),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildJoystickTab(context),
                    _buildButtonsTab(context),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildJoystickTab(BuildContext context) {
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final joystickSize = (constraints.maxHeight * 0.48).clamp(180.0, 280.0);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                children: [
                  SizedBox(
                    height: joystickSize + 30,
                    child: Center(
                      child: _buildJoystick(context, size: joystickSize),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildExtrasPanel(context),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildButtonsTab(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Center(
                    child: SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: const DirectionControl(),
                    ),
                  );
                },
              ),
            ),
            _buildExtrasPanel(context),
          ],
        ),
      ),
    );
  }

  Widget _buildExtrasPanel(BuildContext context) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: const Text('Датчики та LED', style: TextStyle(fontSize: 14)),
      children: [
        _buildSensorsDisplay(context),
        const SizedBox(height: 8),
        _buildLedControls(context),
      ],
    );
  }

  Widget _buildModeSwitches(BuildContext context) {
    final provider = context.watch<BluetoothProvider>();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          for (final preset in ['Low', 'Medium', 'High'])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(preset == 'Low' ? 'Повільно' : preset == 'Medium' ? 'Середньо' : 'Швидко'),
                selected: provider.speedPreset == preset,
                onSelected: (_) => provider.setSpeedPreset(preset),
              ),
            ),
          ChoiceChip(
            label: const Text('Лінія'),
            selected: provider.isLineFollowingEnabled,
            onSelected: (_) => provider.toggleLineFollowing(),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Перешкоди'),
            selected: provider.isObstacleAvoidanceEnabled,
            onSelected: (_) => provider.toggleObstacleAvoidance(),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('LED'),
            selected: provider.isLedAnimationEnabled,
            onSelected: (_) => provider.toggleBoardLed(),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Бузер'),
            selected: provider.buzzerOn,
            onSelected: (_) => provider.toggleBuzzer(),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionBanner(BuildContext context, {bool compact = false}) {
    final provider = context.watch<BluetoothProvider>();
    final scheme = Theme.of(context).colorScheme;
    final isConnected = provider.isConnected;
    final color = isConnected ? scheme.primaryContainer : scheme.surfaceContainerHighest;
    final icon = isConnected ? Icons.check_circle : Icons.bluetooth_searching;
    final title = isConnected ? 'Підключено' : 'Немає підключення';
    final subtitle = provider.activeDeviceName ?? 'Невідомий пристрій';
    final actionLabel = provider.isConnecting
        ? 'Підключення...'
        : isConnected
            ? 'Відключити'
            : provider.canReconnect
                ? 'Підключити'
                : 'Сканувати';
    final VoidCallback? action = provider.isConnecting
        ? null
        : isConnected
            ? () => provider.disconnect()
            : provider.canReconnect
                ? () => _tryReconnectLastDevice(context)
                : () => _showBluetoothDevices(context);

    if (compact && isConnected) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: scheme.onPrimaryContainer, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${provider.batteryPercentage}% · '
                        '${provider.batteryVoltage.toStringAsFixed(1)} V · '
                        '${provider.temperature.toStringAsFixed(1)}°C · '
                        '${provider.distance.toStringAsFixed(0)} см',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onPrimaryContainer.withOpacity(0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: action,
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onPrimaryContainer,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(actionLabel),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isConnected ? scheme.onPrimaryContainer : scheme.primary,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isConnected ? scheme.onPrimaryContainer : scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isConnected
                      ? subtitle
                      : provider.lastDeviceName != null
                          ? 'Останній: ${provider.lastDeviceName}. Натисніть «Підключити», щоб з’єднатися знову.'
                          : 'Натисніть «Сканувати» вгорі або кнопку праворуч, щоб знайти робота поблизу.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: isConnected ? scheme.onPrimaryContainer.withOpacity(0.92) : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: action,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildDisconnectedState(BuildContext context) {
    final provider = context.watch<BluetoothProvider>();
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Підключіть робота через Bluetooth',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Увімкніть робота, дозвольте доступ до Bluetooth і оберіть його в списку після сканування.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (provider.canReconnect)
              TextButton.icon(
                onPressed: provider.isConnecting ? null : () => _tryReconnectLastDevice(context),
                icon: const Icon(Icons.history),
                label: Text(provider.isConnecting ? 'Підключення...' : 'Підключити останній пристрій'),
              ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: provider.isScanning ? null : () => _showBluetoothDevices(context),
              icon: const Icon(Icons.search),
              label: Text(provider.isScanning ? 'Пошук...' : 'Сканувати пристрої'),
            ),
          ],
        ),
      ),
    );
  }

  /// Мертва зона джойстика (0…1): стільки від центру ігнорується.
  static const double _joystickDeadZone = 0.42;

  Widget _buildJoystick(BuildContext context, {required double size}) {
    final settings = context.watch<SettingsProvider>();
    final sensitivity = settings.joystickSensitivity;
    final double gain = switch (sensitivity) {
      'low' => 0.7,
      'high' => 1.2,
      _ => 1.0,
    };
    return SizedBox(
      width: size,
      height: size,
      child: Joystick(
        onStickDragEnd: () {
          context.read<BluetoothProvider>().releaseJoystick();
        },
        listener: (details) {
          context.read<BluetoothProvider>().handleJoystick(
                details.x,
                details.y,
                deadZone: _joystickDeadZone,
                gain: gain,
              );
        },
      ),
    );
  }

  Widget _buildSensorsDisplay(BuildContext context) {
    final provider = context.watch<BluetoothProvider>();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Відстань (HC-SR04): ${provider.distance.toStringAsFixed(1)} см'),
            const SizedBox(height: 8),
            if (provider.lastRobotState != null && provider.lastRobotState!.isNotEmpty)
              Text('Стан: ${provider.lastRobotState}', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 6),
            if (!provider.hasTelemetry)
              Text(
                'Очікування телеметрії (до 3 с)…',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: Theme.of(context).colorScheme.error,
                ),
              )
            else
              Text(
                'Телеметрія: ${provider.temperature.toStringAsFixed(1)}°C, '
                '${provider.batteryVoltage.toStringAsFixed(2)} V, ${provider.batteryPercentage}%',
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLedControls(BuildContext context) {
    final provider = context.watch<BluetoothProvider>();
    final colors = [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.yellow,
      Colors.purple,
      Colors.white,
      Colors.black,
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Керування LED:'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(4, (index) {
                return PopupMenuButton<Color>(
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: provider.ledColors[index],
                      border: Border.all(),
                    ),
                  ),
                  itemBuilder: (context) {
                    return colors.map((color) {
                      return PopupMenuItem(
                        value: color,
                        child: Container(
                          width: 30,
                          height: 30,
                          color: color,
                        ),
                      );
                    }).toList();
                  },
                  onSelected: (color) => provider.setLedColor(index, color),
                );
              }),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                PopupMenuButton<Color>(
                  child: const Text('Всі LED'),
                  itemBuilder: (context) {
                    return colors
                        .map((color) => PopupMenuItem(
                              value: color,
                              child: Row(
                                children: [
                                  Container(width: 18, height: 18, color: color),
                                  const SizedBox(width: 8),
                                  Text(color == Colors.black ? 'Вимк.' : 'Колір'),
                                ],
                              ),
                            ))
                        .toList();
                  },
                  onSelected: provider.setAllLedColor,
                ),
                TextButton(
                  onPressed: () => provider.setBoardLed(!provider.isLedAnimationEnabled),
                  child: Text(provider.isLedAnimationEnabled ? 'LED вимк.' : 'LED вмк.'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBluetoothDevices(BuildContext context) async {
    final provider = context.read<BluetoothProvider>();
    
    try {
      if (!await provider.requestPermissions()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Потрібні дозволи для роботи з Bluetooth')),
          );
        }
        return;
      }

      await provider.startScan();

      if (!context.mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Доступні пристрої'),
          content: SizedBox(
            width: double.maxFinite,
            child: Consumer<BluetoothProvider>(
              builder: (context, provider, child) {
                if (provider.isScanning) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Пошук пристроїв...'),
                      ],
                    ),
                  );
                }

                if (provider.devices.isEmpty) {
                  return const Center(
                    child: Text('Пристрої не знайдені'),
                  );
                }

                return SizedBox(
                  height: 360,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Для PicoGo оберіть JDY-33-SPP (Classic Bluetooth). '
                          'Варіант JDY-33-BLE не підтримується офіційним застосунком Waveshare.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: provider.devices.length,
                          itemBuilder: (context, index) {
                          final device = provider.devices[index];
                          final name = provider.getDisplayNameForDevice(
                            device.id,
                            fallbackName: device.nativeName,
                          );

                          return ListTile(
                            title: Text(name),
                            subtitle: Text('${device.id} · ${device.linkTypeLabel}'),
                            leading: device.isRecommendedForPicoGo
                                ? const Icon(Icons.check_circle, color: Colors.green)
                                : device.isBleVariantWarning
                                    ? const Icon(Icons.warning_amber, color: Colors.orange)
                                    : const Icon(Icons.bluetooth),
                            trailing: provider.isConnected && provider.isConnectedTo(device)
                                ? const Icon(Icons.bluetooth_connected, color: Colors.green)
                                : null,
                            onTap: () async {
                              if (!provider.isConnected) {
                                try {
                                  await provider.connect(device);
                                  if (context.mounted) Navigator.pop(context);
                                } catch (e) {
                                  if (context.mounted) {
                                    showBluetoothConnectionErrorDialog(context, e);
                                  }
                                }
                              }
                            },
                          );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Скасувати'),
            ),
            TextButton(
              onPressed: provider.isScanning ? null : () => provider.startScan(),
              child: const Text('Оновити'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Помилка при роботі з Bluetooth: $e')),
        );
      }
    }
  }
}