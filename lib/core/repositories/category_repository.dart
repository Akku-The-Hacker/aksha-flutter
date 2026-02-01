import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/category_model.dart';

class CategoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Get all active (non-archived) categories
  Future<List<Category>> getAllActive() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'archived_at IS NULL',
      orderBy: 'sort_order ASC, name ASC',
    );

    return maps.map((map) => Category.fromMap(map)).toList();
  }

  // Get category by ID
  Future<Category?> getById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Category.fromMap(maps.first);
  }

  // Insert new category
  Future<void> insert(Category category) async {
    final db = await _dbHelper.database;
    await db.insert(
      'categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Update category
  Future<void> update(Category category) async {
    final db = await _dbHelper.database;
    
    // Update timestamps
    final updatedCategory = category.copyWith(
      updatedAt: DateTime.now(),
    );

    await db.update(
      'categories',
      updatedCategory.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  // Soft delete (archive) category
  Future<void> softDelete(String id) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      'categories',
      {
        'archived_at': now,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    // Update all routines using this category to fallback to 'personal'
    await db.update(
      'routines',
      {
        'category_id': 'personal',
        'updated_at': now,
      },
      where: 'category_id = ? AND archived_at IS NULL',
      whereArgs: [id],
    );
  }

  // Hard delete (permanent)
  Future<void> hardDelete(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Check if category is system category
  Future<bool> isSystemCategory(String id) async {
    final category = await getById(id);
    return category?.isSystem ?? false;
  }

  // Get category count (for limiting custom categories)
  Future<int> getCustomCategoryCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM categories WHERE is_system = 0 AND archived_at IS NULL',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Get all categories (including archived)
  Future<List<Category>> getAll() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      orderBy: 'sort_order ASC, name ASC',
    );

    return maps.map((map) => Category.fromMap(map)).toList();
  }

  // Restore archived category
  Future<void> restore(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      'categories',
      {
        'archived_at': null,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Alias for softDelete
  Future<void> delete(String id) async {
    await softDelete(id);
  }
}
