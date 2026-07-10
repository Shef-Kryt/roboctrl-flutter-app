import 'dart:math' show min;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bluetooth_provider.dart';
import '../providers/settings_provider.dart';

class DirectionControl extends StatelessWidget {
  const DirectionControl({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final speed = int.tryParse(settings.defaultSpeed) ?? 50;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
        final maxH = constraints.maxHeight.isFinite ? constraints.maxHeight : 340.0;
        final scale = min(1.0, min(maxW / 300, maxH / 320));

        final btnPadding = 16.0 * scale;
        final iconSize = 28.0 * scale;
        final gap = 10.0 * scale;
        final labelSize = 11.0 * scale;

        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: EdgeInsets.all(4 * scale),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _holdButton(
                  context,
                  motionKey: 'Forward',
                  speed: speed,
                  icon: Icons.arrow_upward,
                  label: 'Вперед',
                  padding: btnPadding,
                  iconSize: iconSize,
                  labelSize: labelSize,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _holdButton(
                      context,
                      motionKey: 'Left',
                      speed: speed,
                      icon: Icons.arrow_back,
                      label: 'Вліво',
                      padding: btnPadding,
                      iconSize: iconSize,
                      labelSize: labelSize,
                    ),
                    SizedBox(width: gap),
                    _holdButton(
                      context,
                      motionKey: null,
                      speed: speed,
                      icon: Icons.stop_circle,
                      label: 'Стоп',
                      color: Colors.red,
                      padding: btnPadding,
                      iconSize: iconSize,
                      labelSize: labelSize,
                      onTap: () => context.read<BluetoothProvider>().stop(),
                    ),
                    SizedBox(width: gap),
                    _holdButton(
                      context,
                      motionKey: 'Right',
                      speed: speed,
                      icon: Icons.arrow_forward,
                      label: 'Вправо',
                      padding: btnPadding,
                      iconSize: iconSize,
                      labelSize: labelSize,
                    ),
                  ],
                ),
                _holdButton(
                  context,
                  motionKey: 'Backward',
                  speed: speed,
                  icon: Icons.arrow_downward,
                  label: 'Назад',
                  padding: btnPadding,
                  iconSize: iconSize,
                  labelSize: labelSize,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _holdButton(
    BuildContext context, {
    required String? motionKey,
    required int speed,
    required IconData icon,
    required String label,
    required double padding,
    required double iconSize,
    required double labelSize,
    Color? color,
    VoidCallback? onTap,
  }) {
    final side = padding * 2 + iconSize;

    return Padding(
      padding: const EdgeInsets.all(4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) {
              if (onTap != null) {
                onTap();
              } else if (motionKey != null) {
                context.read<BluetoothProvider>().motionDown(motionKey, speedPercent: speed);
              }
            },
            onPointerUp: (_) {
              if (motionKey != null) {
                context.read<BluetoothProvider>().stop();
              }
            },
            onPointerCancel: (_) {
              if (motionKey != null) {
                context.read<BluetoothProvider>().stop();
              }
            },
            child: Material(
              color: color ?? Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(14),
              elevation: 2,
              child: SizedBox(
                width: side,
                height: side,
                child: Icon(
                  icon,
                  size: iconSize,
                  color: color != null ? Colors.white : Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ),
          SizedBox(height: labelSize * 0.35),
          Text(label, style: TextStyle(fontSize: labelSize)),
        ],
      ),
    );
  }
}
