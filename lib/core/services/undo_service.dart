import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

enum UndoActionType {
  routineCreate,
  routineUpdate,
  routineDelete,
  instanceStatusChange,
  categoryCreate,
  categoryUpdate,
  categoryDelete,
}

class UndoAction {
  final String id;
  final UndoActionType actionType;
  final String entityId;
  final String? previousState; // JSON string
  final String? newState; // JSON string
  final DateTime timestamp;

  UndoAction({
    required this.id,
    required this.actionType,
    required this.entityId,
    this.previousState,
    this.newState,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'action_type': actionType.name,
      'entity_id': entityId,
      'previous_state': previousState,
      'new_state': newState,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory UndoAction.fromMap(Map<String, dynamic> map) {
    return UndoAction(
      id: map['id'] as String,
      actionType: UndoActionType.values.firstWhere(
        (e) => e.name == map['action_type'],
      ),
      entityId: map['entity_id'] as String,
      previousState: map['previous_state'] as String?,
      newState: map['new_state'] as String?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    );
  }
}

class UndoService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  static const int _maxUndoStackSize = 50;
  static const Duration _undoTimeout = Duration(hours: 24);

  /// Record an action for undo
  Future<void> recordAction(UndoAction action) async {
    final db = await _dbHelper.database;
    
    // Insert action
    await db.insert('undo_stack', action.toMap());
    
    // Clean up old actions
    await _cleanupOldActions();
  }

  /// Get the most recent undoable action
  Future<UndoAction?> getLatestAction() async {
    final db = await _dbHelper.database;
    
    final cutoffTime = DateTime.now().subtract(_undoTimeout);
    final maps = await db.query(
      'undo_stack',
      where: 'timestamp > ?',
      whereArgs: [cutoffTime.millisecondsSinceEpoch],
      orderBy: 'timestamp DESC',
      limit: 1,
    );
    
    if (maps.isEmpty) return null;
    return UndoAction.fromMap(maps.first);
  }

  /// Remove an action from the stack
  Future<void> removeAction(String id) async {
    final db = await _dbHelper.database;
    await db.delete(
      'undo_stack',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Clean up old actions beyond timeout or max size
  Future<void> _cleanupOldActions() async {
    final db = await _dbHelper.database;
    
    // Remove actions older than timeout
    final cutoffTime = DateTime.now().subtract(_undoTimeout);
    await db.delete(
      'undo_stack',
      where: 'timestamp < ?',
      whereArgs: [cutoffTime.millisecondsSinceEpoch],
    );
    
    // Keep only the most recent N actions
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM undo_stack'),
    ) ?? 0;
    
    if (count > _maxUndoStackSize) {
      final toDelete = count - _maxUndoStackSize;
      await db.rawDelete('''
        DELETE FROM undo_stack
        WHERE id IN (
          SELECT id FROM undo_stack
          ORDER BY timestamp ASC
          LIMIT ?
        )
      ''', [toDelete]);
    }
  }

  /// Clear all undo history
  Future<void> clearAll() async {
    final db = await _dbHelper.database;
    await db.delete('undo_stack');
  }

  /// Get undo stack size
  Future<int> getStackSize() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM undo_stack');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
