import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/daily_instance_model.dart';

class DailyInstanceRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Get instances for a specific date
  Future<List<DailyInstance>> getByDate(String date) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'daily_instances',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'planned_start ASC',
    );

    return maps.map((map) => DailyInstance.fromMap(map)).toList();
  }

  // Get instance by ID
  Future<DailyInstance?> getById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'daily_instances',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return DailyInstance.fromMap(maps.first);
  }

  // Get instances for a date range
  Future<List<DailyInstance>> getByDateRange(String startDate, String endDate) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'daily_instances',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date ASC, planned_start ASC',
    );

    return maps.map((map) => DailyInstance.fromMap(map)).toList();
  }

  // Get instances for a specific routine
  Future<List<DailyInstance>> getByRoutineId(String routineId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'daily_instances',
      where: 'routine_id = ?',
      whereArgs: [routineId],
      orderBy: 'date DESC',
    );

    return maps.map((map) => DailyInstance.fromMap(map)).toList();
  }

  // Insert new instance
  Future<void> insert(DailyInstance instance) async {
    final db = await _dbHelper.database;
    await db.insert(
      'daily_instances',
      instance.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Batch insert instances (for generation)
  Future<void> batchInsert(List<DailyInstance> instances) async {
    final db = await _dbHelper.database;
    final batch = db.batch();
    
    for (final instance in instances) {
      batch.insert(
        'daily_instances',
        instance.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore, // Don't override existing
      );
    }
    
    await batch.commit(noResult: true);
  }

  // Update instance
  Future<void> update(DailyInstance instance) async {
    final db = await _dbHelper.database;
    
    // Update timestamps
    final updatedInstance = instance.copyWith(
      updatedAt: DateTime.now(),
    );

    await db.update(
      'daily_instances',
      updatedInstance.toMap(),
      where: 'id = ?',
      whereArgs: [instance.id],
    );
  }

  // Update instance status
  Future<void> updateStatus(
    String id,
    InstanceStatus status, {
    int? actualMinutes,
    String? notes,
  }) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();

    // Check if editing after day end
    final instance = await getById(id);
    final editedAfterDayEnd = instance != null &&
        !_isSameDay(DateFormat('yyyy-MM-dd').parse(instance.date), now);

    await db.update(
      'daily_instances',
      {
        'status': status.name,
        'actual_minutes': actualMinutes,
        'completed_at': (status == InstanceStatus.done || status == InstanceStatus.partial)
            ? now.millisecondsSinceEpoch
            : null,
        'notes': notes,
        'edited_after_day_end': editedAfterDayEnd ? 1 : 0,
        'updated_at': now.millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    // Invalidate cache for this date
    if (instance != null) {
      await _invalidateCache(instance.date);
    }
  }

  // Mark instances as missed at end of day
  Future<int> markPendingAsMissed(String date) async {
    final db = await _dbHelper.database;
    final count = await db.update(
      'daily_instances',
      {
        'status': InstanceStatus.missed.name,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'date = ? AND status = ?',
      whereArgs: [date, InstanceStatus.pending.name],
    );

    if (count > 0) {
      await _invalidateCache(date);
    }

    return count;
  }

  // Delete instance
  Future<void> delete(String id) async {
    final db = await _dbHelper.database;
    final instance = await getById(id);
    
    await db.delete(
      'daily_instances',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (instance != null) {
      await _invalidateCache(instance.date);
    }
  }

  // Delete all instances for a routine
  Future<void> deleteByRoutineId(String routineId) async {
    final db = await _dbHelper.database;
    await db.delete(
      'daily_instances',
      where: 'routine_id = ?',
      whereArgs: [routineId],
    );
  }

  // Get instances by status
  Future<List<DailyInstance>> getByStatus(String date, InstanceStatus status) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'daily_instances',
      where: 'date = ? AND status = ?',
      whereArgs: [date, status.name],
      orderBy: 'planned_start ASC',
    );

    return maps.map((map) => DailyInstance.fromMap(map)).toList();
  }

  // Check if instance exists for date and routine
  Future<bool> exists(String date, String routineId) async {
    final db = await _dbHelper.database;
    final result = await db.query(
      'daily_instances',
      where: 'date = ? AND routine_id = ?',
      whereArgs: [date, routineId],
      limit: 1,
    );

    return result.isNotEmpty;
  }

  // Get completion statistics for a date
  Future<Map<String, int>> getDateStats(String date) async {
    final instances = await getByDate(date);

    return {
      'total': instances.length,
      'pending': instances.where((i) => i.status == InstanceStatus.pending).length,
      'done': instances.where((i) => i.status == InstanceStatus.done).length,
      'partial': instances.where((i) => i.status == InstanceStatus.partial).length,
      'skipped': instances.where((i) => i.status == InstanceStatus.skipped).length,
      'missed': instances.where((i) => i.status == InstanceStatus.missed).length,
    };
  }

  // Invalidate cache for a specific date
  Future<void> _invalidateCache(String date) async {
    final db = await _dbHelper.database;
    await db.update(
      'daily_cache',
      {
        'is_dirty': 1,
        'computed_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'date = ?',
      whereArgs: [date],
    );

    // If cache doesn't exist, create it as dirty
    final exists = await db.query(
      'daily_cache',
      where: 'date = ?',
      whereArgs: [date],
      limit: 1,
    );

    if (exists.isEmpty) {
      await db.insert('daily_cache', {
        'date': date,
        'is_dirty': 1,
        'computed_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  // Helper: Check if two dates are same day
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // Get instances that were edited retroactively
  Future<List<DailyInstance>> getEditedAfterDayEnd(String startDate, String endDate) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'daily_instances',
      where: 'date >= ? AND date <= ? AND edited_after_day_end = 1',
      whereArgs: [startDate, endDate],
      orderBy: 'date DESC',
    );

    return maps.map((map) => DailyInstance.fromMap(map)).toList();
  }

  // Get instances in date range (alias for getByDateRange)
  Future<List<DailyInstance>> getInstancesInRange(DateTime startDate, DateTime endDate) async {
    final startStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(endDate);
    return getByDateRange(startStr, endStr);
  }

  // Get instances by date (alias for getByDate)
  Future<List<DailyInstance>> getInstancesByDate(String date) async {
    return getByDate(date);
  }
}
