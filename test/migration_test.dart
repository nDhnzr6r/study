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

  test('旧版数据库升级后保留设置并载入数学知识点', () async {
    final directory = await Directory.systemTemp.createTemp('study_migration');
    final path = p.join(directory.path, 'study.db');

    final oldDatabase = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
          );
          await db.insert('settings', {'key': 'themeMode', 'value': 'dark'});
          await db.execute('CREATE TABLE decks (id INTEGER PRIMARY KEY, name TEXT)');
          await db.execute('CREATE TABLE cards (id INTEGER PRIMARY KEY, front TEXT)');
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
}
