import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/dates.dart';
import 'app_database.dart';
import 'models.dart';

abstract final class SettingKeys {
  static const String themeMode = 'themeMode';
}

class StudyRepository {
  StudyRepository(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  String get databasePath => _database.path;

  Future<List<Topic>> topics(Subject subject) async {
    final rows = await _db.query(
      'topics',
      where: 'subject = ?',
      whereArgs: [subject.id],
      orderBy: 'sort_order ASC',
    );
    return rows.map(_topicFromRow).toList();
  }

  Future<List<Topic>> newTopics(Subject subject, {int limit = 5}) async {
    if (limit <= 0) return [];
    final rows = await _db.rawQuery(
      '''
      SELECT t.* FROM topics t
      LEFT JOIN progress p ON p.topic_id = t.id
      WHERE t.subject = ? AND p.topic_id IS NULL
      ORDER BY t.sort_order ASC
      LIMIT ?
    ''',
      [subject.id, limit],
    );
    return rows.map(_topicFromRow).toList();
  }

  Future<SubjectPlan> plan(Subject subject, {DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final today = dateOnly(clock);
    final todayKey = dateKey(today);

    final topicRows = await _db.query(
      'topics',
      where: 'subject = ?',
      whereArgs: [subject.id],
      orderBy: 'sort_order ASC',
    );
    final topics = topicRows.map(_topicFromRow).toList();
    final progressRows = await _db.query('progress');
    final progressByTopic = {
      for (final row in progressRows)
        row['topic_id'] as int: _progressFromRow(row),
    };

    final statuses = [
      for (final topic in topics)
        TopicStatus(topic: topic, progress: progressByTopic[topic.id]),
    ];

    final dueTopics = statuses.where((status) => status.isDue(clock)).toList()
      ..sort((a, b) {
        final byDate = a.nextReviewDate!.compareTo(b.nextReviewDate!);
        if (byDate != 0) return byDate;
        return a.topic.sortOrder.compareTo(b.topic.sortOrder);
      });

    final newTopics = [
      for (final status in statuses)
        if (status.isNew) status.topic,
    ];

    final chapterNames = <String>[];
    for (final topic in topics) {
      if (!chapterNames.contains(topic.chapter)) {
        chapterNames.add(topic.chapter);
      }
    }
    final chapters = [
      for (final chapter in chapterNames)
        _chapterPlan(
          chapter,
          statuses.where((status) => status.topic.chapter == chapter),
          clock,
        ),
    ];

    final forecastBuckets = List<int>.filled(7, 0);
    for (final status in statuses) {
      final progress = status.progress;
      if (progress == null || progress.stage >= reviewOffsets.length) continue;
      final next = status.nextReviewDate!;
      if (next.isAfter(today)) {
        final difference = next.difference(today).inDays;
        if (difference < forecastBuckets.length) forecastBuckets[difference]++;
      } else if (progress.lastReviewedOn != null &&
          dateKey(progress.lastReviewedOn!) == todayKey) {
        if (forecastBuckets.length > 1) forecastBuckets[1]++;
      } else {
        forecastBuckets[0]++;
      }
    }

    final learnedToday = statuses.where((status) {
      final progress = status.progress;
      return progress != null && dateKey(progress.learnedOn) == todayKey;
    }).length;

    final reviewedToday = await _count(
      '''
      SELECT COUNT(*) FROM activity a
      JOIN topics t ON t.id = a.topic_id
      WHERE t.subject = ? AND a.kind = 'review' AND a.happened_on = ?
      ''',
      [subject.id, todayKey],
    );

    return SubjectPlan(
      subject: subject,
      topics: statuses,
      dueTopics: dueTopics,
      newTopics: newTopics,
      chapters: chapters,
      forecast: [
        for (var index = 0; index < forecastBuckets.length; index++)
          DayCount(addDays(today, index), forecastBuckets[index]),
      ],
      learnedToday: learnedToday,
      reviewedToday: reviewedToday,
      streak: await _streak(subject, clock),
    );
  }

  Future<int> markLearned(Iterable<int> topicIds, DateTime now) async {
    final ids = topicIds.toSet().toList();
    if (ids.isEmpty) return 0;
    final todayKey = dateKey(now);
    var count = 0;
    await _db.transaction((txn) async {
      for (final topicId in ids) {
        final existing = await txn.query(
          'progress',
          columns: ['topic_id'],
          where: 'topic_id = ?',
          whereArgs: [topicId],
          limit: 1,
        );
        if (existing.isNotEmpty) continue;
        await txn.insert('progress', {
          'topic_id': topicId,
          'learned_on': todayKey,
          'stage': 0,
        });
        await txn.insert('activity', {
          'topic_id': topicId,
          'kind': 'learn',
          'happened_on': todayKey,
        });
        count++;
      }
    });
    return count;
  }

  Future<int> markReviewed(Iterable<int> topicIds, DateTime now) async {
    final ids = topicIds.toSet().toList();
    if (ids.isEmpty) return 0;
    final today = dateOnly(now);
    final todayKey = dateKey(today);
    var count = 0;
    await _db.transaction((txn) async {
      for (final topicId in ids) {
        final rows = await txn.query(
          'progress',
          where: 'topic_id = ?',
          whereArgs: [topicId],
          limit: 1,
        );
        if (rows.isEmpty) continue;
        final row = rows.first;
        final stage = (row['stage'] as num?)?.toInt() ?? 0;
        if (stage >= reviewOffsets.length) continue;
        final learnedOn = parseDateKey(row['learned_on']);
        if (learnedOn == null) continue;
        final nextReview = addDays(learnedOn, reviewOffsets[stage]);
        if (nextReview.isAfter(today)) continue;
        final lastReviewed = parseDateKey(row['last_reviewed_on']);
        if (lastReviewed != null && dateKey(lastReviewed) == todayKey) continue;

        final nextStage = stage + 1;
        await txn.update(
          'progress',
          {
            'stage': nextStage,
            'last_reviewed_on': todayKey,
            if (nextStage >= reviewOffsets.length) 'completed_on': todayKey,
          },
          where: 'topic_id = ?',
          whereArgs: [topicId],
        );
        await txn.insert('activity', {
          'topic_id': topicId,
          'kind': 'review',
          'happened_on': todayKey,
        });
        count++;
      }
    });
    return count;
  }

  Future<void> clearProgress() async {
    await _db.transaction((txn) async {
      await txn.delete('activity');
      await txn.delete('progress');
    });
  }

  Future<Map<String, String>> settings() async {
    final rows = await _db.query('settings');
    return {
      for (final row in rows) row['key'] as String: row['value'] as String,
    };
  }

  Future<void> saveSetting(String key, String value) async {
    await _db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> _count(String sql, List<Object?> args) async {
    final rows = await _db.rawQuery(sql, args);
    return (rows.first.values.first as num?)?.toInt() ?? 0;
  }

  Future<int> _streak(Subject subject, DateTime now) async {
    final rows = await _db.rawQuery(
      '''
      SELECT DISTINCT a.happened_on AS day FROM activity a
      JOIN topics t ON t.id = a.topic_id
      WHERE t.subject = ?
      ORDER BY day DESC
    ''',
      [subject.id],
    );
    final days = {for (final row in rows) row['day'] as String};
    var cursor = dateOnly(now);
    if (!days.contains(dateKey(cursor))) {
      cursor = addDays(cursor, -1);
      if (!days.contains(dateKey(cursor))) return 0;
    }
    var count = 0;
    while (days.contains(dateKey(cursor))) {
      count++;
      cursor = addDays(cursor, -1);
    }
    return count;
  }

  static ChapterPlan _chapterPlan(
    String name,
    Iterable<TopicStatus> statuses,
    DateTime now,
  ) {
    final list = statuses.toList();
    return ChapterPlan(
      name: name,
      total: list.length,
      learned: list.where((status) => !status.isNew).length,
      completed: list.where((status) => status.isCompleted).length,
      due: list.where((status) => status.isDue(now)).length,
    );
  }

  static Topic _topicFromRow(Map<String, Object?> row) {
    return Topic(
      id: row['id'] as int,
      subject: Subject.fromId(row['subject'] as String),
      chapter: row['chapter'] as String,
      title: row['title'] as String,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  static TopicProgress _progressFromRow(Map<String, Object?> row) {
    return TopicProgress(
      topicId: row['topic_id'] as int,
      learnedOn: parseDateKey(row['learned_on']) ?? DateTime.now(),
      stage: (row['stage'] as num?)?.toInt() ?? 0,
      lastReviewedOn: parseDateKey(row['last_reviewed_on']),
      completedOn: parseDateKey(row['completed_on']),
    );
  }
}
