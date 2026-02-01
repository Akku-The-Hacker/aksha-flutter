import 'package:flutter/material.dart';

class Achievement {
  final String id;
  final BadgeType badgeType;
  final DateTime earnedAt;
  final int earnedCount;

  Achievement({
    required this.id,
    required this.badgeType,
    required this.earnedAt,
    this.earnedCount = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'badge_type': badgeType.name,
      'earned_at': earnedAt.millisecondsSinceEpoch,
      'earned_count': earnedCount,
    };
  }

  factory Achievement.fromMap(Map<String, dynamic> map) {
    return Achievement(
      id: map['id'] as String,
      badgeType: BadgeType.values.firstWhere(
        (e) => e.name == map['badge_type'],
        orElse: () => BadgeType.firstCompletion,
      ),
      earnedAt: DateTime.fromMillisecondsSinceEpoch(map['earned_at'] as int),
      earnedCount: map['earned_count'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() => toMap();
  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement.fromMap(json);
}

enum BadgeType {
  firstRoutine,     // Created first routine
  firstCompletion,  // Completed first routine
  streak3,          // 3-day streak
  streak7,          // 7-day streak
  streak30,         // 30-day streak
  perfectDay,       // Completed all routines in a day
  perfectWeek,      // Perfect week
  earlyBird,        // Completed routine before 8 AM
  nightOwl,         // Completed routine after 10 PM
  century,          // 100 total completions
  dedicated,        // 500 total completions
}

extension BadgeTypeExtension on BadgeType {
  String get title {
    switch (this) {
      case BadgeType.firstRoutine:
        return '🎯 First Step';
      case BadgeType.firstCompletion:
        return '✅ First Win';
      case BadgeType.streak3:
        return '🔥 3-Day Streak';
      case BadgeType.streak7:
        return '⭐ Week Warrior';
      case BadgeType.streak30:
        return '👑 Monthly Master';
      case BadgeType.perfectDay:
        return '💯 Perfect Day';
      case BadgeType.perfectWeek:
        return '🏆 Perfect Week';
      case BadgeType.earlyBird:
        return '🌅 Early Bird';
      case BadgeType.nightOwl:
        return '🌙 Night Owl';
      case BadgeType.century:
        return '💎 Century';
      case BadgeType.dedicated:
        return '🌟 Dedicated';
    }
  }

  String get description {
    switch (this) {
      case BadgeType.firstRoutine:
        return 'Created your first routine';
      case BadgeType.firstCompletion:
        return 'Completed your first routine';
      case BadgeType.streak3:
        return 'Maintained a 3-day streak';
      case BadgeType.streak7:
        return 'Maintained a 7-day streak';
      case BadgeType.streak30:
        return 'Maintained a 30-day streak';
      case BadgeType.perfectDay:
        return 'Completed all routines in a day';
      case BadgeType.perfectWeek:
        return 'Completed all routines for a week';
      case BadgeType.earlyBird:
        return 'Completed a routine before 8 AM';
      case BadgeType.nightOwl:
        return 'Completed a routine after 10 PM';
      case BadgeType.century:
        return 'Completed 100 routines';
      case BadgeType.dedicated:
        return 'Completed 500 routines';
    }
  }

  Color get color {
    switch (this) {
      case BadgeType.firstRoutine:
        return Colors.green;
      case BadgeType.firstCompletion:
        return Colors.blue;
      case BadgeType.streak3:
        return Colors.orange;
      case BadgeType.streak7:
        return Colors.red;
      case BadgeType.streak30:
        return Colors.purple;
      case BadgeType.perfectDay:
        return Colors.teal;
      case BadgeType.perfectWeek:
        return Colors.amber;
      case BadgeType.earlyBird:
        return Colors.yellow;
      case BadgeType.nightOwl:
        return Colors.indigo;
      case BadgeType.century:
        return Colors.cyan;
      case BadgeType.dedicated:
        return Colors.deepPurple;
    }
  }

  bool get isRepeatable {
    return this == BadgeType.perfectDay || this == BadgeType.perfectWeek;
  }
}
