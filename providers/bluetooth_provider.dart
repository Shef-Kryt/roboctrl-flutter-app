import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' show sqrt;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_bluetooth_classic_serial/flutter_bluetooth_classic.dart' as classic;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/robot_device.dart';
import '../models/route_step.dart';
import '../utils/logger.dart' show Logger;
import '../utils/picogo_protocol.dart';

class BluetoothProvider extends ChangeNotifier {
  BluetoothProvider() {
    _init();
  }

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static const _lastDeviceIdKey = 'last_device_id';
  static const _lastDeviceNameKey = 'last_device_name';
  static const _lastDeviceLinkKey = 'last_device_link';
  static const _deviceAliasesKey = 'device_aliases';
  static const _deviceHistoryKey = 'device_history';
  static const _deviceLinkTypesKey = 'device_link_types';
  static const _isObstacleAvoidanceEnabledAdv='isObstacleAvoidanceEnabledAdv';
  final List<RobotDevice> _devices = [];
  final Map<String, BluetoothDevice> _bleRefs = {};
  final classic.FlutterBluetoothClassic _classic = classic.FlutterBluetoothClassic();
  final Logger _logger = Logger();

  BluetoothDevice? _connectedBleDevice;
  String? _connectedClassicAddress;
  RobotLinkType? _activeLinkType;
  StreamSubscription<List<int>>? _bleDataSubscription;
  StreamSubscription<classic.BluetoothData>? _classicDataSubscription;
  StreamSubscription<List<ScanResult>>? _bleScanSubscription;
  Timer? _classicRefreshTimer;
  BluetoothCharacteristic? _bleWriteCharacteristic;
  String _robotMode = 'manual';               // <── ДОДАТИ
  String get robotMode => _robotMode;
  bool _isConnected = false;
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _classicBridgeReady = false;
  StreamSubscription<classic.BluetoothConnectionState>? _classicConnectionSubscription;
  DateTime? _classicLinkSince;
  bool _classicSocketReady = false;
  bool _disconnecting = false;
  Completer<bool>? _connectWaiter;

  String _rxBuffer = '';
  String? _activeMotionKey;
  bool _motionHoldRequested = false;
  int _motionEpoch = 0;
  bool _joystickDriving = false;
  String _speedPreset = 'Medium';
  String? _lastRobotState;
  DateTime? _lastTelemetryAt;

  SharedPreferences? _prefs;
  String? _lastDeviceId;
  String? _lastDeviceName;
  RobotLinkType? _lastDeviceLink;
  Map<String, String> _deviceAliases = {};
  Map<String, String> _deviceLinkTypes = {};
  List<String> _deviceHistoryIds = [];

  double _batteryVoltage = 0.0;
  int _batteryPercentage = 0;
  double _temperature = 0.0;
  double _distance = 0.0;
  List<int> _lineSensors = List.filled(5, 0);
  bool _leftObstacle = false;
  bool _rightObstacle = false;
  List<Color> _ledColors = List.filled(4, Colors.black);

  bool _isLineFollowingEnabled = false;
  bool _isObstacleAvoidanceEnabled = false;
  bool _isLedAnimationEnabled = false;
  bool _buzzerOn = false;
  static const int _telemetryHistoryMax = 240;
  final List<double> _voltageHistory = [];
  final List<double> _temperatureHistory = [];
  final List<double> _distanceHistory = [];

  bool get _supportsClassic =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isWindows);

  List<RobotDevice> get devices {
    final list = List<RobotDevice>.from(_devices);
    list.sort((a, b) => RobotDevice.sortPriority(a).compareTo(RobotDevice.sortPriority(b)));
    return List.unmodifiable(list);
  }

  Future<void> _setRobotMode(String mode) async {   // <── ДОДАТИ весь метод
    _robotMode = mode;
    _isObstacleAvoidanceEnabled = mode == 'obstacle';
    _isLineFollowingEnabled     = mode == 'line';
    await sendPicogo({'Mode': mode});
    notifyListeners();
  }
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  bool get isConnecting => _isConnecting;
  bool get canReconnect => _lastDeviceId != null;
  String? get lastDeviceName => _lastDeviceName;
  RobotLinkType? get lastDeviceLink => _lastDeviceLink;

  String? get activeDeviceName {
    if (_isConnected) {
      if (_activeLinkType == RobotLinkType.classicSpp && _connectedClassicAddress != null) {
        final match = _devices.where((d) => d.id == _connectedClassicAddress);
        if (match.isNotEmpty) return _displayName(match.first);
      }
      if (_connectedBleDevice != null) {
        final name = _connectedBleDevice!.platformName;
        if (name.isNotEmpty) return _displayNameForId(_connectedBleDevice!.remoteId.str, name);
      }
    }
    return _lastDeviceName;
  }

  double get batteryVoltage => _batteryVoltage;
  int get batteryPercentage => _batteryPercentage;
  double get temperature => _temperature;
  double get distance => _distance;
  List<int> get lineSensors => _lineSensors;
  bool get leftObstacle => _leftObstacle;
  bool get rightObstacle => _rightObstacle;
  bool get isLineFollowingEnabled => _isLineFollowingEnabled;
  bool get isObstacleAvoidanceEnabled => _isObstacleAvoidanceEnabled;
  bool get isLedAnimationEnabled => _isLedAnimationEnabled;
  bool get buzzerOn => _buzzerOn;
  List<Color> get ledColors => _ledColors;
  List<double> get voltageHistory => List.unmodifiable(_voltageHistory);
  List<double> get temperatureHistory => List.unmodifiable(_temperatureHistory);
  List<double> get distanceHistory => List.unmodifiable(_distanceHistory);
  List<String> get deviceHistoryIds => List.unmodifiable(_deviceHistoryIds);
  String get speedPreset => _speedPreset;
  String? get lastRobotState => _lastRobotState;
  bool get hasTelemetry => _lastTelemetryAt != null;

  bool isConnectedToId(String deviceId) {
    if (!_isConnected) return false;
    final normalized = RobotDevice.normalizeId(deviceId);
    if (_activeLinkType == RobotLinkType.classicSpp) {
      return _connectedClassicAddress == normalized;
    }
    return _connectedBleDevice?.remoteId.str == deviceId ||
        RobotDevice.normalizeId(_connectedBleDevice?.remoteId.str ?? '') == normalized;
  }

  bool isConnectedTo(RobotDevice device) => isConnectedToId(device.id);

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    _lastDeviceId = _prefs?.getString(_lastDeviceIdKey);
    _lastDeviceName = _prefs?.getString(_lastDeviceNameKey);
    final linkRaw = _prefs?.getString(_lastDeviceLinkKey);
    _lastDeviceLink = _parseLinkType(linkRaw);
    _loadDeviceMeta();
    _ensureClassicBridge();
    notifyListeners();
  }

  void _loadDeviceMeta() {
    final aliasesRaw = _prefs?.getString(_deviceAliasesKey);
    if (aliasesRaw != null && aliasesRaw.isNotEmpty) {
      final decoded = jsonDecode(aliasesRaw);
      if (decoded is Map) {
        _deviceAliases = decoded.map((key, value) => MapEntry(key.toString(), value.toString()));
      }
    }

    final linkTypesRaw = _prefs?.getString(_deviceLinkTypesKey);
    if (linkTypesRaw != null && linkTypesRaw.isNotEmpty) {
      final decoded = jsonDecode(linkTypesRaw);
      if (decoded is Map) {
        _deviceLinkTypes = decoded.map((key, value) => MapEntry(key.toString(), value.toString()));
      }
    }

    final historyRaw = _prefs?.getStringList(_deviceHistoryKey);
    if (historyRaw != null) {
      _deviceHistoryIds = List<String>.from(historyRaw);
    }
  }

  RobotLinkType? _parseLinkType(String? raw) {
    if (raw == 'classic') return RobotLinkType.classicSpp;
    if (raw == 'ble') return RobotLinkType.ble;
    return null;
  }

  String _linkTypeStorage(RobotLinkType type) =>
      type == RobotLinkType.classicSpp ? 'classic' : 'ble';

  /// Один раз: прийом байтів + події з'єднання (без completer/таймерів).
  void _ensureClassicBridge() {
    if (!_supportsClassic || _classicBridgeReady) return;

    _classicDataSubscription = _classic.onDataReceived.listen(
      (data) {
        if (data.data.isEmpty) return;
        _onClassicSocketUp('rx');
        _handleIncomingChunk(String.fromCharCodes(data.data));
      },
      onError: (e) => _logger.error('Classic RX: $e'),
    );

    _classicConnectionSubscription = _classic.onConnectionChanged.listen((state) {
      _logger.info('SPP: ${state.status} (${state.deviceAddress})');

      if (state.isConnected) {
        _onClassicSocketUp('connected');
        return;
      }

      if (_isConnecting) return;
      if (!_isConnected || _activeLinkType != RobotLinkType.classicSpp) return;

      final status = state.status;
      if (!status.contains('DISCONNECTED') && !status.contains('ERROR')) return;

      final since = _classicLinkSince;
      if (since != null && DateTime.now().difference(since) < const Duration(seconds: 3)) {
        return;
      }

      _logger.warning('SPP розірвано: $status');
      _markDisconnected();
    });

    _classicBridgeReady = true;
  }

  void _onClassicSocketUp(String reason) {
    _classicSocketReady = true;
    final waiter = _connectWaiter;
    if (waiter != null && !waiter.isCompleted) {
      _logger.info('SPP готовий ($reason)');
      waiter.complete(true);
    }
  }

  void _markDisconnected({bool notify = true}) {
    if (!_isConnected && !_classicSocketReady) return;
    _classicSocketReady = false;
    _isConnected = false;
    _isConnecting = false;
    _connectedClassicAddress = null;
    _activeLinkType = null;
    _classicLinkSince = null;
    _activeMotionKey = null;
    _joystickDriving = false;
    _rxBuffer = '';
    if (notify) notifyListeners();
  }

  Future<void> _prepareRadioForConnect() async {
    _classicRefreshTimer?.cancel();
    _classicRefreshTimer = null;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    if (_supportsClassic) {
      try {
        await _classic.stopDiscovery();
      } catch (_) {}
    }
    _isScanning = false;
  }

  double? _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  Future<bool> requestPermissions() async {
    final locationStatus = await Permission.location.request();
    if (!locationStatus.isGranted) {
      await _showPermissionDialog(
        title: 'Потрібен доступ до геолокації',
        content: 'Для пошуку Bluetooth пристроїв потрібен доступ до геолокації.',
      );
      return false;
    }

    final bluetoothScan = await Permission.bluetoothScan.request();
    if (!bluetoothScan.isGranted) {
      await _showPermissionDialog(
        title: 'Потрібен доступ до пошуку пристроїв',
        content: 'Для пошуку Bluetooth пристроїв потрібен відповідний дозвіл.',
      );
      return false;
    }

    final bluetoothConnect = await Permission.bluetoothConnect.request();
    if (!bluetoothConnect.isGranted) {
      await _showPermissionDialog(
        title: 'Потрібен доступ до підключення',
        content: 'Для підключення до Bluetooth пристроїв потрібен відповідний дозвіл.',
      );
      return false;
    }

    return true;
  }

  Future<void> _showPermissionDialog({
    required String title,
    required String content,
  }) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Скасувати'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(true);
                await openAppSettings();
              },
              child: const Text('Відкрити налаштування'),
            ),
          ],
        );
      },
    );
  }

  void _upsertDevice(RobotDevice device) {
    final id = RobotDevice.normalizeId(device.id);
    final normalized = RobotDevice(
      id: id,
      nativeName: device.nativeName,
      linkType: device.linkType,
    );
    final index = _devices.indexWhere((d) => d.id == id && d.linkType == device.linkType);
    if (index >= 0) {
      _devices[index] = normalized;
    } else {
      _devices.add(normalized);
    }
  }

  Future<void> _refreshClassicDevices() async {
    if (!_supportsClassic) return;
    try {
      final enabled = await _classic.isBluetoothEnabled();
      if (!enabled) return;
      final paired = await _classic.getPairedDevices();
      for (final device in paired) {
        final name = device.name.isNotEmpty ? device.name : 'Невідомий пристрій';
        _upsertDevice(
          RobotDevice(
            id: RobotDevice.normalizeId(device.address),
            nativeName: name,
            linkType: RobotLinkType.classicSpp,
          ),
        );
      }
      notifyListeners();
    } catch (e) {
      _logger.error('Classic paired devices error: $e');
    }
  }

  Future<void> startScan() async {
    if (!await requestPermissions()) return;

    _devices.clear();
    _bleRefs.clear();
    _isScanning = true;
    notifyListeners();

    try {
      _ensureClassicBridge();

      if (_supportsClassic) {
        await _refreshClassicDevices();
        await _classic.startDiscovery();
        _classicRefreshTimer?.cancel();
        _classicRefreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
          _refreshClassicDevices();
        });
      }

      await _bleScanSubscription?.cancel();
      _bleScanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final ble = result.device;
          final id = RobotDevice.normalizeId(ble.remoteId.str);
          _bleRefs[id] = ble;
          final name = ble.platformName.isNotEmpty ? ble.platformName : 'Невідомий пристрій';
          _upsertDevice(
            RobotDevice(id: id, nativeName: name, linkType: RobotLinkType.ble),
          );
        }
        notifyListeners();
      });

      final bondedBle = await FlutterBluePlus.systemDevices([]);
      for (final ble in bondedBle) {
        final id = RobotDevice.normalizeId(ble.remoteId.str);
        _bleRefs[id] = ble;
        final name = ble.platformName.isNotEmpty ? ble.platformName : 'Невідомий пристрій';
        _upsertDevice(
          RobotDevice(id: id, nativeName: name, linkType: RobotLinkType.ble),
        );
      }
      notifyListeners();

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 6),
        androidUsesFineLocation: false,
        androidScanMode: AndroidScanMode.lowLatency,
      );

      Future.delayed(const Duration(seconds: 6), () {
        if (_isScanning) stopScan();
      });
    } catch (e) {
      _logger.error('startScan error: $e');
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> stopScan() async {
    _classicRefreshTimer?.cancel();
    _classicRefreshTimer = null;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    if (_supportsClassic) {
      try {
        await _classic.stopDiscovery();
        await _refreshClassicDevices();
      } catch (_) {}
    }
    _isScanning = false;
    notifyListeners();
  }

  Future<void> reconnectToLastKnown() async {
    if (_lastDeviceId == null || _isConnected || _isConnecting) return;
    await connectToDeviceId(_lastDeviceId!);
  }

  RobotLinkType? _linkTypeForId(String deviceIdStr) {
    final normalized = RobotDevice.normalizeId(deviceIdStr);
    final stored = _deviceLinkTypes[normalized] ?? _deviceLinkTypes[deviceIdStr];
    return _parseLinkType(stored) ?? _lastDeviceLink;
  }

  Future<void> connectToDeviceId(String deviceIdStr) async {
    if (_isConnected || _isConnecting) return;

    final normalized = RobotDevice.normalizeId(deviceIdStr);
    final preferredLink = _linkTypeForId(normalized);

    RobotDevice? target;
    try {
      target = _devices.firstWhere((d) => d.id == normalized);
    } catch (_) {}

    if (target != null) {
      await connect(target);
      return;
    }

    if (preferredLink == RobotLinkType.ble) {
      await startScan();
      await Future.delayed(const Duration(milliseconds: 1200));
      try {
        target = _devices.firstWhere((d) => d.id == normalized && d.linkType == RobotLinkType.ble);
        await connect(target);
        return;
      } catch (_) {}
      throw Exception('Пристрій не знайдено');
    }

    if (_supportsClassic) {
      try {
        await _connectClassic(normalized, _deviceAliases[normalized] ?? 'PicoGo');
        return;
      } catch (e) {
        if (preferredLink == RobotLinkType.classicSpp) rethrow;
        _logger.info('Classic reconnect failed, trying BLE: $e');
      }
    }

    await startScan();
    await Future.delayed(const Duration(milliseconds: 1200));
    try {
      target = _devices.firstWhere((d) => d.id == normalized);
      await connect(target);
    } catch (_) {
      throw Exception('Пристрій не знайдено');
    }
  }

  Future<void> connect(RobotDevice device) async {
    if (!await requestPermissions()) {
      throw Exception('Немає дозволів Bluetooth');
    }
    await _prepareRadioForConnect();

    if (device.isBleVariantWarning) {
      throw Exception(
        'Обрано JDY-33-BLE. Для PicoGo потрібен JDY-33-SPP (Classic Bluetooth). '
        'Спаруйте «JDY-33-SPP» у налаштуваннях телефону.',
      );
    }

    if (device.linkType == RobotLinkType.classicSpp) {
      await _connectClassic(device.id, device.nativeName);
    } else {
      await _connectBle(device);
    }
  }

  Future<void> _connectClassic(String address, String nativeName) async {
    if (!_supportsClassic) {
      throw Exception('Classic Bluetooth (SPP) підтримується лише на Android/iOS/Windows');
    }

    _ensureClassicBridge();
    final normalized = RobotDevice.normalizeId(address);

    if (_isConnected &&
        _activeLinkType == RobotLinkType.classicSpp &&
        _connectedClassicAddress == normalized) {
      return;
    }

    _isConnecting = true;
    notifyListeners();

    try {
      _rxBuffer = '';

      if (_activeLinkType == RobotLinkType.classicSpp) {
        _isConnected = false;
        _connectedClassicAddress = null;
        _activeLinkType = null;
        try {
          await _classic.disconnect();
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 250));
      }

      _logger.info('SPP connect → $normalized ($nativeName)');

      if (!await _classic.isBluetoothEnabled()) {
        throw Exception('Увімкніть Bluetooth на телефоні');
      }

      classic.BluetoothDevice? match;
      for (final d in await _classic.getPairedDevices()) {
        if (RobotDevice.normalizeId(d.address) == normalized) {
          match = d;
          break;
        }
      }
      if (match == null) {
        throw Exception(
          'JDY-33-SPP не в списку спарених. Спаруйте робота в налаштуваннях Bluetooth.',
        );
      }

      _classicSocketReady = false;
      _connectWaiter = Completer<bool>();

      final started = await _classic.connect(match.address);
      if (!started) {
        throw Exception('Не вдалося підключитися до JDY-33-SPP');
      }

      var socketUp = false;
      try {
        socketUp = await _connectWaiter!.future.timeout(
          const Duration(seconds: 12),
          onTimeout: () => _classicSocketReady,
        );
      } finally {
        _connectWaiter = null;
      }

      if (!socketUp) {
        try {
          await _classic.disconnect();
        } catch (_) {}
        throw Exception('SPP не відкрився. Перевірте JDY-33-SPP і перезавантажте Pico.');
      }

      _connectedClassicAddress = normalized;
      _activeLinkType = RobotLinkType.classicSpp;
      _isConnected = true;
      _classicLinkSince = DateTime.now();
      _rememberDevice(normalized, nativeName, RobotLinkType.classicSpp);
    } catch (e) {
      _logger.error('Classic connect error: $e');
      _markDisconnected(notify: false);
      rethrow;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> _connectBle(RobotDevice device) async {
    _isConnecting = true;
    notifyListeners();

    try {
      await disconnect();

      BluetoothDevice? bleDevice = _bleRefs[device.id];
      if (bleDevice == null) {
        await startScan();
        await Future.delayed(const Duration(seconds: 2));
        bleDevice = _bleRefs[device.id];
      }
      if (bleDevice == null) {
        throw Exception('BLE пристрій не знайдено під час сканування');
      }

      _logger.info('Connecting BLE to ${bleDevice.remoteId.str} (${bleDevice.platformName})');
      await bleDevice.connect(timeout: const Duration(seconds: 8));
      await Future.delayed(const Duration(milliseconds: 200));

      final services = await bleDevice.discoverServices();
      BluetoothCharacteristic? sppCharacteristic;

      for (final service in services) {
        if (service.uuid.toString().toUpperCase().contains('FFE0')) {
          for (final characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toUpperCase().contains('FFE1')) {
              sppCharacteristic = characteristic;
              break;
            }
          }
          break;
        }
      }

      if (sppCharacteristic == null) {
        throw Exception(
          'На пристрої не знайдено BLE-сервіс FFE0/FFE1. '
          'Для PicoGo оберіть JDY-33-SPP (Classic), а не JDY-33-BLE.',
        );
      }

      await sppCharacteristic.setNotifyValue(true);
      _bleWriteCharacteristic = sppCharacteristic;
      _bleDataSubscription = sppCharacteristic.onValueReceived.listen((data) {
        _handleIncomingChunk(utf8.decode(data));
      });

      _connectedBleDevice = bleDevice;
      _activeLinkType = RobotLinkType.ble;
      _isConnected = true;
      final name = bleDevice.platformName.isNotEmpty ? bleDevice.platformName : device.nativeName;
      _rememberDevice(device.id, name, RobotLinkType.ble);
      await applySpeedPreset(presetKey: _speedPreset, force: true);
    } catch (e) {
      _logger.error('BLE connect error: $e');
      await disconnect();
      rethrow;
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> sendPicogo(Map<String, String> command) async {
    if (!_isConnected || _isConnecting) return;
    if (_activeLinkType == RobotLinkType.classicSpp && !_classicSocketReady) return;

    final payload = PicogoProtocol.encode(command);
    await _sendRawNow(payload);
  }

  Future<void> _sendRawNow(String payload) async {
    if (!_isConnected || _isConnecting) return;
    if (_activeLinkType == RobotLinkType.classicSpp && !_classicSocketReady) return;

    _logger.debug('TX: $payload');
    final bytes = utf8.encode('$payload\n');

    try {
      if (_activeLinkType == RobotLinkType.classicSpp) {
        final ok = await _classic.sendData(bytes);
        if (!ok) _markDisconnected();
        return;
      }

      final characteristic = _bleWriteCharacteristic;
      if (characteristic == null) return;

      if (characteristic.properties.writeWithoutResponse) {
        await characteristic.write(bytes, withoutResponse: true);
      } else {
        await characteristic.write(bytes);
      }
    } on classic.BluetoothException catch (e) {
      _logger.error('Send: $e');
      final msg = e.message;
      if (msg.contains('NOT_CONNECTED') || msg.contains('Not connected')) {
        _markDisconnected();
      }
    } catch (e) {
      _logger.error('Send: $e');
    }
  }

  void _handleIncomingChunk(String chunk) {
    if (chunk.isEmpty) return;
    _rxBuffer += chunk;
    final objects = PicogoProtocol.extractJsonObjects(_rxBuffer);
    _rxBuffer = PicogoProtocol.remainingBuffer(_rxBuffer);

    for (final jsonStr in objects) {
      _logger.debug('RX: $jsonStr');
      _processJsonPayload(jsonStr);
    }

    final leftover = _rxBuffer.trim();
    if (leftover.isNotEmpty && !leftover.contains('{')) {
      _processIncomingData(leftover);
      _rxBuffer = '';
    }
  }

  void _processJsonPayload(String jsonStr) {
    final obj = PicogoProtocol.tryParseObject(jsonStr);
    if (obj == null) {
      _processIncomingData(jsonStr);
      return;
    }

    var telemetryUpdated = false;
    for (final entry in obj.entries) {
      final key = entry.key;
      final value = entry.value;
      final keyLower = key.toLowerCase();

      if (keyLower == 'temperature') {
        final v = _readDouble(value);
        if (v != null) {
          _temperature = v;
          telemetryUpdated = true;
          _pushTelemetry(_temperatureHistory, _temperature);
        }
      } else if (keyLower == 'voltage') {
        final v = _readDouble(value);
        if (v != null) {
          _batteryVoltage = v;
          telemetryUpdated = true;
          _pushTelemetry(_voltageHistory, _batteryVoltage);
        }
      } else if (keyLower == 'percent') {
        final v = _readDouble(value);
        if (v != null) {
          _batteryPercentage = v.round();
          telemetryUpdated = true;
        }
      } else if (keyLower == 'distance') {
        final v = _readDouble(value);
        if (v != null && v >= 0) {
          _distance = v;
          telemetryUpdated = true;
          _pushTelemetry(_distanceHistory, _distance);
        }
      } else if (keyLower == 'state') {
        _lastRobotState = value?.toString();
        if (_lastRobotState != null) {
          _parseStateTelemetry(_lastRobotState!);
        }
      } else if (keyLower == 'bz') {
        final s = value?.toString().toUpperCase();
        if (s == 'ON' || s == 'OFF') {
          _buzzerOn = s == 'ON';
        }
      } else if (keyLower == 'led') {
        final s = value?.toString().toUpperCase();
        if (s == 'ON' || s == 'OFF') {
          _isLedAnimationEnabled = s == 'ON';
        }
      } else if (keyLower == 'obstacle_left') {
        final v = _readDouble(value);
        if (v != null) {
          _leftObstacle = v != 0;
          telemetryUpdated = true;
        }
      } else if (keyLower == 'obstacle_right') {
        final v = _readDouble(value);
        if (v != null) {
          _rightObstacle = v != 0;
          telemetryUpdated = true;
        }
      } else if (keyLower == 'mode') {
        final m = value?.toString();
        if (m != null) {
          _robotMode = m;
          _isObstacleAvoidanceEnabled = m == 'obstacle';
          _isLineFollowingEnabled = m == 'line';
          telemetryUpdated = true;
        }
      }
    }
    if (telemetryUpdated) {
      _lastTelemetryAt = DateTime.now();
    }
    notifyListeners();
  }

  /// Телеметрія в рядку State або текстових відповідях (якщо прошивка надсилає).
  void _parseStateTelemetry(String state) {
    final tempMatch = RegExp(r'temperature[^0-9]*(\d+\.?\d*)', caseSensitive: false).firstMatch(state);
    if (tempMatch != null) {
      _temperature = double.tryParse(tempMatch.group(1)!) ?? _temperature;
      _pushTelemetry(_temperatureHistory, _temperature);
    }
    final voltMatch = RegExp(r'voltage[^0-9]*(\d+\.?\d*)', caseSensitive: false).firstMatch(state);
    if (voltMatch != null) {
      _batteryVoltage = double.tryParse(voltMatch.group(1)!) ?? _batteryVoltage;
      _pushTelemetry(_voltageHistory, _batteryVoltage);
    }
    final pctMatch = RegExp(r'percent[^0-9]*(\d+\.?\d*)', caseSensitive: false).firstMatch(state);
    if (pctMatch != null) {
      _batteryPercentage = double.tryParse(pctMatch.group(1)!)?.round() ?? _batteryPercentage;
    }
  }

  Future<void> disconnect({bool silent = false}) async {
    if (_disconnecting) return;
    if (!_isConnected && !_isConnecting) return;
    _disconnecting = true;

    try {
      final motionKey = _activeMotionKey;
      final link = _activeLinkType;
      final ble = _connectedBleDevice;
      final socketReady = _classicSocketReady;

      _isConnecting = false;
      _isConnected = false;
      _classicSocketReady = false;
      _activeLinkType = null;
      _connectedClassicAddress = null;
      _classicLinkSince = null;
      _activeMotionKey = null;
      _motionHoldRequested = false;
      _motionEpoch++;
      _joystickDriving = false;

      if (motionKey != null && link != null && socketReady) {
        try {
          final payload = PicogoProtocol.encode(PicogoProtocol.motion(motionKey, pressed: false));
          if (link == RobotLinkType.classicSpp) {
            await _classic.sendData(utf8.encode('$payload\n'));
          } else if (_bleWriteCharacteristic != null) {
            await _bleWriteCharacteristic!.write(utf8.encode('$payload\n'));
          }
        } catch (_) {}
      }

      await _bleDataSubscription?.cancel();
      _bleDataSubscription = null;

      if (_supportsClassic && link == RobotLinkType.classicSpp) {
        try {
          await _classic.disconnect();
        } catch (_) {}
      }

      try {
        await ble?.disconnect();
      } catch (_) {}
      _connectedBleDevice = null;
      _bleWriteCharacteristic = null;
      _rxBuffer = '';
      _resetState();
      _logger.info('Disconnected');
      notifyListeners();
    } finally {
      _disconnecting = false;
    }
  }

  void _resetState() {
    _batteryVoltage = 0.0;
    _batteryPercentage = 0;
    _temperature = 0.0;
    _distance = 0.0;
    _lineSensors = List.filled(5, 0);
    _leftObstacle = false;
    _rightObstacle = false;
    _isLineFollowingEnabled = false;
    _isObstacleAvoidanceEnabled = false;
    _isLedAnimationEnabled = false;
    _buzzerOn = false;
    _lastTelemetryAt = null;
    _lastRobotState = null;
    _ledColors = List.filled(4, Colors.black);
    clearTelemetryHistory(notify: false);
  }

  void _processIncomingData(String message) {
    try {
      var updated = false;
      if (message.contains('temperature')) {
        final tempMatch = RegExp(r'temperature\s*:\s*(\d+\.?\d*)').firstMatch(message);
        final tempValue = tempMatch?.group(1);
        if (tempValue != null) {
          _temperature = double.tryParse(tempValue) ?? 0.0;
          _pushTelemetry(_temperatureHistory, _temperature);
          updated = true;
        }
      }

      if (message.contains('Voltage')) {
        final voltMatch = RegExp(r'Voltage\s*:\s*(\d+\.?\d*)').firstMatch(message);
        final voltValue = voltMatch?.group(1);
        if (voltValue != null) {
          _batteryVoltage = double.tryParse(voltValue) ?? 0.0;
          _pushTelemetry(_voltageHistory, _batteryVoltage);
          updated = true;
        }
      }

      if (message.contains('percent')) {
        final percentMatch = RegExp(r'percent\s*:\s*(\d+\.?\d*)').firstMatch(message);
        final percentValue = percentMatch?.group(1);
        if (percentValue != null) {
          _batteryPercentage = double.tryParse(percentValue)?.round() ?? 0;
          updated = true;
        }
      }
      if (updated) _lastTelemetryAt = DateTime.now();

      if (message.contains('Distance')) {
        final distMatch = RegExp(r'Distance\s*:\s*(\d+\.?\d*)').firstMatch(message);
        final distValue = distMatch?.group(1);
        if (distValue != null) {
          _distance = double.tryParse(distValue) ?? 0.0;
          _pushTelemetry(_distanceHistory, _distance);
        }
      }

      if (message.contains('line_sensors')) {
        final sensorsMatch = RegExp(r'line_sensors:\s*\[([\d,\s]+)\]').firstMatch(message);
        final sensorsValue = sensorsMatch?.group(1);
        if (sensorsValue != null) {
          _lineSensors = sensorsValue
              .split(',')
              .map((s) => int.tryParse(s.trim()) ?? 0)
              .toList();
        }
      }

      if (message.contains('obstacles')) {
        _leftObstacle = message.contains('left:1');
        _rightObstacle = message.contains('right:1');
      }

      notifyListeners();
    } catch (e) {
      _logger.error('Process incoming data error: $e');
    }
  }

  void _pushTelemetry(List<double> list, double value) {
    list.add(value);
    if (list.length > _telemetryHistoryMax) {
      list.removeAt(0);
    }
  }

  void clearTelemetryHistory({bool notify = true}) {
    _voltageHistory.clear();
    _temperatureHistory.clear();
    _distanceHistory.clear();
    if (notify) notifyListeners();
  }

  Future<void> applySpeedPreset({int? speedPercent, String? presetKey, bool force = false}) async {
    final key = presetKey ?? PicogoProtocol.speedKeyForPercent(speedPercent ?? 50);
    if (!force && _speedPreset == key) return;
    _speedPreset = key;
    await sendPicogo(PicogoProtocol.speedPreset(key));
    notifyListeners();
  }

  Future<void> setSpeedPreset(String key) async {
    if (!PicogoProtocol.speedKeys.contains(key)) return;
    await applySpeedPreset(presetKey: key);
  }

  Future<void> motionDown(String motionKey, {int? speedPercent}) async {
    if (!PicogoProtocol.motionKeys.contains(motionKey)) return;
    _motionHoldRequested = true;
    final epoch = ++_motionEpoch;

    // У main.py Left/Right завжди з фікс. швидкістю 20; пресет лише для Forward/Backward.
    if (motionKey == 'Forward' || motionKey == 'Backward') {
      await applySpeedPreset(speedPercent: speedPercent);
      if (!_motionHoldRequested || epoch != _motionEpoch) return;
    }

    if (_activeMotionKey != null && _activeMotionKey != motionKey) {
      await sendPicogo(PicogoProtocol.motion(_activeMotionKey!, pressed: false));
      if (!_motionHoldRequested || epoch != _motionEpoch) return;
    }
    if (_activeMotionKey == motionKey) return;

    _activeMotionKey = motionKey;
    await sendPicogo(PicogoProtocol.motion(motionKey, pressed: true));
  }

  Future<void> motionUp([String? motionKey]) async {
    await stop();
  }

  /// Зупинка при відпусканні джойстика / кнопок (скасовує очікувані Down).
  Future<void> stop() async {
    _motionHoldRequested = false;
    _motionEpoch++;
    _joystickDriving = false;

    final key = _activeMotionKey;
    _activeMotionKey = null;

    if (key != null) {
      await sendPicogo(PicogoProtocol.motion(key, pressed: false));
    }
  }

  /// Керування джойстиком: рух лише поки палець на екрані.
  Future<void> handleJoystick(
    double x,
    double y, {
    required double deadZone,
    required double gain,
  }) async {
    final cx = (x * gain).clamp(-1.0, 1.0);
    final cy = (y * gain).clamp(-1.0, 1.0);
    final magnitude = (cx * cx + cy * cy);

    if (magnitude < deadZone * deadZone) {
      if (_joystickDriving) {
        _joystickDriving = false;
        await stop();
      }
      return;
    }

    final effective =
        ((sqrt(magnitude) - deadZone) / (1.0 - deadZone)).clamp(0.0, 1.0);
    final speed = (effective * 100).round().clamp(10, 100);

    final String motionKey;
    if (cy.abs() > cx.abs()) {
      motionKey = cy < 0 ? 'Forward' : 'Backward';
    } else {
      motionKey = cx > 0 ? 'Right' : 'Left';
    }

    _joystickDriving = true;
    await motionDown(motionKey, speedPercent: speed);
  }

  Future<void> releaseJoystick() async {
    if (_joystickDriving || _activeMotionKey != null) {
      await stop();
    }
  }

  Future<void> moveForward(int speed) => motionDown('Forward', speedPercent: speed);
  Future<void> moveBackward(int speed) => motionDown('Backward', speedPercent: speed);
  Future<void> turnLeft(int speed) => motionDown('Left', speedPercent: speed);
  Future<void> turnRight(int speed) => motionDown('Right', speedPercent: speed);

  Future<void> runRouteStep({
    required MovementDirection direction,
    required int speed,
    required Duration duration,
  }) async {
    if (direction == MovementDirection.stop) {
      await stop();
      return;
    }

    final motionKey = switch (direction) {
      MovementDirection.forward => 'Forward',
      MovementDirection.backward => 'Backward',
      MovementDirection.left => 'Left',
      MovementDirection.right => 'Right',
      MovementDirection.stop => 'Forward',
    };

    await motionDown(motionKey, speedPercent: speed);
    await Future.delayed(duration);
    await motionUp(motionKey);
  }

  Future<void> requestStatus() async {}

  Future<void> requestDistance() async {}

  Future<void> requestLineSensors() async {}

  void toggleLineFollowing() {
    _setRobotMode(_isLineFollowingEnabled ? 'manual' : 'line');
  }

  void toggleObstacleAvoidance() {
    _setRobotMode(_isObstacleAvoidanceEnabled ? 'manual' : 'obstacle');
  }

  void toggleBoardLed() {
    _isLedAnimationEnabled = !_isLedAnimationEnabled;
    sendPicogo(PicogoProtocol.boardLed(on: _isLedAnimationEnabled));
    notifyListeners();
  }

  void toggleBuzzer() {
    _buzzerOn = !_buzzerOn;
    sendPicogo(PicogoProtocol.buzzer(on: _buzzerOn));
    notifyListeners();
  }

  void setLedColor(int index, Color color) {
    if (index >= 0 && index < _ledColors.length) {
      for (var i = 0; i < _ledColors.length; i++) {
        _ledColors[i] = color;
      }
      sendPicogo(PicogoProtocol.rgbAll(color.red, color.green, color.blue));
      notifyListeners();
    }
  }

  void setAllLedColor(Color color) {
    for (int i = 0; i < _ledColors.length; i++) {
      _ledColors[i] = color;
    }
    sendPicogo(PicogoProtocol.rgbAll(color.red, color.green, color.blue));
    notifyListeners();
  }

  void setBoardLed(bool on) {
    _isLedAnimationEnabled = on;
    sendPicogo(PicogoProtocol.boardLed(on: on));
    notifyListeners();
  }

  void setBuzzer(bool on) {
    _buzzerOn = on;
    sendPicogo(PicogoProtocol.buzzer(on: on));
    notifyListeners();
  }

  @Deprecated('Анімації NeoPixel не підтримуються цією прошивкою')
  void startLedAnimation(String type) {}

  @Deprecated('Анімації NeoPixel не підтримуються цією прошивкою')
  void stopLedAnimation() {}

  String _displayName(RobotDevice device) => _displayNameForId(device.id, device.nativeName);

  String _displayNameForId(String id, String nativeName) {
    final normalized = RobotDevice.normalizeId(id);
    return _deviceAliases[normalized] ?? _deviceAliases[id] ?? nativeName;
  }

  @override
  void dispose() {
    _classicRefreshTimer?.cancel();
    _bleScanSubscription?.cancel();
    _classicDataSubscription?.cancel();
    _classicConnectionSubscription?.cancel();
    _classicBridgeReady = false;
    Future.microtask(() => disconnect(silent: true));
    super.dispose();
  }

  void _rememberDevice(String id, String nativeName, RobotLinkType linkType) {
    final normalized = RobotDevice.normalizeId(id);
    _lastDeviceId = normalized;
    _lastDeviceName = _deviceAliases[normalized] ?? nativeName;
    _lastDeviceLink = linkType;
    _prefs?.setString(_lastDeviceIdKey, normalized);
    _prefs?.setString(_lastDeviceNameKey, _lastDeviceName!);
    _prefs?.setString(_lastDeviceLinkKey, _linkTypeStorage(linkType));
    _deviceLinkTypes[normalized] = _linkTypeStorage(linkType);
    _prefs?.setString(_deviceLinkTypesKey, jsonEncode(_deviceLinkTypes));

    _deviceHistoryIds.remove(normalized);
    _deviceHistoryIds.insert(0, normalized);
    if (_deviceHistoryIds.length > 30) {
      _deviceHistoryIds = _deviceHistoryIds.take(30).toList();
    }
    _prefs?.setStringList(_deviceHistoryKey, _deviceHistoryIds);
    notifyListeners();
  }

  String getDisplayNameForDevice(String id, {String? fallbackName}) {
    return _displayNameForId(id, fallbackName ?? 'Невідомий пристрій');
  }

  String linkTypeLabelForDevice(String id) {
    final link = _linkTypeForId(id);
    if (link == RobotLinkType.classicSpp) return 'Classic SPP';
    if (link == RobotLinkType.ble) return 'BLE';
    return 'Невідомо';
  }

  Future<void> renameDevice(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final normalized = RobotDevice.normalizeId(id);
    _deviceAliases[normalized] = trimmed;
    await _prefs?.setString(_deviceAliasesKey, jsonEncode(_deviceAliases));
    if (_lastDeviceId == normalized) {
      _lastDeviceName = trimmed;
      await _prefs?.setString(_lastDeviceNameKey, trimmed);
    }
    notifyListeners();
  }

  Future<void> clearDeviceAlias(String id) async {
    final normalized = RobotDevice.normalizeId(id);
    _deviceAliases.remove(normalized);
    await _prefs?.setString(_deviceAliasesKey, jsonEncode(_deviceAliases));
    notifyListeners();
  }
}
