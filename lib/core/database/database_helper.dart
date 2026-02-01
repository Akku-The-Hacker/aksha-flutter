import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  static const String _databaseName = 'aksha.db';
  static const int _databaseVersion = 2;

  // Singleton pattern
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createAllTables(db);
    await _seedDefaultData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Run migrations sequentially
    for (int version = oldVersion + 1; version <= newVersion; version++) {
      await _runMigration(db, version);
    }
  }

  Future<void> _runMigration(Database db, int version) async {
    switch (version) {
      case 2:
        await _migrateV1toV2(db);
        break;
      // Future migrations here
    }
  }

  Future<void> _migrateV1toV2(Database db) async {
    // Add gamification tables
    await db.execute('''
      CREATE TABLE IF NOT EXISTS achievements (
        id TEXT PRIMARY KEY,
        badge_type TEXT NOT NULL,
        earned_at INTEGER NOT NULL,
        earned_count INTEGER DEFAULT 1,
        UNIQUE(badge_type)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_stats (
        key TEXT PRIMARY KEY,
        value INTEGER DEFAULT 0,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Insert initial stats
    await db.execute('''
      INSERT OR IGNORE INTO user_stats (key, value, updated_at) VALUES
        ('current_streak', 0, 0),
        ('longest_streak', 0, 0),
        ('total_points', 0, 0),
        ('last_active_date', 0, 0)
    ''');
  }

  Future<void> _createAllTables(Database db) async {
    // CATEGORIES
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        color TEXT NOT NULL,
        icon TEXT,
        is_system INTEGER DEFAULT 0,
        sort_order INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        archived_at INTEGER
      )
    ''');

    // ROUTINES
    await db.execute('''
      CREATE TABLE routines (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category_id TEXT,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        is_overnight INTEGER DEFAULT 0,
        duration_minutes INTEGER NOT NULL,
        repeat_days TEXT NOT NULL,
        notification_enabled INTEGER DEFAULT 0,
        notification_minutes_before INTEGER DEFAULT 0,
        is_paused INTEGER DEFAULT 0,
        pause_until_date TEXT,
        start_date INTEGER,
        end_date INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        archived_at INTEGER,
        FOREIGN KEY (category_id) REFERENCES categories(id)
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_routines_category ON routines(category_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_routines_archived ON routines(archived_at)
    ''');

    // DAILY INSTANCES
    await db.execute('''
      CREATE TABLE daily_instances (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        routine_id TEXT NOT NULL,
        routine_name TEXT NOT NULL,
        category_id TEXT,
        category_name TEXT,
        category_color TEXT,
        planned_start TEXT NOT NULL,
        planned_end TEXT NOT NULL,
        planned_minutes INTEGER NOT NULL,
        is_overnight INTEGER DEFAULT 0,
        status TEXT DEFAULT 'pending',
        actual_minutes INTEGER,
        completed_at INTEGER,
        notes TEXT,
        edited_after_day_end INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (routine_id) REFERENCES routines(id),
        CHECK (status IN ('pending', 'done', 'partial', 'skipped', 'missed'))
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_instances_date ON daily_instances(date)
    ''');

    await db.execute('''
      CREATE INDEX idx_instances_routine ON daily_instances(routine_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_instances_status ON daily_instances(status)
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX idx_instances_unique ON daily_instances(date, routine_id)
    ''');

    // DAILY CACHE
    await db.execute('''
      CREATE TABLE daily_cache (
        date TEXT PRIMARY KEY,
        total_planned_minutes INTEGER DEFAULT 0,
        total_actual_minutes INTEGER DEFAULT 0,
        done_count INTEGER DEFAULT 0,
        partial_count INTEGER DEFAULT 0,
        skipped_count INTEGER DEFAULT 0,
        missed_count INTEGER DEFAULT 0,
        pending_count INTEGER DEFAULT 0,
        performance_pct REAL,
        has_activity INTEGER DEFAULT 0,
        is_dirty INTEGER DEFAULT 1,
        computed_at INTEGER
      )
    ''');

    // APP METADATA
    await db.execute('''
      CREATE TABLE app_metadata (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // UNDO STACK
    await db.execute('''
      CREATE TABLE undo_stack (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        action_type TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        previous_state TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    // ACHIEVEMENTS (Gamification)
    await db.execute('''
      CREATE TABLE achievements (
        id TEXT PRIMARY KEY,
        badge_type TEXT NOT NULL,
        earned_at INTEGER NOT NULL,
        earned_count INTEGER DEFAULT 1,
        UNIQUE(badge_type)
      )
    ''');

    // USER STATS (Gamification)
    await db.execute('''
      CREATE TABLE user_stats (
        key TEXT PRIMARY KEY,
        value INTEGER DEFAULT 0,
        updated_at INTEGER NOT NULL
      )
    ''');

    // TAGS
    await db.execute('''
      CREATE TABLE tags (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        color TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_tags_name ON tags(name)
    ''');

    // ROUTINE_TAGS (Junction table)
    await db.execute('''
      CREATE TABLE routine_tags (
        routine_id TEXT NOT NULL,
        tag_id TEXT NOT NULL,
        assigned_at INTEGER NOT NULL,
        PRIMARY KEY (routine_id, tag_id),
        FOREIGN KEY (routine_id) REFERENCES routines(id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_routine_tags_routine ON routine_tags(routine_id)
    ''');

    await db.execute('''
      CREATE INDEX idx_routine_tags_tag ON routine_tags(tag_id)
    ''');
  }

  Future<void> _seedDefaultData(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Seed default categories with updated colors (per v3.2 Addendum Part 42)
    await db.insert('categories', {
      'id': 'health',
      'name': 'Health',
      'color': '#34D399',
      'icon': '💪',
      'is_system': 1,
      'sort_order': 1,
      'created_at': now,
      'updated_at': now,
    });

    await db.insert('categories', {
      'id': 'study',
      'name': 'Study',
      'color': '#60A5FA',
      'icon': '📚',
      'is_system': 1,
      'sort_order': 2,
      'created_at': now,
      'updated_at': now,
    });

    await db.insert('categories', {
      'id': 'work',
      'name': 'Work',
      'color': '#FB923C',
      'icon': '💼',
      'is_system': 1,
      'sort_order': 3,
      'created_at': now,
      'updated_at': now,
    });

    await db.insert('categories', {
      'id': 'personal',
      'name': 'Personal',
      'color': '#C084FC',
      'icon': '🏠',
      'is_system': 1,
      'sort_order': 4,
      'created_at': now,
      'updated_at': now,
    });

    // Initialize user stats
    await db.insert('user_stats', {
      'key': 'current_streak',
      'value': 0,
      'updated_at': now,
    });

    await db.insert('user_stats', {
      'key': 'longest_streak',
      'value': 0,
      'updated_at': now,
    });

    await db.insert('user_stats', {
      'key': 'total_points',
      'value': 0,
      'updated_at': now,
    });

    await db.insert('user_stats', {
      'key': 'last_active_date',
      'value': 0,
      'updated_at': now,
    });

    // Set app metadata version
    await db.insert('app_metadata', {
      'key': 'schema_version',
      'value': _databaseVersion.toString(),
    });
  }

  // Clear all user data and reseed defaults
  Future<void> clearAllData() async {
    final db = await database;
    
    // Delete all data from tables (order matters for foreign keys)
    await db.delete('daily_instances');
    await db.delete('daily_cache');
    await db.delete('routines');
    await db.delete('categories');
    await db.delete('achievements');
    await db.delete('user_stats');
    await db.delete('undo_stack');
    await db.delete('tags');
    await db.delete('routine_tags');
    await db.delete('app_metadata');
    
    // Re-seed default data
    await _seedDefaultData(db);
  }

  // Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
