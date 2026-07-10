import 'route_step.dart';

class Route {
  final String id;
  final String name;
  final String? description;
  final List<RouteStep> steps;
  final DateTime createdAt;
  final DateTime? lastExecutedAt;

  Route({
    required this.id,
    required this.name,
    this.description,
    required this.steps,
    required this.createdAt,
    this.lastExecutedAt,
  });

  Duration get estimatedDuration {
    return steps.fold<Duration>(
      Duration.zero,
      (sum, step) => sum + step.duration,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'steps': steps.map((s) => s.toJson()).toList(),
        'created_at': createdAt.toIso8601String(),
        'last_executed_at': lastExecutedAt?.toIso8601String(),
      };

  factory Route.fromJson(Map<String, dynamic> json) => Route(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String?,
        steps: (json['steps'] as List)
            .map((s) => RouteStep.fromJson(s as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['created_at'] as String),
        lastExecutedAt: json['last_executed_at'] != null
            ? DateTime.parse(json['last_executed_at'] as String)
            : null,
      );

  Route copyWith({
    String? name,
    String? description,
    List<RouteStep>? steps,
    DateTime? lastExecutedAt,
  }) {
    return Route(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      steps: steps ?? this.steps,
      createdAt: createdAt,
      lastExecutedAt: lastExecutedAt ?? this.lastExecutedAt,
    );
  }
}
