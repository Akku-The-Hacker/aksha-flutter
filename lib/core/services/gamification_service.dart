import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/achievement_model.dart';
import '../models/daily_instance_model.dart';
import '../repositories/daily_instance_repository.dart';
import 'package:intl/intl.dart';

class GamificationService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final DailyInstanceRepository _instanceRepository = DailyInstanceRepository();

  // Check and award achievements after an instance is completed
  Future<List<BadgeType>> checkAchievements() async {
    final newBadges = <BadgeType>[];

    // Check each achievement type
    if (await _checkFirstCompletion()) newBadges.add(BadgeType.firstCompletion);
    if (await _checkStreak3()) newBadges.add(BadgeType.streak3);
    if (await _checkStreak7()) newBadges.add(BadgeType.streak7);
    if (await _checkStreak30()) newBadges.add(BadgeType.streak30);
    if (await _checkPerfectDay()) newBadges.add(BadgeType.perfectDay);
    if (await _checkCentury()) newBadges.add(BadgeType.century);
    if (await _checkDedicated()) newBadges.add(BadgeType.dedicated);

    // Award new badges
    for (final badgeType in newBadges) {
      await _awardBadge(badgeType);
    }

    return newBadges;
  }

  Future<bool> _checkFirstCompletion() async {
    final hasAchievement = await _hasAchievement(BadgeType.firstCompletion);
    if (hasAchievement) return false;

    final totalCompletions = await _getTotalCompletions();
    return totalCompletions >= 1;
  }

  Future<bool> _checkStreak3() async {
    if (await _hasAchievement(BadgeType.streak3)) return false;
    final streak = await _calculateStreak();
    return streak >= 3;
  }

  Future<bool> _checkStreak7() async {
    if (await _hasAchievement(BadgeType.streak7)) return false;
    final streak = await _calculateStreak();
    return streak >= 7;
  }

  Future<bool> _checkStreak30() async {
    if (await _hasAchievement(BadgeType.streak30)) return false;
    final streak = await _calculateStreak();
    return streak >= 30;
  }

  Future<bool> _checkPerfectDay() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final stats = await _instanceRepository.getDateStats(today);
    
    final total = stats['total'] ?? 0;
    final done = stats['done'] ?? 0;
    
    return total > 0 && total == done;
  }

  Future<bool> _checkCentury() async {
    if (await _hasAchievement(BadgeType.century)) return false;
    final total = await _getTotalCompletions();
    return total >= 100;
  }

  Future<bool> _checkDedicated() async {
    if (await _hasAchievement(BadgeType.dedicated)) return false;
    final total = await _getTotalCompletions();
    return total >= 500;
  }

  Future<int> _calculateStreak() async {
    int streak = 0;
    DateTime current = DateTime.now();

    while (true) {
      final dateStr = DateFormat('yyyy-MM-dd').format(current);
      final instances = await _instanceRepository.getByDate(dateStr);
      
      if (instances.isEmpty) break;
      
      final hasAnyDone = instances.any((i) => i.status == InstanceStatus.done);
      if (!hasAnyDone) break;
      
      streak++;
      current = current.subtract(const Duration(days: 1));
      
      if (streak > 365) break;
    }

    return streak;
  }

  Future<int> _getTotalCompletions() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM daily_instances WHERE status IN ('done', 'partial')"
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<bool> _hasAchievement(BadgeType badgeType) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'achievements',
      where: 'badge_type = ?',
      whereArgs: [badgeType.name],
    );
    return result.isNotEmpty;
  }

  Future<void> _awardBadge(BadgeType badgeType) async {
    final db = await _dbHelper.database;
    
    final achievement = Achievement(
      id: const Uuid().v4(),
      badgeType: badgeType,  // Pass enum directly, not .name
      earnedAt: DateTime.now(),
    );

    await db.insert(
      'achievements',
      achievement.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // Get all earned achievements
  Future<List<Achievement>> getEarnedAchievements() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'achievements',
      orderBy: 'earned_at DESC',
    );

    return maps.map((map) => Achievement.fromMap(map)).toList();
  }

  // Get total points (1 point per completion)
  Future<int> getTotalPoints() async {
    return await _getTotalCompletions();
  }

  // Update user stats
  Future<void> updateStats() async {
    final db = await _dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final streak = await _calculateStreak();
    final points = await getTotalPoints();

    // Update current streak
    await db.update(
      'user_stats',
      {'value': streak, 'updated_at': now},
      where: 'key = ?',
      whereArgs: ['current_streak'],
    );

    // Update longest streak if needed
    final longestResult = await db.query(
      'user_stats',
      where: 'key = ?',
      whereArgs: ['longest_streak'],
    );
    final longestStreak = longestResult.isNotEmpty
        ? (longestResult.first['value'] as int? ?? 0)
        : 0;

    if (streak > longestStreak) {
      await db.update(
        'user_stats',
        {'value': streak, 'updated_at': now},
        where: 'key = ?',
        whereArgs: ['longest_streak'],
      );
    }

    // Update total points
    await db.update(
      'user_stats',
      {'value': points, 'updated_at': now},
      where: 'key = ?',
      whereArgs: ['total_points'],
    );

    // Update last active date
    final todayStr = DateFormat('yyyyMMdd').format(DateTime.now());
    await db.update(
      'user_stats',
      {'value': int.parse(todayStr), 'updated_at': now},
      where: 'key = ?',
      whereArgs: ['last_active_date'],
    );
  }
}
