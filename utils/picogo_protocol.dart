import 'dart:convert';

class PicogoProtocol {
  PicogoProtocol._();

  static const motionKeys = ['Forward', 'Backward', 'Left', 'Right'];
  static const speedKeys = ['Low', 'Medium', 'High'];

  static Map<String, String> motion(String key, {required bool pressed}) {
    assert(motionKeys.contains(key));
    return {key: pressed ? 'Down' : 'Up'};
  }

  static Map<String, String> speedPreset(String key) {
    assert(speedKeys.contains(key));
    return {key: 'Down'};
  }

  static Map<String, String> boardLed({required bool on}) => {'LED': on ? 'on' : 'off'};

  static Map<String, String> buzzer({required bool on}) => {'BZ': on ? 'on' : 'off'};

  static Map<String, String> rgbAll(int r, int g, int b) => {'RGB': '($r,$g,$b)'};

  static String speedKeyForPercent(int speedPercent) {
    if (speedPercent <= 35) return 'Low';
    if (speedPercent <= 55) return 'Medium';
    return 'High';
  }

  static List<String> extractJsonObjects(String buffer) {
    final objects = <String>[];
    var rest = buffer;
    while (rest.isNotEmpty) {
      final start = rest.indexOf('{');
      if (start == -1) break;
      if (start > 0) rest = rest.substring(start);
      final end = rest.indexOf('}');
      if (end == -1) break;
      objects.add(rest.substring(0, end + 1));
      rest = rest.substring(end + 1);
    }
    return objects;
  }

  static String remainingBuffer(String buffer) {
    var rest = buffer;
    while (rest.isNotEmpty) {
      final start = rest.indexOf('{');
      if (start == -1) return rest;
      if (start > 0) rest = rest.substring(start);
      final end = rest.indexOf('}');
      if (end == -1) return rest;
      rest = rest.substring(end + 1);
    }
    return '';
  }

  static Map<String, dynamic>? tryParseObject(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}
    return null;
  }

  static String encode(Map<String, String> command) => jsonEncode(command);
}
