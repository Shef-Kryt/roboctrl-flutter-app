import 'package:flutter/material.dart';

void showBluetoothConnectionErrorDialog(BuildContext context, Object error) {
  final text = _humanizeBluetoothError(error);
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Не вдалося підключитися'),
      content: SingleChildScrollView(
        child: Text(text),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

String _humanizeBluetoothError(Object error) {
  final raw = error.toString();
  if (raw.contains('JDY-33-BLE') || raw.contains('JDY-33-SPP')) {
    return raw.replaceFirst('Exception: ', '');
  }
  if (raw.contains('Classic Bluetooth (SPP)') || raw.contains('Bluetooth Classic')) {
    return raw.replaceFirst('Exception: ', '');
  }
  if (raw.contains('FFE0/FFE1') || raw.contains('BLE-сервіс')) {
    return raw.replaceFirst('Exception: ', '');
  }
  if (raw.contains('SPP сервіс не знайдено') || raw.contains('SPP')) {
    return 'На пристрої не знайдено сервіс Bluetooth SPP.';
  }
  if (raw.contains('Пристрій не знайдено')) {
    return 'Пристрій не знайдено під час пошуку. Увімкніть робота, спаруйте SPP '
        'у системних налаштуваннях Bluetooth і спробуйте сканувати знову.';
  }
  if (raw.contains('timeout') || raw.contains('timed out') || raw.contains('TimeoutException')) {
    return 'Час очікування підключення вичерпано. Перевірте, чи робот увімкнений і чи не підключений він до іншого телефону.';
  }
  if (raw.contains('firstWhere') || raw.contains('Bad state')) {
    return 'Пристрій відсутній у списку знайдених.';
  }
  return raw.replaceFirst('Exception: ', '');
}
