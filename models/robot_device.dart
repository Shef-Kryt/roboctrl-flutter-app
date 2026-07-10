enum RobotLinkType {
  classicSpp,

  ble,
}

class RobotDevice {
  const RobotDevice({
    required this.id,
    required this.nativeName,
    required this.linkType,
  });

  final String id;
  final String nativeName;
  final RobotLinkType linkType;

  bool get isRecommendedForPicoGo => isPicoGoSppName(nativeName);

  bool get isBleVariantWarning => isBleOnlyName(nativeName);

  String get linkTypeLabel =>
      linkType == RobotLinkType.classicSpp ? 'Classic SPP' : 'BLE';

  static String normalizeId(String id) {
    final clean = id.replaceAll(':', '').replaceAll('-', '').toUpperCase();
    if (clean.length == 12) {
      final parts = <String>[];
      for (var i = 0; i < 12; i += 2) {
        parts.add(clean.substring(i, i + 2));
      }
      return parts.join(':');
    }
    return id.toUpperCase();
  }

  static bool isPicoGoSppName(String name) {
    final u = name.toUpperCase();
    if (u.contains('BLE')) return false;
    return (u.contains('JDY') && u.contains('SPP')) ||
        u.contains('JDY-33-SPP') ||
        u.contains('PICOGO');
  }

  static bool isBleOnlyName(String name) {
    final u = name.toUpperCase();
    return u.contains('JDY') && u.contains('BLE');
  }

  static int sortPriority(RobotDevice device) {
    if (device.isRecommendedForPicoGo) return 0;
    if (device.linkType == RobotLinkType.classicSpp) return 1;
    if (device.isBleVariantWarning) return 3;
    return 2;
  }
}
