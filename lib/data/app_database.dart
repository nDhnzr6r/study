import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  AppDatabase._(this.db, this.path);

  final Database db;
  final String path;

  static const int schemaVersion = 1;

  static Future<AppDatabase> open() async {
    final directory = _supportDirectory();
    await directory.create(recursive: true);
    return openAt(p.join(directory.path, 'study.db'));
  }

  static Directory _supportDirectory() {
    final appData = Platform.environment['APPDATA'];
    if (appData != null && appData.isNotEmpty) {
      return Directory(p.join(appData, 'Study'));
    }
    return Directory(p.join(Directory.current.path, 'StudyData'));
  }

  static Future<AppDatabase> openAt(String dbPath) async {
    final database = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE decks (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              description TEXT NOT NULL DEFAULT '',
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE cards (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              deck_id INTEGER NOT NULL REFERENCES decks(id) ON DELETE CASCADE,
              front TEXT NOT NULL,
              back TEXT NOT NULL,
              note TEXT NOT NULL DEFAULT '',
              state TEXT NOT NULL DEFAULT 'new',
              due_date TEXT,
              interval_days INTEGER NOT NULL DEFAULT 0,
              ease REAL NOT NULL DEFAULT 2.5,
              reps INTEGER NOT NULL DEFAULT 0,
              lapses INTEGER NOT NULL DEFAULT 0,
              introduced_on TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          await db.execute('CREATE INDEX idx_cards_deck ON cards(deck_id)');
          await db.execute(
            'CREATE INDEX idx_cards_due ON cards(state, due_date)',
          );
          await db.execute('''
            CREATE TABLE review_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              card_id INTEGER NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
              rating INTEGER NOT NULL,
              reviewed_at TEXT NOT NULL,
              prev_interval INTEGER NOT NULL,
              next_interval INTEGER NOT NULL,
              prev_state TEXT NOT NULL,
              next_state TEXT NOT NULL
            )
          ''');
          await db.execute(
            'CREATE INDEX idx_logs_reviewed ON review_logs(reviewed_at)',
          );
          await db.execute('''
            CREATE TABLE settings (
              key TEXT PRIMARY KEY,
              value TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    return AppDatabase._(database, dbPath);
  }

  static Future<AppDatabase> inMemory() => openAt(inMemoryDatabasePath);

  Future<void> close() => db.close();
}
