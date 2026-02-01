import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/routine_model.dart';

class RoutineRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  // Get all active (non-archived, non-paused) routines
  Future<List<Routine>> getAllActive() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'routines',
      where: 'archived_at IS NULL AND is_paused = 0',
      orderBy: 'start_time ASC',
    );

    return maps.map((map) => Routine.fromMap(map)).toList();
  }

  // Get all routines including paused
  Future<List<Routine>> getAllNonArchived() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'routines',
      where: 'archived_at IS NULL',
      orderBy: 'start_time ASC',
    );

    return maps.map((map) => Routine.fromMap(map)).toList();
  }

  // Get routine by ID
  Future<Routine?> getById(String id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'routines',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    return Routine.fromMap(maps.first);
  }

  // Get routines by category
  Future<List<Routine>> getByCategory(String categoryId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'routines',
      where: 'category_id = ? AND archived_at IS NULL',
      whereArgs: [categoryId],
      orderBy: 'start_time ASC',
    );

    return maps.map((map) => Routine.fromMap(map)).toList();
  }

  // Get routines for a specific day of week
  Future<List<Routine>> getForDayOfWeek(int dayOfWeek) async {
    final allRoutines = await getAllActive();
    
    // Filter routines that include this day
    return allRoutines.where((routine) {
      return routine.repeatDays.contains(dayOfWeek);
    }).toList();
  }

  // Insert new routine
  Future<void> insert(Routine routine) async {
    final db = await _dbHelper.database;
    await db.insert(
      'routines',
      routine.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Update routine
  Future<void> update(Routine routine) async {
    final db = await _dbHelper.database;
    
    // Update timestamps
    final updatedRoutine = routine.copyWith(
      updatedAt: DateTime.now(),
    );

    await db.update(
      'routines',
      updatedRoutine.toMap(),
      where: 'id = ?',
      whereArgs: [routine.id],
    );
  }

  // Soft delete (archive) routine
  Future<void> softDelete(String id) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      'routines',
      {
        'archived_at': now,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Hard delete (permanent)
  Future<void> hardDelete(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'routines',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Pause routine
  Future<void> pause(String id, {String? pauseUntilDate}) async {
    final db = await _dbHelper.database;
    await db.update(
      'routines',
      {
        'is_paused': 1,
        'pause_until_date': pauseUntilDate,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Resume routine
  Future<void> resume(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      'routines',
      {
        'is_paused': 0,
        'pause_until_date': null,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Check for overlapping routines
  Future<bool> hasOverlap(Routine newRoutine, {String? excludeId}) async {
    final allRoutines = await getAllActive();
    
    print('DEBUG: Checking overlap for routine: ${newRoutine.name} (ID: ${newRoutine.id})');
    print('DEBUG: Excluding ID: $excludeId');
    print('DEBUG: Total active routines: ${allRoutines.length}');
    
    // Filter out the routine being edited
    final existingRoutines = allRoutines.where((r) => r.id != excludeId).toList();
    
    print('DEBUG: Routines to check against: ${existingRoutines.length}');
    for (final r in existingRoutines) {
      print('  - ${r.name} (ID: ${r.id}): ${r.startTime}-${r.endTime}, Days: ${r.repeatDays}');
    }

    for (final existing in existingRoutines) {
      // 0. Check Date Range Overlap FIRST
      // If the date ranges don't overlap, the time/days don't matter.
      if (!_hasDateOverlap(newRoutine, existing)) {
        continue;
      }

      // Check each day in new routine
      for (final day in newRoutine.repeatDays) {
        final newStart = _timeToMinutes(newRoutine.startTime);
        final newEnd = newRoutine.isOvernight 
            ? _timeToMinutes(newRoutine.endTime) + 1440 
            : _timeToMinutes(newRoutine.endTime);

        // 1. Check conflicts with existing routine on the SAME day
        if (existing.repeatDays.contains(day)) {
          final exStart = _timeToMinutes(existing.startTime);
          final exEnd = existing.isOvernight 
              ? _timeToMinutes(existing.endTime) + 1440 
              : _timeToMinutes(existing.endTime);

          if (newStart < exEnd && newEnd > exStart) {
            return true;
          }
        }

        // 2. Check conflicts with overnighters from PREVIOUS day (that extend into today)
        final prevDay = day == 1 ? 7 : day - 1;
        if (existing.repeatDays.contains(prevDay) && existing.isOvernight) {
          final exEndLate = _timeToMinutes(existing.endTime);
          // New routine range [newStart, newEnd] vs Existing range [0, exEndLate] on 'day'
          if (0 < exEndLate && 0 < newEnd && newStart < exEndLate) {
            return true;
          }
        }

        // 3. If new routine is overnight, check conflicts with routines on NEXT day
        if (newRoutine.isOvernight) {
          final nextDay = day == 7 ? 1 : day + 1;
          final newEndNextDay = _timeToMinutes(newRoutine.endTime);
          
          if (existing.repeatDays.contains(nextDay)) {
             final exStartNext = _timeToMinutes(existing.startTime);
             // New routine range [0, newEndNextDay] vs Existing range [exStartNext, ...] on 'nextDay'
             if (exStartNext < newEndNextDay) {
               return true;
             }
          }
        }
      }
    }

    return false; // No overlap found
  }

  // Helper: Check if two routines have overlapping Date Ranges
  bool _hasDateOverlap(Routine a, Routine b) {
    // If either is null, treat as infinite in that direction
    // A Start defaults to 'beginning of time' if null (or effectively 0)
    // A End defaults to 'end of time' if null
    
    // Check if A ends before B starts
    if (a.endDate != null && b.startDate != null) {
      // If A.end < B.start, no overlap
      // Use isBefore but strictly less than implies no overlap?
      // Usually same day might count as overlap?
      // Let's use strict comparison for Date only (ignoring time component of Date if any, but DateTime usually has time)
      // Assuming startDate/endDate are just dates (00:00:00).
      if (a.endDate!.isBefore(b.startDate!)) return false;
    }

    // Check if B ends before A starts
    if (b.endDate != null && a.startDate != null) {
      if (b.endDate!.isBefore(a.startDate!)) return false;
    }

    return true;
  }

  // Helper: Check if two time ranges overlap
  bool _hasTimeOverlap(
    String start1,
    String end1,
    bool overnight1,
    String start2,
    String end2,
    bool overnight2,
  ) {
    final s1 = _timeToMinutes(start1);
    final e1 = overnight1 ? _timeToMinutes(end1) + 1440 : _timeToMinutes(end1);
    final s2 = _timeToMinutes(start2);
    final e2 = overnight2 ? _timeToMinutes(end2) + 1440 : _timeToMinutes(end2);

    // For overnight routines, check both the primary and wrapped ranges
    if (overnight1 || overnight2) {
      // Check if ranges overlap
      return !(e1 <= s2 || e2 <= s1);
    }

    // Normal case: ranges overlap if not (end1 <= start2 OR end2 <= start1)
    return !(e1 <= s2 || e2 <= s1);
  }

  // Helper: Convert "HH:mm" to minutes since midnight
  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  // Get paused routines
  Future<List<Routine>> getPaused() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'routines',
      where: 'archived_at IS NULL AND is_paused = 1',
      orderBy: 'name ASC',
    );

    return maps.map((map) => Routine.fromMap(map)).toList();
  }

  // Get archived routines
  Future<List<Routine>> getArchived() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'routines',
      where: 'archived_at IS NOT NULL',
      orderBy: 'archived_at DESC',
    );

    return maps.map((map) => Routine.fromMap(map)).toList();
  }

  // Restore archived routine
  Future<void> restore(String id) async {
    final db = await _dbHelper.database;
    await db.update(
      'routines',
      {
        'archived_at': null,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
