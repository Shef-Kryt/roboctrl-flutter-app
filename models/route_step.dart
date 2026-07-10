enum MovementDirection {
  forward,
  backward,
  left,
  right,
  stop,
}

class RouteStep {
  final MovementDirection direction;
  final int speed; // 0-100
  final Duration duration;
  final String? description;

  const RouteStep({
    required this.direction,
    required this.speed,
    required this.duration,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'direction': direction.name,
        'speed': speed,
        'duration_ms': duration.inMilliseconds,
        'description': description,
      };

  factory RouteStep.fromJson(Map<String, dynamic> json) => RouteStep(
        direction: MovementDirection.values.firstWhere(
          (e) => e.name == json['direction'],
          orElse: () => MovementDirection.stop,
        ),
        speed: json['speed'] as int,
        duration: Duration(milliseconds: json['duration_ms'] as int),
        description: json['description'] as String?,
      );

  String get displayName {
    switch (direction) {
      case MovementDirection.forward:
        return 'Вперед';
      case MovementDirection.backward:
        return 'Назад';
      case MovementDirection.left:
        return 'Вліво';
      case MovementDirection.right:
        return 'Вправо';
      case MovementDirection.stop:
        return 'Стоп';
    }
  }
}
