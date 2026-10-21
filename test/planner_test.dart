import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study/core/dates.dart';
import 'package:study/data/app_database.dart';
import 'package:study/data/models.dart';
import 'package:study/data/study_repository.dart';

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

  Future<List<Topic>> topics() => repository.topics(Subject.math);

  test('初次打开只有数学知识点', () async {
    final math = await repository.plan(Subject.math, now: now);
    expect(math.total, 41);
    expect(math.remainingNew, 41);
    expect(math.dueCount, 0);
    expect(math.chapters.length, 8);

    final english = await repository.plan(Subject.english, now: now);
    expect(english.total, 0);
  });

  test('学习后按固定节奏出现在复习列表', () async {
    final topic = (await topics()).first;
    final id = topic.id!;

    expect(await repository.markLearned([id], now), 1);
    var plan = await repository.plan(Subject.math, now: now);
    expect(plan.learned, 1);
    expect(plan.learnedToday, 1);
    expect(plan.dueCount, 0);
    expect(plan.forecast[1].count, 1);

    for (var index = 0; index < reviewOffsets.length; index++) {
      final offset = reviewOffsets[index];
      final reviewDay = addDays(now, offset);
      plan = await repository.plan(Subject.math, now: reviewDay);
      expect(plan.dueCount, 1, reason: '第 $offset 天应该到期');
      final status = plan.dueTopics.single;
      expect(status.nextReviewDate, reviewDay);
      expect(status.reviewStage, index + 1);

      expect(await repository.markReviewed([id], reviewDay), 1);
      plan = await repository.plan(Subject.math, now: reviewDay);
      expect(plan.dueCount, 0, reason: '同一天完成后不再重复出现');
    }

    plan = await repository.plan(Subject.math, now: addDays(now, 31));
    expect(plan.completed, 1);
    expect(plan.dueCount, 0);
    final status = plan.topics.firstWhere((item) => item.topic.id == id);
    expect(status.isCompleted, true);
    expect(status.progress!.stage, 5);
    expect(status.progress!.completedOn, addDays(now, 30));
  });

  test('错过的复习会在之后列出，并且每天最多完成一次', () async {
    final topic = (await topics()).first;
    final id = topic.id!;
    await repository.markLearned([id], now);

    final lateDay = addDays(now, 5);
    var plan = await repository.plan(Subject.math, now: lateDay);
    expect(plan.dueCount, 1);
    expect(plan.dueTopics.single.nextReviewDate, addDays(now, 1));

    expect(await repository.markReviewed([id], lateDay), 1);
    plan = await repository.plan(Subject.math, now: lateDay);
    expect(plan.dueCount, 0);

    final nextDay = addDays(now, 6);
    plan = await repository.plan(Subject.math, now: nextDay);
    expect(plan.dueCount, 1);
    expect(plan.dueTopics.single.progress!.stage, 1);
    expect(plan.dueTopics.single.nextReviewDate, addDays(now, 3));
  });

  test('未到期时不能提前完成复习', () async {
    final topic = (await topics()).first;
    await repository.markLearned([topic.id!], now);
    expect(await repository.markReviewed([topic.id!], now), 0);
    final plan = await repository.plan(Subject.math, now: now);
    expect(plan.dueCount, 0);
  });

  test('重复标记已学不会改变学习日期', () async {
    final topic = (await topics()).first;
    await repository.markLearned([topic.id!], now);
    final later = addDays(now, 2);
    expect(await repository.markLearned([topic.id!], later), 0);
    final plan = await repository.plan(Subject.math, now: later);
    expect(plan.learned, 1);
    expect(plan.topics.first.progress!.learnedOn, dateOnly(now));
  });

  test('新知识点按顺序取出，且数量受参数限制', () async {
    final firstFive = await repository.newTopics(Subject.math, limit: 5);
    expect(firstFive.length, 5);
    expect(firstFive.first.title, '集合的概念与表示');

    await repository.markLearned([firstFive.first.id!], now);
    final next = await repository.newTopics(Subject.math, limit: 5);
    expect(next.first.title, '集合的基本运算');
  });

  test('连续学习天数按学习与复习记录计算', () async {
    final list = await topics();
    await repository.markLearned([list[0].id!, list[1].id!], now);
    var plan = await repository.plan(Subject.math, now: now);
    expect(plan.streak, 1);

    final dayOne = addDays(now, 1);
    await repository.markReviewed([list[0].id!, list[1].id!], dayOne);
    plan = await repository.plan(Subject.math, now: dayOne);
    expect(plan.streak, 2);
    expect(plan.reviewedToday, 2);

    plan = await repository.plan(Subject.math, now: addDays(now, 3));
    expect(plan.streak, 0);
  });

  test('清空进度会保留知识点', () async {
    final topic = (await topics()).first;
    await repository.markLearned([topic.id!], now);
    await repository.clearProgress();

    final plan = await repository.plan(Subject.math, now: now);
    expect(plan.total, 41);
    expect(plan.learned, 0);
    expect(plan.dueCount, 0);
    expect(await repository.markReviewed([topic.id!], addDays(now, 1)), 0);
  });
}
