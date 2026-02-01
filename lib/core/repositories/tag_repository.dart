import 'package:sqflite/sqflite.dart';
import '../models/tag_model.dart';
import '../database/database_helper.dart';

class TagRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  /// Get all tags
  Future<List<Tag>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query('tags', orderBy: 'name ASC');
    return maps.map((map) => Tag.fromMap(map)).toList();
  }

  /// Get tag by ID
  Future<Tag?> getById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'tags',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return Tag.fromMap(maps.first);
  }

  /// Insert new tag
  Future<void> insert(Tag tag) async {
    final db = await _dbHelper.database;
    await db.insert(
      'tags',
      tag.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update tag
  Future<void> update(Tag tag) async {
    final db = await _dbHelper.database;
    await db.update(
      'tags',
      tag.toMap(),
      where: 'id = ?',
      whereArgs: [tag.id],
    );
  }

  /// Delete tag
  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    
    // Delete tag-routine associations first
    await db.delete(
      'routine_tags',
      where: 'tag_id = ?',
      whereArgs: [id],
    );
    
    // Delete tag
    await db.delete(
      'tags',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get tags for a specific routine
  Future<List<Tag>> getTagsForRoutine(String routineId) async {
    final db = await _dbHelper.database;
    final maps = await db.rawQuery('''
      SELECT t.* FROM tags t
      INNER JOIN routine_tags rt ON t.id = rt.tag_id
      WHERE rt.routine_id = ?
      ORDER BY t.name ASC
    ''', [routineId]);
    
    return maps.map((map) => Tag.fromMap(map)).toList();
  }

  /// Get routines for a specific tag
  Future<List<String>> getRoutineIdsForTag(String tagId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'routine_tags',
      columns: ['routine_id'],
      where: 'tag_id = ?',
      whereArgs: [tagId],
    );
    
    return maps.map((map) => map['routine_id'] as String).toList();
  }

  /// Assign tag to routine
  Future<void> assignTagToRoutine(String routineId, String tagId) async {
    final db = await _dbHelper.database;
    final routineTag = RoutineTag(
      routineId: routineId,
      tagId: tagId,
      assignedAt: DateTime.now(),
    );
    
    await db.insert(
      'routine_tags',
      routineTag.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Remove tag from routine
  Future<void> removeTagFromRoutine(String routineId, String tagId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'routine_tags',
      where: 'routine_id = ? AND tag_id = ?',
      whereArgs: [routineId, tagId],
    );
  }

  /// Check if tag name already exists
  Future<bool> nameExists(String name, {String? excludeId}) async {
    final db = await _dbHelper.database;
    final where = excludeId != null ? 'name = ? AND id != ?' : 'name = ?';
    final whereArgs = excludeId != null ? [name, excludeId] : [name];
    
    final maps = await db.query(
      'tags',
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );
    
    return maps.isNotEmpty;
  }

  /// Get tag usage count (how many routines use this tag)
  Future<int> getUsageCount(String tagId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM routine_tags WHERE tag_id = ?',
      [tagId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
