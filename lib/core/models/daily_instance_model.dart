enum InstanceStatus {
  pending,
  done,
  partial,
  skipped,
  missed;

  String toJson() => name;

  static InstanceStatus fromJson(String json) {
    return InstanceStatus.values.firstWhere((e) => e.name == json);
  }
}

class DailyInstance {
  final String id;
  final String date; // "yyyy-MM-dd" format
  final String routineId;
  
  // Snapshot fields (immutable after generation)
  final String routineName;
  final String? categoryId;
  final String? categoryName;
  final String? categoryColor;
  final String plannedStart; // "HH:mm"
  final String plannedEnd; // "HH:mm"
  final int plannedMinutes;
  final bool isOvernight;
  
  // Execution fields (mutable)
  final InstanceStatus status;
  final int? actualMinutes;
  final DateTime? completedAt;
  final String? notes;
  final bool editedAfterDayEnd;
  
  final DateTime createdAt;
  final DateTime updatedAt;

  DailyInstance({
    required this.id,
    required this.date,
    required this.routineId,
    required this.routineName,
    this.categoryId,
    this.categoryName,
    this.categoryColor,
    required this.plannedStart,
    required this.plannedEnd,
    required this.plannedMinutes,
    this.isOvernight = false,
    this.status = InstanceStatus.pending,
    this.actualMinutes,
    this.completedAt,
    this.notes,
    this.editedAfterDayEnd = false,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'routine_id': routineId,
      'routine_name': routineName,
      'category_id': categoryId,
      'category_name': categoryName,
      'category_color': categoryColor,
      'planned_start': plannedStart,
      'planned_end': plannedEnd,
      'planned_minutes': plannedMinutes,
      'is_overnight': isOvernight ? 1 : 0,
      'status': status.name,
      'actual_minutes': actualMinutes,
      'completed_at': completedAt?.millisecondsSinceEpoch,
      'notes': notes,
      'edited_after_day_end': editedAfterDayEnd ? 1 : 0,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  // Create from Map
  factory DailyInstance.fromMap(Map<String, dynamic> map) {
    return DailyInstance(
      id: map['id'] as String,
      date: map['date'] as String,
      routineId: map['routine_id'] as String,
      routineName: map['routine_name'] as String,
      categoryId: map['category_id'] as String?,
      categoryName: map['category_name'] as String?,
      categoryColor: map['category_color'] as String?,
      plannedStart: map['planned_start'] as String,
      plannedEnd: map['planned_end'] as String,
      plannedMinutes: map['planned_minutes'] as int,
      isOvernight: (map['is_overnight'] as int) == 1,
      status: InstanceStatus.fromJson(map['status'] as String),
      actualMinutes: map['actual_minutes'] as int?,
      completedAt: map['completed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int)
          : null,
      notes: map['notes'] as String?,
      editedAfterDayEnd: (map['edited_after_day_end'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  // JSON serialization
  Map<String, dynamic> toJson() => toMap();

  factory DailyInstance.fromJson(Map<String, dynamic> json) =>
      DailyInstance.fromMap(json);

  // Copy with
  DailyInstance copyWith({
    String? id,
    String? date,
    String? routineId,
    String? routineName,
    String? categoryId,
    String? categoryName,
    String? categoryColor,
    String? plannedStart,
    String? plannedEnd,
    int? plannedMinutes,
    bool? isOvernight,
    InstanceStatus? status,
    int? actualMinutes,
    DateTime? completedAt,
    String? notes,
    bool? editedAfterDayEnd,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DailyInstance(
      id: id ?? this.id,
      date: date ?? this.date,
      routineId: routineId ?? this.routineId,
      routineName: routineName ?? this.routineName,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryColor: categoryColor ?? this.categoryColor,
      plannedStart: plannedStart ?? this.plannedStart,
      plannedEnd: plannedEnd ?? this.plannedEnd,
      plannedMinutes: plannedMinutes ?? this.plannedMinutes,
      isOvernight: isOvernight ?? this.isOvernight,
      status: status ?? this.status,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
      editedAfterDayEnd: editedAfterDayEnd ?? this.editedAfterDayEnd,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'DailyInstance{id: $id, date: $date, routine: $routineName, status: $status}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DailyInstance && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
