import 'package:uuid/uuid.dart';
import '../models/achievement_model.dart';
import '../repositories/achievement_repository.dart';
import '../repositories/daily_instance_repository.dart';
import '../repositories/routine_repository.dart';
import 'package:intl/intl.dart';

class AchievementService {
  final AchievementRepository _achievementRepo = AchievementRepository();
  final DailyInstanceRepository _instanceRepo = DailyInstanceRepository();
  final RoutineRepository _routineRepo = RoutineRepository();

  /// Check and award achievements after a routine completion
  Future<List<Achievement>> checkAndAwardAchievements() async {
    final newlyEarned = <Achievement>[];

    // Check all possible achievements
    final checks = [
      _checkFirstCompletion(),
      _checkEarlyBird(),
      _checkNightOwl(),
      _checkStreak3(),
      _checkStreak7(),
      _checkStreak30(),
      _checkPerfectDay(),
      _checkPerfectWeek(),
      _checkCentury(),
      _checkDedicated(),
    ];

    for (final check in checks) {
      final achievement = await check;
      if (achievement != null) {
        newlyEarned.add(achievement);
      }
    }

    return newlyEarned;
  }

  /// Award achievement for first routine creation
  Future<Achievement?> awardFirstRoutine() async {
    if (await _achievementRepo.exists(BadgeType.firstRoutine)) {
      return null;
    }

    final achievement = Achievement(
      id: const Uuid().v4(),
      badgeType: BadgeType.firstRoutine,
      earnedAt: DateTime.now(),
    );

    await _achievementRepo.insert(achievement);
    return achievement;
  }

  // Private achievement check methods

  Future<Achievement?> _checkFirstCompletion() async {
    if (await _achievementRepo.exists(BadgeType.firstCompletion)) {
      return null;
    }

    final totalCompletions = await _getTotalCompletions();
    if (totalCompletions >= 1) {
      final achievement = Achievement(
        id: const Uuid().v4(),
        badgeType: BadgeType.firstCompletion,
        earnedAt: DateTime.now(),
      );
      await _achievementRepo.insert(achievement);
      return achievement;
    }

    return null;
  }

  Future<Achievement?> _checkEarlyBird() async {
    if (await _achievementRepo.exists(BadgeType.earlyBird)) {
      return null;
    }

    // Check if any instance was completed before 8 AM
    final instances = await _instanceRepo.getInstancesInRange(
      DateTime.now().subtract(const Duration(days: 30)),
      DateTime.now(),
    );

    for (final instance in instances) {
      if (instance.status.name == 'done' && instance.completedAt != null) {
        final hour = instance.completedAt!.hour;
        if (hour < 8) {
          final achievement = Achievement(
            id: const Uuid().v4(),
            badgeType: BadgeType.earlyBird,
            earnedAt: DateTime.now(),
          );
          await _achievementRepo.insert(achievement);
          return achievement;
        }
      }
    }

    return null;
  }

  Future<Achievement?> _checkNightOwl() async {
    if (await _achievementRepo.exists(BadgeType.nightOwl)) {
      return null;
    }

    // Check if any instance was completed after 10 PM
    final instances = await _instanceRepo.getInstancesInRange(
      DateTime.now().subtract(const Duration(days: 30)),
      DateTime.now(),
    );

    for (final instance in instances) {
      if (instance.status.name == 'done' && instance.completedAt != null) {
        final hour = instance.completedAt!.hour;
        if (hour >= 22) {
          final achievement = Achievement(
            id: const Uuid().v4(),
            badgeType: BadgeType.nightOwl,
            earnedAt: DateTime.now(),
          );
          await _achievementRepo.insert(achievement);
          return achievement;
        }
      }
    }

    return null;
  }

  Future<Achievement?> _checkStreak3() async {
    if (await _achievementRepo.exists(BadgeType.streak3)) {
      return null;
    }

    final streak = await _getCurrentStreak();
    if (streak >= 3) {
      final achievement = Achievement(
        id: const Uuid().v4(),
        badgeType: BadgeType.streak3,
        earnedAt: DateTime.now(),
      );
      await _achievementRepo.insert(achievement);
      return achievement;
    }

    return null;
  }

  Future<Achievement?> _checkStreak7() async {
    if (await _achievementRepo.exists(BadgeType.streak7)) {
      return null;
    }

    final streak = await _getCurrentStreak();
    if (streak >= 7) {
      final achievement = Achievement(
        id: const Uuid().v4(),
        badgeType: BadgeType.streak7,
        earnedAt: DateTime.now(),
      );
      await _achievementRepo.insert(achievement);
      return achievement;
    }

    return null;
  }

  Future<Achievement?> _checkStreak30() async {
    if (await _achievementRepo.exists(BadgeType.streak30)) {
      return null;
    }

    final streak = await _getCurrentStreak();
    if (streak >= 30) {
      final achievement = Achievement(
        id: const Uuid().v4(),
        badgeType: BadgeType.streak30,
        earnedAt: DateTime.now(),
      );
      await _achievementRepo.insert(achievement);
      return achievement;
    }

    return null;
  }

  Future<Achievement?> _checkPerfectDay() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final instances = await _instanceRepo.getInstancesByDate(today);

    if (instances.isEmpty) return null;

    final allDone = instances.every((i) => i.status.name == 'done');
    if (allDone) {
      // Check if already earned today (repeatable)
      final existing = await _achievementRepo.getByBadgeType(BadgeType.perfectDay);
      
      if (existing == null) {
        final achievement = Achievement(
          id: const Uuid().v4(),
          badgeType: BadgeType.perfectDay,
          earnedAt: DateTime.now(),
        );
        await _achievementRepo.insert(achievement);
        return achievement;
      } else {
        // Increment count if not already counted today
        final lastEarnedDate = DateFormat('yyyy-MM-dd').format(existing.earnedAt);
        if (lastEarnedDate != today) {
          await _achievementRepo.incrementEarnedCount(existing.id);
          return existing.copyWith(earnedCount: existing.earnedCount + 1);
        }
      }
    }

    return null;
  }

  Future<Achievement?> _checkPerfectWeek() async {
    // Check if last 7 days were all perfect
    final today = DateTime.now();
    bool isPerfect = true;

    for (int i = 0; i < 7; i++) {
      final date = DateFormat('yyyy-MM-dd').format(today.subtract(Duration(days: i)));
      final instances = await _instanceRepo.getInstancesByDate(date);
      
      if (instances.isEmpty || !instances.every((i) => i.status.name == 'done')) {
        isPerfect = false;
        break;
      }
    }

    if (isPerfect) {
      final existing = await _achievementRepo.getByBadgeType(BadgeType.perfectWeek);
      
      if (existing == null) {
        final achievement = Achievement(
          id: const Uuid().v4(),
          badgeType: BadgeType.perfectWeek,
          earnedAt: DateTime.now(),
        );
        await _achievementRepo.insert(achievement);
        return achievement;
      } else {
        // Increment if not already counted this week
        final daysSinceEarned = DateTime.now().difference(existing.earnedAt).inDays;
        if (daysSinceEarned >= 7) {
          await _achievementRepo.incrementEarnedCount(existing.id);
          return existing.copyWith(earnedCount: existing.earnedCount + 1);
        }
      }
    }

    return null;
  }

  Future<Achievement?> _checkCentury() async {
    if (await _achievementRepo.exists(BadgeType.century)) {
      return null;
    }

    final total = await _getTotalCompletions();
    if (total >= 100) {
      final achievement = Achievement(
        id: const Uuid().v4(),
        badgeType: BadgeType.century,
        earnedAt: DateTime.now(),
      );
      await _achievementRepo.insert(achievement);
      return achievement;
    }

    return null;
  }

  Future<Achievement?> _checkDedicated() async {
    if (await _achievementRepo.exists(BadgeType.dedicated)) {
      return null;
    }

    final total = await _getTotalCompletions();
    if (total >= 500) {
      final achievement = Achievement(
        id: const Uuid().v4(),
        badgeType: BadgeType.dedicated,
        earnedAt: DateTime.now(),
      );
      await _achievementRepo.insert(achievement);
      return achievement;
    }

    return null;
  }

  // Helper methods

  Future<int> _getTotalCompletions() async {
    final instances = await _instanceRepo.getInstancesInRange(
      DateTime(2020, 1, 1), // All time
      DateTime.now(),
    );
    return instances.where((i) => i.status.name == 'done').length;
  }

  Future<int> _getCurrentStreak() async {
    int streak = 0;
    final today = DateTime.now();

    for (int i = 0; i < 365; i++) {
      final date = DateFormat('yyyy-MM-dd').format(today.subtract(Duration(days: i)));
      final instances = await _instanceRepo.getInstancesByDate(date);

      if (instances.isEmpty) break;

      final hasCompletions = instances.any((i) => i.status.name == 'done');
      if (hasCompletions) {
        streak++;
      } else {
        break;
      }
    }

    return streak;
  }

  /// Get all earned achievements
  Future<List<Achievement>> getAllAchievements() async {
    return await _achievementRepo.getAll();
  }
}

extension on Achievement {
  Achievement copyWith({int? earnedCount}) {
    return Achievement(
      id: id,
      badgeType: badgeType,
      earnedAt: earnedAt,
      earnedCount: earnedCount ?? this.earnedCount,
    );
  }
}
