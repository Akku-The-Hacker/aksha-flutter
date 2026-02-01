import 'package:sqflite/sqflite.dart';
import '../models/achievement_model.dart';
import '../database/database_helper.dart';

class AchievementRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Get all earned achievements
  Future<List<Achievement>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'achievements',
      orderBy: 'earned_at DESC',
    );
    return maps.map((map) => Achievement.fromMap(map)).toList();
  }

  /// Get specific achievement by badge type
  Future<Achievement?> getByBadgeType(BadgeType badgeType) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'achievements',
      where: 'badge_type = ?',
      whereArgs: [badgeType.name],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return Achievement.fromMap(maps.first);
  }

  /// Insert new achievement
  Future<void> insert(Achievement achievement) async {
    final db = await _dbHelper.database;
    await db.insert(
      'achievements',
      achievement.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update achievement (for repeatable badges)
  Future<void> update(Achievement achievement) async {
    final db = await _dbHelper.database;
    await db.update(
      'achievements',
      achievement.toMap(),
      where: 'id = ?',
      whereArgs: [achievement.id],
    );
  }

  /// Increment earned count for repeatable achievement
  Future<void> incrementEarnedCount(String id) async {
    final db = await _dbHelper.database;
    await db.rawUpdate(
      'UPDATE achievements SET earned_count = earned_count + 1 WHERE id = ?',
      [id],
    );
  }

  /// Check if achievement exists
  Future<bool> exists(BadgeType badgeType) async {
    final achievement = await getByBadgeType(badgeType);
    return achievement != null;
  }

  /// Get total count of achievements earned
  Future<int> getTotalCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM achievements');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Delete all achievements (for testing/reset)
  Future<void> deleteAll() async {
    final db = await _dbHelper.database;
    await db.delete('achievements');
  }
}
