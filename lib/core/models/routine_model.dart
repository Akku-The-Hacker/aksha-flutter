class Routine {
  final String id;
  final String name;
  final String? categoryId;
  final String startTime; // "HH:mm" format
  final String endTime; // "HH:mm" format
  final bool isOvernight;
  final int durationMinutes;
  final List<int> repeatDays; // 1=Mon, 7=Sun
  final bool notificationEnabled;
  final int notificationMinutesBefore;
  final bool isPaused;
  final String? pauseUntilDate; // "yyyy-MM-dd" format
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  Routine({
    required this.id,
    required this.name,
    this.categoryId,
    required this.startTime,
    required this.endTime,
    required this.isOvernight,
    required this.durationMinutes,
    required this.repeatDays,
    this.notificationEnabled = false,
    this.notificationMinutesBefore = 0,
    this.isPaused = false,
    this.pauseUntilDate,
    this.startDate,
    this.endDate,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  // Helper: Calculate if overnight
  static bool calculateIsOvernight(String start, String end) {
    final startParts = start.split(':');
    final endParts = end.split(':');
    final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    return endMinutes < startMinutes;
  }

  // Helper: Calculate duration
  static int calculateDuration(String start, String end) {
    final startParts = start.split(':');
    final endParts = end.split(':');
    final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

    if (endMinutes < startMinutes) {
      // Overnight
      return (24 * 60) - startMinutes + endMinutes;
    } else {
      return endMinutes - startMinutes;
    }
  }

  // Convert to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'start_time': startTime,
      'end_time': endTime,
      'is_overnight': isOvernight ? 1 : 0,
      'duration_minutes': durationMinutes,
      'repeat_days': repeatDays.join(','),
      'notification_enabled': notificationEnabled ? 1 : 0,
      'notification_minutes_before': notificationMinutesBefore,
      'is_paused': isPaused ? 1 : 0,
      'pause_until_date': pauseUntilDate,
      'start_date': startDate?.millisecondsSinceEpoch,
      'end_date': endDate?.millisecondsSinceEpoch,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'archived_at': archivedAt?.millisecondsSinceEpoch,
    };
  }

  // Create from Map
  factory Routine.fromMap(Map<String, dynamic> map) {
    return Routine(
      id: map['id'] as String,
      name: map['name'] as String,
      categoryId: map['category_id'] as String?,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String,
      isOvernight: (map['is_overnight'] as int) == 1,
      durationMinutes: map['duration_minutes'] as int,
      repeatDays: (map['repeat_days'] as String)
          .split(',')
          .map((e) => int.parse(e))
          .toList(),
      notificationEnabled: (map['notification_enabled'] as int) == 1,
      notificationMinutesBefore: map['notification_minutes_before'] as int,
      isPaused: (map['is_paused'] as int) == 1,
      pauseUntilDate: map['pause_until_date'] as String?,
      startDate: map['start_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['start_date'] as int)
          : null,
      endDate: map['end_date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['end_date'] as int)
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
      archivedAt: map['archived_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['archived_at'] as int)
          : null,
    );
  }

  // JSON serialization
  Map<String, dynamic> toJson() => toMap();

  factory Routine.fromJson(Map<String, dynamic> json) => Routine.fromMap(json);

  // Copy with
  Routine copyWith({
    String? id,
    String? name,
    String? categoryId,
    String? startTime,
    String? endTime,
    bool? isOvernight,
    int? durationMinutes,
    List<int>? repeatDays,
    bool? notificationEnabled,
    int? notificationMinutesBefore,
    bool? isPaused,
    String? pauseUntilDate,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? archivedAt,
  }) {
    return Routine(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isOvernight: isOvernight ?? this.isOvernight,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      repeatDays: repeatDays ?? this.repeatDays,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      notificationMinutesBefore:
          notificationMinutesBefore ?? this.notificationMinutesBefore,
      isPaused: isPaused ?? this.isPaused,
      pauseUntilDate: pauseUntilDate ?? this.pauseUntilDate,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  @override
  String toString() {
    return 'Routine{id: $id, name: $name, time: $startTime-$endTime, days: $repeatDays}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Routine && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
