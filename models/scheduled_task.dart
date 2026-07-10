import 'route.dart' show Route;
import 'sensor_reading.dart';

enum TaskStatus {
  pending,
  running,
  completed,
  failed,
  cancelled,
}

class ScheduledTask {
  final String id;
  final String name;
  final Route route;
  final DateTime scheduledTime;
  final bool enabled;
  final TaskStatus status;
  final DateTime? executedAt;
  final List<SensorReading>? sensorData;
  final String? errorMessage;

  ScheduledTask({
    required this.id,
    required this.name,
    required this.route,
    required this.scheduledTime,
    this.enabled = true,
    this.status = TaskStatus.pending,
    this.executedAt,
    this.sensorData,
    this.errorMessage,
  });

  bool get isOverdue => DateTime.now().isAfter(scheduledTime) && status == TaskStatus.pending;
  bool get canExecute => enabled && status == TaskStatus.pending && !isOverdue;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'route': route.toJson(),
        'scheduled_time': scheduledTime.toIso8601String(),
        'enabled': enabled,
        'status': status.name,
        'executed_at': executedAt?.toIso8601String(),
        'sensor_data': sensorData?.map((s) => s.toJson()).toList(),
        'error_message': errorMessage,
      };

  factory ScheduledTask.fromJson(Map<String, dynamic> json) => ScheduledTask(
        id: json['id'] as String,
        name: json['name'] as String,
        route: Route.fromJson(json['route'] as Map<String, dynamic>),
        scheduledTime: DateTime.parse(json['scheduled_time'] as String),
        enabled: json['enabled'] as bool? ?? true,
        status: TaskStatus.values.firstWhere(
          (e) => e.name == json['status'] as String,
          orElse: () => TaskStatus.pending,
        ),
        executedAt: json['executed_at'] != null
            ? DateTime.parse(json['executed_at'] as String)
            : null,
        sensorData: json['sensor_data'] != null
            ? (json['sensor_data'] as List)
                .map((s) => SensorReading.fromJson(s as Map<String, dynamic>))
                .toList()
            : null,
        errorMessage: json['error_message'] as String?,
      );

  ScheduledTask copyWith({
    String? name,
    Route? route,
    DateTime? scheduledTime,
    bool? enabled,
    TaskStatus? status,
    DateTime? executedAt,
    List<SensorReading>? sensorData,
    String? errorMessage,
  }) {
    return ScheduledTask(
      id: id,
      name: name ?? this.name,
      route: route ?? this.route,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      enabled: enabled ?? this.enabled,
      status: status ?? this.status,
      executedAt: executedAt ?? this.executedAt,
      sensorData: sensorData ?? this.sensorData,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
