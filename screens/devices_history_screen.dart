import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/bluetooth_provider.dart';
import '../utils/bluetooth_error_dialog.dart';

class DevicesHistoryScreen extends StatelessWidget {
  const DevicesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Історія пристроїв')),
      body: Consumer<BluetoothProvider>(
        builder: (context, provider, child) {
          final ids = provider.deviceHistoryIds;
          if (ids.isEmpty) {
            return const Center(
              child: Text('Поки що немає підключених пристроїв'),
            );
          }

          return ListView.separated(
            itemCount: ids.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final id = ids[index];
              final displayName = provider.getDisplayNameForDevice(id);
              final isLast = provider.lastDeviceName == displayName;
              return ListTile(
                leading: const Icon(Icons.bluetooth),
                title: Text(displayName),
                subtitle: Text('$id · ${provider.linkTypeLabelForDevice(id)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLast) const Icon(Icons.history, size: 18),
                    IconButton(
                      tooltip: 'Перейменувати',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _showRenameDialog(context, provider, id, displayName),
                    ),
                  ],
                ),
                onTap: () async {
                  try {
                    await provider.connectToDeviceId(id);
                  } catch (e) {
                    if (context.mounted) {
                      showBluetoothConnectionErrorDialog(context, e);
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    BluetoothProvider provider,
    String id,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Перейменувати пристрій'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Введіть нову назву',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Скасувати'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, '__clear__'),
            child: const Text('Скинути'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Зберегти'),
          ),
        ],
      ),
    );

    if (result == null) return;
    if (result == '__clear__') {
      await provider.clearDeviceAlias(id);
      return;
    }
    await provider.renameDevice(id, result);
  }
}

