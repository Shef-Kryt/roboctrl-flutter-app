import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _updateRateKey = 'update_rate';
  static const String _defaultSpeedKey = 'default_speed';
  static const String _joystickSensitivityKey = 'joystick_sensitivity';
  static const String _lineSensorThresholdKey = 'line_sensor_threshold';
  static const String _obstacleDistanceKey = 'obstacle_distance';
  static const String _ledBrightnessKey = 'led_brightness';
  static const String _ledAnimationSpeedKey = 'led_animation_speed';
  static const String _autoConnectKey = 'auto_connect';
  static const String _vibrationKey = 'vibration';
  static const String _soundEffectsKey = 'sound_effects';
  /// `system` | `light` | `dark`
  static const String _themeModeKey = 'theme_mode';

  late SharedPreferences _prefs;
  
  String _updateRate = '1';
  String _defaultSpeed = '50';
  String _joystickSensitivity = 'normal';
  String _lineSensorThreshold = 'medium';
  String _obstacleDistance = '20';
  String _ledBrightness = '100';
  String _ledAnimationSpeed = 'normal';
  bool _autoConnect = false;
  bool _vibration = true;
  bool _soundEffects = true;
  String _themeMode = 'system';

  String get updateRate => _updateRate;
  String get defaultSpeed => _defaultSpeed;
  String get joystickSensitivity => _joystickSensitivity;
  String get lineSensorThreshold => _lineSensorThreshold;
  String get obstacleDistance => _obstacleDistance;
  String get ledBrightness => _ledBrightness;
  String get ledAnimationSpeed => _ledAnimationSpeed;
  bool get autoConnect => _autoConnect;
  bool get vibration => _vibration;
  bool get soundEffects => _soundEffects;
  ThemeMode get themeMode => switch (_themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
  String get themeModeValue => _themeMode;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    
    _updateRate = _prefs.getString(_updateRateKey) ?? '1';
    _defaultSpeed = _prefs.getString(_defaultSpeedKey) ?? '50';
    _joystickSensitivity = _prefs.getString(_joystickSensitivityKey) ?? 'normal';
    _lineSensorThreshold = _prefs.getString(_lineSensorThresholdKey) ?? 'medium';
    _obstacleDistance = _prefs.getString(_obstacleDistanceKey) ?? '20';
    _ledBrightness = _prefs.getString(_ledBrightnessKey) ?? '100';
    _ledAnimationSpeed = _prefs.getString(_ledAnimationSpeedKey) ?? 'normal';
    _autoConnect = _prefs.getBool(_autoConnectKey) ?? false;
    _vibration = _prefs.getBool(_vibrationKey) ?? true;
    _soundEffects = _prefs.getBool(_soundEffectsKey) ?? true;
    _themeMode = _prefs.getString(_themeModeKey) ?? 'system';

    notifyListeners();
  }

  Future<void> setUpdateRate(String value) async {
    _updateRate = value;
    await _prefs.setString(_updateRateKey, value);
    notifyListeners();
  }

  Future<void> setDefaultSpeed(String value) async {
    _defaultSpeed = value;
    await _prefs.setString(_defaultSpeedKey, value);
    notifyListeners();
  }

  Future<void> setJoystickSensitivity(String value) async {
    _joystickSensitivity = value;
    await _prefs.setString(_joystickSensitivityKey, value);
    notifyListeners();
  }

  Future<void> setLineSensorThreshold(String value) async {
    _lineSensorThreshold = value;
    await _prefs.setString(_lineSensorThresholdKey, value);
    notifyListeners();
  }

  Future<void> setObstacleDistance(String value) async {
    _obstacleDistance = value;
    await _prefs.setString(_obstacleDistanceKey, value);
    notifyListeners();
  }

  Future<void> setLedBrightness(String value) async {
    _ledBrightness = value;
    await _prefs.setString(_ledBrightnessKey, value);
    notifyListeners();
  }

  Future<void> setLedAnimationSpeed(String value) async {
    _ledAnimationSpeed = value;
    await _prefs.setString(_ledAnimationSpeedKey, value);
    notifyListeners();
  }

  Future<void> setAutoConnect(bool value) async {
    _autoConnect = value;
    await _prefs.setBool(_autoConnectKey, value);
    notifyListeners();
  }

  Future<void> setVibration(bool value) async {
    _vibration = value;
    await _prefs.setBool(_vibrationKey, value);
    notifyListeners();
  }

  Future<void> setSoundEffects(bool value) async {
    _soundEffects = value;
    await _prefs.setBool(_soundEffectsKey, value);
    notifyListeners();
  }

  Future<void> setThemeMode(String value) async {
    if (value != 'system' && value != 'light' && value != 'dark') return;
    _themeMode = value;
    await _prefs.setString(_themeModeKey, value);
    notifyListeners();
  }
} 