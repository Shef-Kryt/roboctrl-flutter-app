class LineSensor {
  final List<int> calibratedMin = List.filled(5, 0);
  final List<int> calibratedMax = List.filled(5, 1023);
  int lastPosition = 0;
  bool isCalibrated = false;

  static const int threshold = 200;
  static const int noiseThreshold = 50;
  static const int maxValue = 1000;

  List<int> processRawData(List<int> rawValues) {
    final List<int> calibratedValues = List.filled(5, 0);
    
    for (int i = 0; i < 5; i++) {
      int denominator = calibratedMax[i] - calibratedMin[i];
      if (denominator != 0) {
        int value = ((rawValues[i] - calibratedMin[i]) * maxValue ~/ denominator);
        calibratedValues[i] = value.clamp(0, maxValue);
      }
    }
    
    return calibratedValues;
  }

  (int position, List<int>) calculatePosition(List<int> calibratedValues) {
    int avg = 0;
    int sum = 0;
    bool onLine = false;

    for (int i = 0; i < 5; i++) {
      int value = calibratedValues[i];
      
      if (value > threshold) {
        onLine = true;
      }
      
      if (value > noiseThreshold) {
        avg += value * (i * maxValue);
        sum += value;
      }
    }

    if (!onLine) {
      if (lastPosition < (5 - 1) * maxValue ~/ 2) {
        return (0, calibratedValues);
      } else {
        return ((5 - 1) * maxValue, calibratedValues);
      }
    }

    lastPosition = sum != 0 ? avg ~/ sum : lastPosition;
    return (lastPosition, calibratedValues);
  }

  void calibrate(List<int> rawValues) {
    for (int i = 0; i < 5; i++) {
      if (rawValues[i] < calibratedMin[i]) {
        calibratedMin[i] = rawValues[i];
      }
      if (rawValues[i] > calibratedMax[i]) {
        calibratedMax[i] = rawValues[i];
      }
    }
    isCalibrated = true;
  }

  void resetCalibration() {
    for (int i = 0; i < 5; i++) {
      calibratedMin[i] = 0;
      calibratedMax[i] = 1023;
    }
    isCalibrated = false;
  }

  (int position, List<int>) getLinePosition(List<int> rawValues) {
    final calibratedValues = processRawData(rawValues);
    return calculatePosition(calibratedValues);
  }

  bool isCalibrationValid() {
    if (!isCalibrated) return false;
    
    for (int i = 0; i < 5; i++) {
      if (calibratedMax[i] - calibratedMin[i] < 100) {
        return false;
      }
    }
    return true;
  }

  double getNormalizedPosition(List<int> rawValues) {
    final (position, _) = getLinePosition(rawValues);
    return (position - 2000) / 2000.0;
  }

  (int leftSpeed, int rightSpeed) getPidSpeeds(List<int> rawValues, {
    double baseSpeed = 50,
    double kp = 0.5,
    double ki = 0.0,
    double kd = 0.1
  }) {
    final position = getNormalizedPosition(rawValues);
    
    final error = -position;
    final output = kp * error;
    
    int leftSpeed = (baseSpeed + output).round();
    int rightSpeed = (baseSpeed - output).round();
    
    leftSpeed = leftSpeed.clamp(-100, 100);
    rightSpeed = rightSpeed.clamp(-100, 100);
    
    return (leftSpeed, rightSpeed);
  }
} 