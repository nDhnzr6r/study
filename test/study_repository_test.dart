import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study/core/dates.dart';
import 'package:study/data/app_database.dart';
import 'package:study/data/models.dart';
import 'package:study/data/study_repository.dart';
import 'package:study/domain/scheduler.dart';

void main() {
  final now = DateTime(2026, 10, 21, 10);

  late AppDatabase database;
  late StudyRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = await AppDatabase.inMemory();
    repository = StudyRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  Future<void> review(StudyCard card, Rating rating, DateTime at) async {
    final result = Scheduler.schedule(card, rating, at);
    await repository.recordReview(
      card: card,
      result: result,
      rating: rating,
      reviewedAt: at,
    );
  }

  test('卡组与卡片统计跟随复习更新', () async {
    final deckId = await repository.createDeck(name: '线性代数', description: '矩阵');
    await repository.createCard(deckId: deckId, front: 'A', back: '1');
    await repository.createCard(deckId: deckId, front: 'B', back: '2');
    await repository.createCard(deckId: deckId, front: 'C', back: '3');

    final before = (await repository.deckSummaries(now: now)).single;
    expect(before.total, 3);
    expect(before.newCount, 3);
    expect(before.due, 0);

    final cards = await repository.cardsInDeck(deckId);
    await review(cards.first, Rating.good, now);

    final after = (await repository.deckSummaries(now: now)).single;
    expect(after.total, 3);
    expect(after.newCount, 2);
    expect(after.due, 0);

    final tomorrow = addDays(now, 1);
    final nextDay = (await repository.deckSummaries(now: tomorrow)).single;
    expect(nextDay.due, 1);
  });

  test('每日新卡数量受上限约束', () async {
    final deckId = await repository.createDeck(name: '单词');
    for (var index = 0; index < 5; index++) {
      await repository.createCard(
        deckId: deckId,
        front: '$index',
        back: '$index',
      );
    }
    final fresh = await repository.newCards(limit: 2);
    expect(fresh.length, 2);
    expect((await repository.dueCards(now: now)).length, 0);
  });

  test('复习记录写入卡片并生成统计', () async {
    final deckId = await repository.createDeck(name: '历史');
    await repository.createCard(deckId: deckId, front: '年份', back: '1911');
    final card = (await repository.cardsInDeck(deckId)).single;

    await review(card, Rating.good, now);

    final updated = (await repository.cardsInDeck(deckId)).single;
    expect(updated.state, CardState.learning);
    expect(updated.intervalDays, 1);
    expect(updated.dueDate, addDays(now, 1));
    expect(updated.reps, 1);
    expect(updated.introducedOn, dateKey(now));
    expect(await repository.reviewCount(), 1);

    final overview = await repository.overview(now: now);
    expect(overview.reviewedToday, 1);
    expect(overview.introducedToday, 1);
    expect(overview.newTotal, 0);
    expect(overview.dueCount, 0);
    expect(overview.streak, 1);
    expect(overview.forecast[1].count, 1);
    expect(overview.activity.last.count, 1);
  });

  test('连续学习天数按复习日期计算', () async {
    final deckId = await repository.createDeck(name: '地理');
    await repository.createCard(deckId: deckId, front: '首都', back: '北京');
    final card = (await repository.cardsInDeck(deckId)).single;

    await review(card, Rating.good, addDays(now, -1));
    await review(
      (await repository.cardsInDeck(deckId)).single,
      Rating.good,
      now,
    );

    expect(await repository.streak(now: now), 2);
  });

  test('设置可以覆盖写入', () async {
    await repository.saveSetting(SettingKeys.dailyNewLimit, '20');
    expect((await repository.settings())[SettingKeys.dailyNewLimit], '20');
    await repository.saveSetting(SettingKeys.dailyNewLimit, '5');
    expect((await repository.settings())[SettingKeys.dailyNewLimit], '5');
  });

  test('导出与导入保留学习内容', () async {
    final deckId = await repository.createDeck(name: '物理', description: '力学');
    await repository.createCard(deckId: deckId, front: 'F=ma', back: '牛顿第二定律');
    await repository.createCard(deckId: deckId, front: 'E=mc²', back: '质能方程');
    final first = (await repository.cardsInDeck(deckId)).first;
    await review(first, Rating.good, now);

    final exported = await repository.exportJson();
    await repository.clearAll();
    expect(await repository.deckSummaries(now: now), isEmpty);

    await repository.importJson(exported);

    final summaries = await repository.deckSummaries(now: now);
    expect(summaries.length, 1);
    expect(summaries.single.deck.name, '物理');
    expect(summaries.single.total, 2);
    expect(summaries.single.newCount, 1);
    expect(await repository.reviewCount(), 0);
  });

  test('导入无效文件会报错且不破坏现有数据', () async {
    await repository.createDeck(name: '保留');
    await expectLater(
      repository.importJson('{"app":"other"}'),
      throwsFormatException,
    );
    expect((await repository.deckSummaries(now: now)).length, 1);
  });

  test('删除卡组会一并删除卡片与记录', () async {
    final deckId = await repository.createDeck(name: '待删除');
    await repository.createCard(deckId: deckId, front: 'A', back: 'B');
    final card = (await repository.cardsInDeck(deckId)).single;
    await review(card, Rating.good, now);

    await repository.deleteDeck(deckId);

    expect(await repository.deckSummaries(now: now), isEmpty);
    expect(await repository.cardsInDeck(deckId), isEmpty);
    expect(await repository.reviewCount(), 0);
  });
}
