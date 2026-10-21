import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'math_topics.dart';
import 'models.dart';

class AppDatabase {
  AppDatabase._(this.db, this.path);

  final Database db;
  final String path;

  static const int schemaVersion = 4;

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
          await _createSchema(db);
          await _seedMath(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 3) {
            for (final table in const [
              'review_logs',
              'cards',
              'decks',
              'activity',
              'progress',
              'topics',
            ]) {
              await db.execute('DROP TABLE IF EXISTS $table');
            }
            await _createSchema(db);
            await _seedMath(db);
            return;
          }
          if (oldVersion < 4) {
            await _ensureBuiltinColumn(db);
            await _seedMath(db);
          }
        },
      ),
    );
    return AppDatabase._(database, dbPath);
  }

  static Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS topics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject TEXT NOT NULL,
        chapter TEXT NOT NULL,
        title TEXT NOT NULL,
        sort_order INTEGER NOT NULL,
        is_builtin INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_topics_subject ON topics(subject, sort_order)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS progress (
        topic_id INTEGER PRIMARY KEY REFERENCES topics(id) ON DELETE CASCADE,
        learned_on TEXT NOT NULL,
        stage INTEGER NOT NULL DEFAULT 0,
        last_reviewed_on TEXT,
        completed_on TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activity (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topic_id INTEGER NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
        kind TEXT NOT NULL,
        happened_on TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_activity_day ON activity(happened_on)',
    );
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  static Future<void> _ensureBuiltinColumn(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(topics)');
    final names = {for (final column in columns) column['name'] as String};
    if (!names.contains('is_builtin')) {
      await db.execute(
        'ALTER TABLE topics ADD COLUMN is_builtin INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  static Future<void> _seedMath(Database db) async {
    final builtinRows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM topics WHERE subject = ? AND is_builtin = 1',
      [Subject.math.id],
    );
    final builtinCount = (builtinRows.first['count'] as num?)?.toInt() ?? 0;
    if (builtinCount > 0) return;

    final customRows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM topics WHERE subject = ? AND is_builtin = 0',
      [Subject.math.id],
    );
    final customCount = (customRows.first['count'] as num?)?.toInt() ?? 0;
    if (customCount > 0) {
      await db.rawUpdate(
        'UPDATE topics SET sort_order = sort_order + ? WHERE subject = ? AND is_builtin = 0',
        [mathTopicSeeds.length, Subject.math.id],
      );
    }

    final batch = db.batch();
    for (var index = 0; index < mathTopicSeeds.length; index++) {
      final seed = mathTopicSeeds[index];
      batch.insert('topics', {
        'subject': Subject.math.id,
        'chapter': seed.chapter,
        'title': seed.title,
        'sort_order': index,
        'is_builtin': 1,
      });
    }
    await batch.commit(noResult: true);
  }

  static Future<AppDatabase> inMemory() => openAt(inMemoryDatabasePath);

  Future<void> close() => db.close();
}
