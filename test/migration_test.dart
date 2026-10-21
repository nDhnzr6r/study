import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study/data/app_database.dart';
import 'package:study/data/models.dart';
import 'package:study/data/study_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('旧版数据库升级后保留设置并恢复数学内置知识点', () async {
    final directory = await Directory.systemTemp.createTemp(
      'study_migration_v2',
    );
    final path = p.join(directory.path, 'study.db');

    final oldDatabase = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await db.insert('settings', {'key': 'themeMode', 'value': 'dark'});
          await db.execute('''
            CREATE TABLE topics (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              subject TEXT NOT NULL,
              chapter TEXT NOT NULL,
              title TEXT NOT NULL,
              sort_order INTEGER NOT NULL
            )
          ''');
          await db.insert('topics', {
            'subject': 'math',
            'chapter': '第一章',
            'title': '旧版内置知识点',
            'sort_order': 0,
          });
          await db.execute('''
            CREATE TABLE progress (
              topic_id INTEGER PRIMARY KEY,
              learned_on TEXT NOT NULL,
              stage INTEGER NOT NULL DEFAULT 0,
              last_reviewed_on TEXT,
              completed_on TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE activity (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              topic_id INTEGER NOT NULL,
              kind TEXT NOT NULL,
              happened_on TEXT NOT NULL
            )
          ''');
          await db.execute(
            'CREATE TABLE decks (id INTEGER PRIMARY KEY, name TEXT)',
          );
          await db.execute(
            'CREATE TABLE cards (id INTEGER PRIMARY KEY, front TEXT)',
          );
          await db.execute('CREATE TABLE review_logs (id INTEGER PRIMARY KEY)');
        },
      ),
    );
    await oldDatabase.close();

    final database = await AppDatabase.openAt(path);
    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });

    final repository = StudyRepository(database);
    final plan = await repository.plan(Subject.math);
    expect(plan.total, 41);
    expect(plan.chapters.length, 8);

    final settings = await repository.settings();
    expect(settings['themeMode'], 'dark');

    final tables = await database.db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final names = {for (final row in tables) row['name'] as String};
    expect(names.contains('cards'), false);
    expect(names.contains('decks'), false);
    expect(names.contains('topics'), true);
  });

  test('从第三版升级时保留自定义知识点并补齐数学内置内容', () async {
    final directory = await Directory.systemTemp.createTemp(
      'study_migration_v3',
    );
    final path = p.join(directory.path, 'study.db');

    final oldDatabase = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await db.insert('settings', {'key': 'themeMode', 'value': 'light'});
          await db.execute('''
            CREATE TABLE topics (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              subject TEXT NOT NULL,
              chapter TEXT NOT NULL,
              title TEXT NOT NULL,
              sort_order INTEGER NOT NULL
            )
          ''');
          await db.insert('topics', {
            'subject': 'math',
            'chapter': '自定义章节',
            'title': '自定义知识点',
            'sort_order': 0,
          });
          await db.insert('topics', {
            'subject': 'chinese',
            'chapter': '第一单元',
            'title': '沁园春·长沙',
            'sort_order': 0,
          });
          await db.execute('''
            CREATE TABLE progress (
              topic_id INTEGER PRIMARY KEY,
              learned_on TEXT NOT NULL,
              stage INTEGER NOT NULL DEFAULT 0,
              last_reviewed_on TEXT,
              completed_on TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE activity (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              topic_id INTEGER NOT NULL,
              kind TEXT NOT NULL,
              happened_on TEXT NOT NULL
            )
          ''');
        },
      ),
    );
    await oldDatabase.close();

    final database = await AppDatabase.openAt(path);
    addTearDown(() async {
      await database.close();
      await directory.delete(recursive: true);
    });

    final repository = StudyRepository(database);
    final math = await repository.plan(Subject.math);
    expect(math.total, 42);
    expect(math.topics.first.topic.title, '集合的概念与表示');
    expect(math.topics.last.topic.title, '自定义知识点');
    expect(math.topics.last.topic.chapter, '自定义章节');

    final chinese = await repository.plan(Subject.chinese);
    expect(chinese.total, 1);
    expect(chinese.topics.single.topic.title, '沁园春·长沙');

    final builtin = await database.db.rawQuery(
      'SELECT COUNT(*) AS count FROM topics WHERE subject = ? AND is_builtin = 1',
      [Subject.math.id],
    );
    expect((builtin.first['count'] as num).toInt(), 41);
  });
}
