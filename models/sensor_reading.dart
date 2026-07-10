class SensorReading {
  final DateTime timestamp;
  final double batteryVoltage;
  final int batteryPercentage;
  final double temperature;
  final double distance;
  final List<int> lineSensors; // 5 values
  final bool leftObstacle;
  final bool rightObstacle;

  SensorReading({
    required this.timestamp,
    required this.batteryVoltage,
    required this.batteryPercentage,
    required this.temperature,
    required this.distance,
    required this.lineSensors,
    required this.leftObstacle,
    required this.rightObstacle,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'battery_voltage': batteryVoltage,
        'battery_percentage': batteryPercentage,
        'temperature': temperature,
        'distance': distance,
        'line_sensors': lineSensors,
        'left_obstacle': leftObstacle,
        'right_obstacle': rightObstacle,
      };

  factory SensorReading.fromJson(Map<String, dynamic> json) => SensorReading(
        timestamp: DateTime.parse(json['timestamp'] as String),
        batteryVoltage: (json['battery_voltage'] as num).toDouble(),
        batteryPercentage: json['battery_percentage'] as int,
        temperature: (json['temperature'] as num).toDouble(),
        distance: (json['distance'] as num).toDouble(),
        lineSensors: List<int>.from(json['line_sensors'] as List),
        leftObstacle: json['left_obstacle'] as bool,
        rightObstacle: json['right_obstacle'] as bool,
      );

  String toCsvRow() {
    return [
      timestamp.toIso8601String(),
      batteryVoltage.toStringAsFixed(2),
      batteryPercentage.toString(),
      temperature.toStringAsFixed(2),
      distance.toStringAsFixed(2),
      lineSensors.join(';'),
      leftObstacle ? '1' : '0',
      rightObstacle ? '1' : '0',
    ].join(',');
  }

  static String csvHeader() {
    return 'Timestamp,Battery Voltage (V),Battery (%),Temperature (°C),Distance (cm),Line Sensor 1,Line Sensor 2,Line Sensor 3,Line Sensor 4,Line Sensor 5,Left Obstacle,Right Obstacle';
  }
}
