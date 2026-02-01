class Tag {
  final String id;
  final String name;
  final String color; // Hex color code
  final DateTime createdAt;

  Tag({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'] as String,
      name: map['name'] as String,
      color: map['color'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory Tag.fromJson(Map<String, dynamic> json) => Tag.fromMap(json);

  Tag copyWith({
    String? id,
    String? name,
    String? color,
    DateTime? createdAt,
  }) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Junction table for routine-tag relationships
class RoutineTag {
  final String routineId;
  final String tagId;
  final DateTime assignedAt;

  RoutineTag({
    required this.routineId,
    required this.tagId,
    required this.assignedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'routine_id': routineId,
      'tag_id': tagId,
      'assigned_at': assignedAt.millisecondsSinceEpoch,
    };
  }

  factory RoutineTag.fromMap(Map<String, dynamic> map) {
    return RoutineTag(
      routineId: map['routine_id'] as String,
      tagId: map['tag_id'] as String,
      assignedAt: DateTime.fromMillisecondsSinceEpoch(map['assigned_at'] as int),
    );
  }
}
