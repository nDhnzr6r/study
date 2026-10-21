import 'dart:convert';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/dates.dart';
import '../domain/scheduler.dart';
import 'app_database.dart';
import 'models.dart';

abstract final class SettingKeys {
  static const String dailyNewLimit = 'dailyNewLimit';
  static const String themeMode = 'themeMode';
}

class StudyRepository {
  StudyRepository(this._database);

  final AppDatabase _database;

  Database get _db => _database.db;

  String get databasePath => _database.path;

  Future<List<DeckSummary>> deckSummaries({DateTime? now}) async {
    final today = dateKey(now ?? DateTime.now());
    final rows = await _db.rawQuery(
      '''
      SELECT d.id, d.name, d.description, d.created_at,
        COUNT(c.id) AS total,
        COALESCE(SUM(CASE WHEN c.state <> 'new' AND c.due_date IS NOT NULL
          AND c.due_date <= ? THEN 1 ELSE 0 END), 0) AS due_count,
        COALESCE(SUM(CASE WHEN c.state = 'new' THEN 1 ELSE 0 END), 0) AS new_count,
        COALESCE(SUM(CASE WHEN c.state = 'review' AND c.interval_days >= 21
          THEN 1 ELSE 0 END), 0) AS mature_count
      FROM decks d
      LEFT JOIN cards c ON c.deck_id = d.id
      GROUP BY d.id
      ORDER BY d.created_at ASC, d.id ASC
    ''',
      [today],
    );
    return rows.map(_deckSummaryFromRow).toList();
  }

  Future<DeckSummary?> deckSummary(int deckId, {DateTime? now}) async {
    final today = dateKey(now ?? DateTime.now());
    final rows = await _db.rawQuery(
      '''
      SELECT d.id, d.name, d.description, d.created_at,
        COUNT(c.id) AS total,
        COALESCE(SUM(CASE WHEN c.state <> 'new' AND c.due_date IS NOT NULL
          AND c.due_date <= ? THEN 1 ELSE 0 END), 0) AS due_count,
        COALESCE(SUM(CASE WHEN c.state = 'new' THEN 1 ELSE 0 END), 0) AS new_count,
        COALESCE(SUM(CASE WHEN c.state = 'review' AND c.interval_days >= 21
          THEN 1 ELSE 0 END), 0) AS mature_count
      FROM decks d
      LEFT JOIN cards c ON c.deck_id = d.id
      WHERE d.id = ?
      GROUP BY d.id
    ''',
      [today, deckId],
    );
    if (rows.isEmpty) return null;
    return _deckSummaryFromRow(rows.first);
  }

  Future<Deck?> deck(int deckId) async {
    final rows = await _db.query(
      'decks',
      where: 'id = ?',
      whereArgs: [deckId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _deckFromRow(rows.first);
  }

  Future<int> createDeck({required String name, String description = ''}) {
    return _db.insert('decks', {
      'name': name.trim(),
      'description': description.trim(),
      'created_at': timestamp(DateTime.now()),
    });
  }

  Future<void> updateDeck(
    int deckId, {
    required String name,
    String description = '',
  }) async {
    await _db.update(
      'decks',
      {'name': name.trim(), 'description': description.trim()},
      where: 'id = ?',
      whereArgs: [deckId],
    );
  }

  Future<void> deleteDeck(int deckId) async {
    await _db.delete('decks', where: 'id = ?', whereArgs: [deckId]);
  }

  Future<List<StudyCard>> cardsInDeck(
    int deckId, {
    String query = '',
    CardFilter filter = CardFilter.all,
    DateTime? now,
  }) async {
    final clauses = <String>['deck_id = ?'];
    final args = <Object?>[deckId];
    final keyword = query.trim();
    if (keyword.isNotEmpty) {
      clauses.add('(front LIKE ? OR back LIKE ? OR note LIKE ?)');
      final like = '%$keyword%';
      args.addAll([like, like, like]);
    }
    switch (filter) {
      case CardFilter.all:
        break;
      case CardFilter.due:
        clauses.add(
          "state <> 'new' AND due_date IS NOT NULL AND due_date <= ?",
        );
        args.add(dateKey(now ?? DateTime.now()));
      case CardFilter.fresh:
        clauses.add("state = 'new'");
      case CardFilter.mature:
        clauses.add("state = 'review' AND interval_days >= 21");
    }
    final rows = await _db.query(
      'cards',
      where: clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at DESC, id DESC',
    );
    return rows.map(_cardFromRow).toList();
  }

  Future<List<StudyCard>> dueCards({int? deckId, DateTime? now}) async {
    final today = dateKey(now ?? DateTime.now());
    final clauses = <String>[
      "state <> 'new'",
      'due_date IS NOT NULL',
      'due_date <= ?',
    ];
    final args = <Object?>[today];
    if (deckId != null) {
      clauses.add('deck_id = ?');
      args.add(deckId);
    }
    final rows = await _db.query(
      'cards',
      where: clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'due_date ASC, id ASC',
    );
    return rows.map(_cardFromRow).toList();
  }

  Future<List<StudyCard>> newCards({int? deckId, required int limit}) async {
    if (limit <= 0) return [];
    final clauses = <String>["state = 'new'"];
    final args = <Object?>[];
    if (deckId != null) {
      clauses.add('deck_id = ?');
      args.add(deckId);
    }
    final rows = await _db.query(
      'cards',
      where: clauses.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at ASC, id ASC',
      limit: limit,
    );
    return rows.map(_cardFromRow).toList();
  }

  Future<int> introducedOn(DateTime day) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS count FROM cards WHERE introduced_on = ?',
      [dateKey(day)],
    );
    return (rows.first['count'] as num?)?.toInt() ?? 0;
  }

  Future<int> createCard({
    required int deckId,
    required String front,
    required String back,
    String note = '',
  }) {
    final now = timestamp(DateTime.now());
    return _db.insert('cards', {
      'deck_id': deckId,
      'front': front.trim(),
      'back': back.trim(),
      'note': note.trim(),
      'state': CardState.newCard.dbValue,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> updateCardContent(
    int cardId, {
    required String front,
    required String back,
    String note = '',
  }) async {
    await _db.update(
      'cards',
      {
        'front': front.trim(),
        'back': back.trim(),
        'note': note.trim(),
        'updated_at': timestamp(DateTime.now()),
      },
      where: 'id = ?',
      whereArgs: [cardId],
    );
  }

  Future<void> deleteCard(int cardId) async {
    await _db.delete('cards', where: 'id = ?', whereArgs: [cardId]);
  }

  Future<void> recordReview({
    required StudyCard card,
    required ScheduleResult result,
    required Rating rating,
    DateTime? reviewedAt,
  }) async {
    final cardId = card.id;
    if (cardId == null) throw ArgumentError('卡片尚未保存');
    final at = reviewedAt ?? DateTime.now();
    await _db.transaction((txn) async {
      final affected = await txn.update(
        'cards',
        {
          'state': result.state.dbValue,
          'due_date': dateKey(result.dueDate),
          'interval_days': result.intervalDays,
          'ease': result.ease,
          'reps': result.reps,
          'lapses': result.lapses,
          'introduced_on': result.introducedOn,
          'updated_at': timestamp(at),
        },
        where: 'id = ?',
        whereArgs: [cardId],
      );
      if (affected == 0) throw StateError('卡片不存在');
      await txn.insert('review_logs', {
        'card_id': cardId,
        'rating': rating.value,
        'reviewed_at': timestamp(at),
        'prev_interval': card.intervalDays,
        'next_interval': result.intervalDays,
        'prev_state': card.state.dbValue,
        'next_state': result.state.dbValue,
      });
    });
  }

  Future<OverviewData> overview({DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final today = dateOnly(clock);
    final todayKey = dateKey(today);

    final dueCount = await _count(
      "SELECT COUNT(*) FROM cards WHERE state <> 'new' AND due_date IS NOT NULL AND due_date <= ?",
      [todayKey],
    );
    final reviewedToday = await _count(
      'SELECT COUNT(*) FROM review_logs WHERE substr(reviewed_at, 1, 10) = ?',
      [todayKey],
    );
    final introducedToday = await introducedOn(today);

    final stateRows = await _db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN state = 'new' THEN 1 ELSE 0 END), 0) AS new_total,
        COALESCE(SUM(CASE WHEN state = 'learning' THEN 1 ELSE 0 END), 0) AS learning,
        COALESCE(SUM(CASE WHEN state = 'review' AND interval_days < 21 THEN 1 ELSE 0 END), 0) AS young,
        COALESCE(SUM(CASE WHEN state = 'review' AND interval_days >= 21 THEN 1 ELSE 0 END), 0) AS mature,
        COUNT(*) AS total
      FROM cards
    ''');
    final stateRow = stateRows.first;
    int value(String key) => (stateRow[key] as num?)?.toInt() ?? 0;

    final retentionRows = await _db.rawQuery(
      '''
      SELECT
        COUNT(*) AS total,
        COALESCE(SUM(CASE WHEN rating >= 1 THEN 1 ELSE 0 END), 0) AS kept
      FROM review_logs
      WHERE substr(reviewed_at, 1, 10) >= ? AND substr(reviewed_at, 1, 10) <= ?
    ''',
      [dateKey(addDays(today, -29)), todayKey],
    );
    final retentionTotal = (retentionRows.first['total'] as num?)?.toInt() ?? 0;
    final retentionKept = (retentionRows.first['kept'] as num?)?.toInt() ?? 0;

    return OverviewData(
      dueCount: dueCount,
      newTotal: value('new_total'),
      learningCards: value('learning'),
      youngCards: value('young'),
      matureCards: value('mature'),
      totalCards: value('total'),
      reviewedToday: reviewedToday,
      introducedToday: introducedToday,
      streak: await streak(now: clock),
      retention: retentionTotal == 0 ? 0 : retentionKept / retentionTotal,
      forecast: await forecast(days: 7, now: clock),
      activity: await activity(days: 7, now: clock),
    );
  }

  Future<List<DayCount>> forecast({int days = 7, DateTime? now}) async {
    if (days <= 0) return [];
    final today = dateOnly(now ?? DateTime.now());
    final todayKey = dateKey(today);
    final endKey = dateKey(addDays(today, days - 1));
    final rows = await _db.rawQuery(
      '''
      SELECT due_date, COUNT(*) AS count
      FROM cards
      WHERE state <> 'new' AND due_date IS NOT NULL AND due_date <= ?
      GROUP BY due_date
    ''',
      [endKey],
    );
    final buckets = <String, int>{};
    for (final row in rows) {
      final key = row['due_date'] as String;
      final bucket = key.compareTo(todayKey) < 0 ? todayKey : key;
      buckets[bucket] =
          (buckets[bucket] ?? 0) + ((row['count'] as num?)?.toInt() ?? 0);
    }
    return [
      for (var index = 0; index < days; index++)
        DayCount(
          addDays(today, index),
          buckets[dateKey(addDays(today, index))] ?? 0,
        ),
    ];
  }

  Future<List<DayCount>> activity({int days = 7, DateTime? now}) async {
    if (days <= 0) return [];
    final today = dateOnly(now ?? DateTime.now());
    final startKey = dateKey(addDays(today, -(days - 1)));
    final endKey = dateKey(today);
    final rows = await _db.rawQuery(
      '''
      SELECT substr(reviewed_at, 1, 10) AS day, COUNT(*) AS count
      FROM review_logs
      WHERE substr(reviewed_at, 1, 10) >= ? AND substr(reviewed_at, 1, 10) <= ?
      GROUP BY day
    ''',
      [startKey, endKey],
    );
    final buckets = <String, int>{
      for (final row in rows)
        row['day'] as String: (row['count'] as num?)?.toInt() ?? 0,
    };
    return [
      for (var index = 0; index < days; index++)
        DayCount(
          addDays(today, -(days - 1 - index)),
          buckets[dateKey(addDays(today, -(days - 1 - index)))] ?? 0,
        ),
    ];
  }

  Future<int> streak({DateTime? now}) async {
    final today = dateOnly(now ?? DateTime.now());
    final rows = await _db.rawQuery(
      'SELECT DISTINCT substr(reviewed_at, 1, 10) AS day FROM review_logs ORDER BY day DESC',
    );
    final days = {for (final row in rows) row['day'] as String};
    var cursor = today;
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

  Future<String> exportJson() async {
    final deckRows = await _db.query(
      'decks',
      orderBy: 'created_at ASC, id ASC',
    );
    final cardRows = await _db.query(
      'cards',
      orderBy: 'created_at ASC, id ASC',
    );
    final grouped = <int, List<Map<String, Object?>>>{};
    for (final row in cardRows) {
      grouped
          .putIfAbsent(row['deck_id'] as int, () => [])
          .add(_exportCard(row));
    }
    final payload = {
      'app': 'study',
      'version': 1,
      'exportedAt': timestamp(DateTime.now()),
      'decks': [
        for (final row in deckRows)
          {
            'name': row['name'],
            'description': row['description'],
            'createdAt': row['created_at'],
            'cards': grouped[row['id'] as int] ?? const [],
          },
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  Future<void> importJson(String source) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const FormatException('文件内容不是有效的 JSON');
    }
    if (decoded is! Map) throw const FormatException('备份文件格式不正确');
    if (decoded['app'] != 'study' || decoded['version'] != 1) {
      throw const FormatException('不是有效的 Study 备份文件');
    }
    final deckList = decoded['decks'];
    if (deckList is! List) throw const FormatException('备份文件中缺少卡组');

    final now = DateTime.now();
    final parsed = <_ImportedDeck>[];
    for (final rawDeck in deckList) {
      if (rawDeck is! Map) throw const FormatException('卡组数据格式不正确');
      final name = (rawDeck['name'] as Object?)?.toString().trim() ?? '';
      if (name.isEmpty) throw const FormatException('卡组名称不能为空');
      final description =
          (rawDeck['description'] as Object?)?.toString().trim() ?? '';
      final createdAt =
          DateTime.tryParse(
            (rawDeck['createdAt'] as Object?)?.toString() ?? '',
          ) ??
          now;
      final rawCards = rawDeck['cards'];
      if (rawCards is! List) throw const FormatException('卡组中的卡片格式不正确');
      final cards = <Map<String, Object?>>[];
      for (final rawCard in rawCards) {
        cards.add(_parseImportedCard(rawCard, now));
      }
      parsed.add(_ImportedDeck(name, description, createdAt, cards));
    }

    await _db.transaction((txn) async {
      await txn.delete('review_logs');
      await txn.delete('cards');
      await txn.delete('decks');
      for (final imported in parsed) {
        final deckId = await txn.insert('decks', {
          'name': imported.name,
          'description': imported.description,
          'created_at': timestamp(imported.createdAt),
        });
        for (final card in imported.cards) {
          await txn.insert('cards', {...card, 'deck_id': deckId});
        }
      }
    });
  }

  Future<void> clearAll() async {
    await _db.transaction((txn) async {
      await txn.delete('review_logs');
      await txn.delete('cards');
      await txn.delete('decks');
    });
  }

  Future<int> reviewCount() => _count('SELECT COUNT(*) FROM review_logs');

  Future<int> _count(String sql, [List<Object?> args = const []]) async {
    final rows = await _db.rawQuery(sql, args);
    return (rows.first.values.first as num?)?.toInt() ?? 0;
  }

  Map<String, Object?> _exportCard(Map<String, Object?> row) {
    return {
      'front': row['front'],
      'back': row['back'],
      'note': row['note'],
      'state': row['state'],
      'dueDate': row['due_date'],
      'intervalDays': row['interval_days'],
      'ease': row['ease'],
      'reps': row['reps'],
      'lapses': row['lapses'],
      'introducedOn': row['introduced_on'],
      'createdAt': row['created_at'],
      'updatedAt': row['updated_at'],
    };
  }

  static Map<String, Object?> _parseImportedCard(Object? raw, DateTime now) {
    if (raw is! Map) throw const FormatException('卡片数据格式不正确');
    final front = (raw['front'] as Object?)?.toString().trim() ?? '';
    final back = (raw['back'] as Object?)?.toString().trim() ?? '';
    if (front.isEmpty || back.isEmpty) {
      throw const FormatException('卡片正面和背面都不能为空');
    }
    final note = (raw['note'] as Object?)?.toString().trim() ?? '';
    final stateValue = (raw['state'] as Object?)?.toString() ?? 'new';
    final state = switch (stateValue) {
      'new' => CardState.newCard,
      'learning' => CardState.learning,
      'review' => CardState.review,
      _ => throw const FormatException('卡片状态无法识别'),
    };
    final dueDate =
        parseDateKey(raw['dueDate']) ??
        (state == CardState.newCard ? null : dateOnly(now));
    final intervalDays = ((raw['intervalDays'] as num?)?.toInt() ?? 0).clamp(
      0,
      Scheduler.maxInterval,
    );
    final ease = ((raw['ease'] as num?)?.toDouble() ?? 2.5).clamp(
      Scheduler.minEase,
      Scheduler.maxEase,
    );
    final reps = ((raw['reps'] as num?)?.toInt() ?? 0).clamp(0, 1000000);
    final lapses = ((raw['lapses'] as num?)?.toInt() ?? 0).clamp(0, 1000000);
    final introducedOn = raw['introducedOn'] as String?;
    final createdAt =
        DateTime.tryParse((raw['createdAt'] as Object?)?.toString() ?? '') ??
        now;
    final updatedAt =
        DateTime.tryParse((raw['updatedAt'] as Object?)?.toString() ?? '') ??
        createdAt;
    return {
      'front': front,
      'back': back,
      'note': note,
      'state': state.dbValue,
      'due_date': dueDate == null ? null : dateKey(dueDate),
      'interval_days': intervalDays,
      'ease': ease,
      'reps': reps,
      'lapses': lapses,
      'introduced_on': introducedOn,
      'created_at': timestamp(createdAt),
      'updated_at': timestamp(updatedAt),
    };
  }

  static DeckSummary _deckSummaryFromRow(Map<String, Object?> row) {
    return DeckSummary(
      deck: _deckFromRow(row),
      total: (row['total'] as num?)?.toInt() ?? 0,
      due: (row['due_count'] as num?)?.toInt() ?? 0,
      newCount: (row['new_count'] as num?)?.toInt() ?? 0,
      mature: (row['mature_count'] as num?)?.toInt() ?? 0,
    );
  }

  static Deck _deckFromRow(Map<String, Object?> row) {
    return Deck(
      id: row['id'] as int,
      name: row['name'] as String,
      description: (row['description'] as String?) ?? '',
      createdAt:
          DateTime.tryParse(row['created_at'] as String) ?? DateTime.now(),
    );
  }

  static StudyCard _cardFromRow(Map<String, Object?> row) {
    return StudyCard(
      id: row['id'] as int,
      deckId: row['deck_id'] as int,
      front: row['front'] as String,
      back: row['back'] as String,
      note: (row['note'] as String?) ?? '',
      state: CardState.fromDb((row['state'] as String?) ?? 'new'),
      dueDate: parseDateKey(row['due_date']),
      intervalDays: (row['interval_days'] as num?)?.toInt() ?? 0,
      ease: (row['ease'] as num?)?.toDouble() ?? 2.5,
      reps: (row['reps'] as num?)?.toInt() ?? 0,
      lapses: (row['lapses'] as num?)?.toInt() ?? 0,
      introducedOn: row['introduced_on'] as String?,
      createdAt:
          DateTime.tryParse(row['created_at'] as String) ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(row['updated_at'] as String) ?? DateTime.now(),
    );
  }
}

class _ImportedDeck {
  const _ImportedDeck(this.name, this.description, this.createdAt, this.cards);

  final String name;
  final String description;
  final DateTime createdAt;
  final List<Map<String, Object?>> cards;
}
