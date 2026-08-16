import 'dart:io';
import 'turso_client.dart';

TursoClient? _db;
bool _tablesReady = false;

Future<TursoClient> getDb() async {
  _db ??= TursoClient(
    databaseUrl: _requireEnv('TURSO_DATABASE_URL'),
    authToken: _requireEnv('TURSO_AUTH_TOKEN'),
  );

  if (!_tablesReady) {
    await _initTables(_db!);
    _tablesReady = true;
  }

  return _db!;
}

String _requireEnv(String key) {
  final value = Platform.environment[key];
  if (value == null || value.isEmpty) {
    throw StateError('Missing required environment variable: $key');
  }
  return value;
}

Future<void> _initTables(TursoClient db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS towers (
      id TEXT PRIMARY KEY,
      name TEXT,
      crop_type TEXT DEFAULT 'Lettuce',
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  await db.execute('''
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

  await db.execute('''
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

  await db.execute('''
    CREATE TABLE IF NOT EXISTS alerts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      tower_id TEXT,
      severity TEXT,
      title TEXT,
      description TEXT,
      created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )
  ''');

  await db.execute('''
    CREATE TABLE IF NOT EXISTS device_state (
      tower_id TEXT PRIMARY KEY,
      automatic_mode INTEGER DEFAULT 1,
      pump_manual INTEGER DEFAULT 0,
      pump_status INTEGER DEFAULT 0,
      pump_remaining_time INTEGER DEFAULT 0,
      updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (tower_id) REFERENCES towers(id)
    )
  ''');
}