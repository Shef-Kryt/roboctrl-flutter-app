import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical
}

class Logger {
  static final Logger _instance = Logger._internal();
  factory Logger() => _instance;
  Logger._internal();

  List<String> _logs = [];
  bool _enabled = false;
  LogLevel _minLevel = LogLevel.info;
  static const int _maxLogs = 1000;

  bool get enabled => _enabled;
  LogLevel get minLevel => _minLevel;
  List<String> get logs => List.unmodifiable(_logs);

  void enable() {
    _enabled = true;
    _log(LogLevel.info, 'Logger увімкнутий');
  }

  void disable() {
    _enabled = false;
    _log(LogLevel.info, 'Logger вимкнутий');
  }

  void setLevel(LogLevel level) {
    _minLevel = level;
    _log(LogLevel.info, 'Log level set to $level');
  }

  void debug(String message) => _log(LogLevel.debug, message);
  void info(String message) => _log(LogLevel.info, message);
  void warning(String message) => _log(LogLevel.warning, message);
  void error(String message) => _log(LogLevel.error, message);
  void critical(String message) => _log(LogLevel.critical, message);

  void _log(LogLevel level, String message) {
    if (!_enabled || level.index < _minLevel.index) return;

    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp][$level] $message';
    
    _logs.add(logEntry);
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }

    print(logEntry);
  }

  Future<void> saveLogs() async {
    if (!_enabled) return;

    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/robot_logs.txt');
      await file.writeAsString(_logs.join('\n'));
      _log(LogLevel.info, 'Logs збережений в ${file.path}');
    } catch (e) {
      _log(LogLevel.error, 'Помилка збереження logs: $e');
    }
  }

  Future<void> loadLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/robot_logs.txt');
      if (await file.exists()) {
        final content = await file.readAsString();
        _logs = content.split('\n');
        _log(LogLevel.info, 'Logs завантажений з ${file.path}');
      }
    } catch (e) {
      _log(LogLevel.error, 'Failed to load logs: $e');
    }
  }

  void clearLogs() {
    _logs.clear();
    _log(LogLevel.info, 'Logs очищені');
  }

  String getLogsAsJson() {
    return jsonEncode(_logs);
  }

  void loadLogsFromJson(String json) {
    try {
      _logs = List<String>.from(jsonDecode(json));
      _log(LogLevel.info, 'Logs завантажений з JSON');
    } catch (e) {
      _log(LogLevel.error, 'Помилка завантаження з JSON: $e');
    }
  }
} 