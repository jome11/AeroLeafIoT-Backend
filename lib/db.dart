import 'package:sqlite3/sqlite3.dart';

Database? _db;

Database getDb() {
  _db ??= sqlite3.open('aeroleaf.db');
  _initTables(_db!);
  return _db!;
}

void _initTables(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS towers (
      id TEXT PRIMARY KEY,
      name TEXT,
      crop_type TEXT DEFAULT 'Lettuce',
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS telemetry (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tower_id TEXT,
      tds REAL,
      temperature REAL,
      water_level REAL,
      ph REAL,
      recorded_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (tower_id) REFERENCES towers(id)
    )
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS automation_schedules (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tower_id TEXT,
      name TEXT,
      cycle_interval_mins INTEGER,
      duration_secs INTEGER,
      active INTEGER DEFAULT 1,
      last_triggered TEXT,
      FOREIGN KEY (tower_id) REFERENCES towers(id)
    )
  ''');

  db.execute('''
    CREATE TABLE IF NOT EXISTS alerts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tower_id TEXT,
      severity TEXT,
      title TEXT,
      description TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  ''');
}