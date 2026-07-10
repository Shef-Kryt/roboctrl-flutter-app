import 'dart:ui';

class LedStrip {
  static const int numLeds = 4;
  static const int maxBrightness = 255;

  static String setPixel(int index, int red, int green, int blue) {
    if (index < 0 || index >= numLeds) return '';
    
    final r = red.clamp(0, maxBrightness);
    final g = green.clamp(0, maxBrightness);
    final b = blue.clamp(0, maxBrightness);
    
    return 'led_set $index $r $g $b';
  }

  static String setAll(int red, int green, int blue) {
    final r = red.clamp(0, maxBrightness);
    final g = green.clamp(0, maxBrightness);
    final b = blue.clamp(0, maxBrightness);
    
    return 'led_set_all $r $g $b';
  }

  static String startAnimation(String type) {
    final validTypes = [
      'rainbow',
      'breathing',
      'running',
      'police',
      'fire',
      'ukraine'
    ];
    
    if (!validTypes.contains(type)) {
      type = 'rainbow';
    }
    
    return 'led_animation_start $type';
  }

  static String stopAnimation() => 'led_animation_stop';

  static Color wheel(int position) {
    position = position & 255;
    
    if (position < 85) {
      return Color.fromARGB(255, 255 - position * 3, position * 3, 0);
    } else if (position < 170) {
      position -= 85;
      return Color.fromARGB(255, 0, 255 - position * 3, position * 3);
    } else {
      position -= 170;
      return Color.fromARGB(255, position * 3, 0, 255 - position * 3);
    }
  }

  static Color get red => const Color.fromARGB(255, 255, 0, 0);
  static Color get green => const Color.fromARGB(255, 0, 255, 0);
  static Color get blue => const Color.fromARGB(255, 0, 0, 255);
  static Color get yellow => const Color.fromARGB(255, 255, 255, 0);
  static Color get purple => const Color.fromARGB(255, 255, 0, 255);
  static Color get cyan => const Color.fromARGB(255, 0, 255, 255);
  static Color get white => const Color.fromARGB(255, 255, 255, 255);
  static Color get off => const Color.fromARGB(255, 0, 0, 0);
} 