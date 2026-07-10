import 'package:flutter/material.dart';

import '../utils/logger.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final _logger = Logger();

  @override
  Widget build(BuildContext context) {
    final logs = _logger.logs.reversed.toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Логи'),
        actions: [
          IconButton(
            tooltip: _logger.enabled ? 'Вимкнути логування' : 'Увімкнути логування',
            icon: Icon(_logger.enabled ? Icons.pause_circle_outline : Icons.play_circle_outline),
            onPressed: () {
              setState(() {
                _logger.enabled ? _logger.disable() : _logger.enable();
              });
            },
          ),
          IconButton(
            tooltip: 'Зберегти у файл',
            icon: const Icon(Icons.save_alt),
            onPressed: () async {
              await _logger.saveLogs();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Логи збережено (robot_logs.txt)')),
              );
            },
          ),
          IconButton(
            tooltip: 'Очистити',
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              setState(() => _logger.clearLogs());
            },
          ),
        ],
      ),
      body: logs.isEmpty
          ? const Center(child: Text('Поки що логів немає'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: logs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return SelectableText(
                  logs[index],
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                );
              },
            ),
    );
  }
}

