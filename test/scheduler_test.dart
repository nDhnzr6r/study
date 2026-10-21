import 'package:flutter_test/flutter_test.dart';
import 'package:study/core/dates.dart';
import 'package:study/data/models.dart';
import 'package:study/domain/scheduler.dart';

void main() {
  final now = DateTime(2026, 10, 21, 9, 30);

  StudyCard card({
    CardState state = CardState.newCard,
    int intervalDays = 0,
    double ease = 2.5,
    int reps = 0,
    int lapses = 0,
    String? introducedOn,
  }) {
    return StudyCard(
      id: 1,
      deckId: 1,
      front: '问题',
      back: '答案',
      state: state,
      dueDate: state == CardState.newCard ? null : dateOnly(now),
      intervalDays: intervalDays,
      ease: ease,
      reps: reps,
      lapses: lapses,
      introducedOn: introducedOn,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('新卡', () {
    test('忘记后今天再次出现，进入学习中', () {
      final result = Scheduler.schedule(card(), Rating.again, now);
      expect(result.state, CardState.learning);
      expect(result.dueDate, dateOnly(now));
      expect(result.intervalDays, 0);
      expect(result.introducedOn, '2026-10-21');
      expect(result.reps, 1);
    });

    test('记得后明天复习，仍处于学习中', () {
      final result = Scheduler.schedule(card(), Rating.good, now);
      expect(result.state, CardState.learning);
      expect(result.dueDate, addDays(now, 1));
      expect(result.intervalDays, 1);
    });

    test('简单后直接进入复习，间隔 4 天', () {
      final result = Scheduler.schedule(card(), Rating.easy, now);
      expect(result.state, CardState.review);
      expect(result.dueDate, addDays(now, 4));
      expect(result.intervalDays, 4);
    });
  });

  group('学习中', () {
    test('记得后毕业，间隔 3 天', () {
      final result = Scheduler.schedule(
        card(state: CardState.learning, intervalDays: 1),
        Rating.good,
        now,
      );
      expect(result.state, CardState.review);
      expect(result.intervalDays, 3);
      expect(result.dueDate, addDays(now, 3));
    });

    test('困难后保持一天后复习', () {
      final result = Scheduler.schedule(
        card(state: CardState.learning, intervalDays: 1),
        Rating.hard,
        now,
      );
      expect(result.state, CardState.learning);
      expect(result.intervalDays, 1);
      expect(result.dueDate, addDays(now, 1));
    });
  });

  group('复习中', () {
    test('记得按难度拉长间隔', () {
      final result = Scheduler.schedule(
        card(state: CardState.review, intervalDays: 10, ease: 2.5),
        Rating.good,
        now,
      );
      expect(result.intervalDays, 25);
      expect(result.dueDate, addDays(now, 25));
      expect(result.ease, 2.5);
      expect(result.reps, 1);
    });

    test('困难时降低难度并小幅增加间隔', () {
      final result = Scheduler.schedule(
        card(state: CardState.review, intervalDays: 10, ease: 2.5),
        Rating.hard,
        now,
      );
      expect(result.intervalDays, 12);
      expect(result.ease, closeTo(2.35, 0.0001));
    });

    test('间隔较小时困难也会延长一天', () {
      final result = Scheduler.schedule(
        card(state: CardState.review, intervalDays: 2, ease: 2.5),
        Rating.hard,
        now,
      );
      expect(result.intervalDays, 3);
    });

    test('简单时提高难度并加大间隔', () {
      final result = Scheduler.schedule(
        card(state: CardState.review, intervalDays: 10, ease: 2.5),
        Rating.easy,
        now,
      );
      expect(result.intervalDays, 33);
      expect(result.ease, closeTo(2.65, 0.0001));
    });

    test('忘记后回到一天，并记录一次遗忘', () {
      final result = Scheduler.schedule(
        card(state: CardState.review, intervalDays: 40, ease: 2.5, lapses: 2),
        Rating.again,
        now,
      );
      expect(result.state, CardState.review);
      expect(result.intervalDays, 1);
      expect(result.dueDate, addDays(now, 1));
      expect(result.ease, closeTo(2.3, 0.0001));
      expect(result.lapses, 3);
    });

    test('难度不低于 1.3', () {
      final result = Scheduler.schedule(
        card(state: CardState.review, intervalDays: 10, ease: 1.3),
        Rating.again,
        now,
      );
      expect(result.ease, Scheduler.minEase);
    });

    test('难度不高于 2.8', () {
      final result = Scheduler.schedule(
        card(state: CardState.review, intervalDays: 10, ease: 2.8),
        Rating.easy,
        now,
      );
      expect(result.ease, Scheduler.maxEase);
    });

    test('间隔不超过上限', () {
      final result = Scheduler.schedule(
        card(state: CardState.review, intervalDays: 3000, ease: 2.5),
        Rating.easy,
        now,
      );
      expect(result.intervalDays, Scheduler.maxInterval);
    });
  });
}
