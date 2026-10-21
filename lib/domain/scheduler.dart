import '../core/dates.dart';
import '../data/models.dart';

class Scheduler {
  static const double minEase = 1.3;
  static const double maxEase = 2.8;
  static const int maxInterval = 3650;

  static ScheduleResult schedule(StudyCard card, Rating rating, DateTime now) {
    final today = dateOnly(now);
    final ease = card.ease.clamp(minEase, maxEase).toDouble();
    final introducedOn = card.introducedOn ?? dateKey(today);

    switch (card.state) {
      case CardState.newCard:
        return switch (rating) {
          Rating.again => _result(
            state: CardState.learning,
            due: today,
            interval: 0,
            ease: ease,
            card: card,
            introducedOn: introducedOn,
          ),
          Rating.hard => _result(
            state: CardState.learning,
            due: addDays(today, 1),
            interval: 1,
            ease: ease,
            card: card,
            introducedOn: introducedOn,
          ),
          Rating.good => _result(
            state: CardState.learning,
            due: addDays(today, 1),
            interval: 1,
            ease: ease,
            card: card,
            introducedOn: introducedOn,
          ),
          Rating.easy => _result(
            state: CardState.review,
            due: addDays(today, 4),
            interval: 4,
            ease: ease,
            card: card,
            introducedOn: introducedOn,
          ),
        };
      case CardState.learning:
        return switch (rating) {
          Rating.again => _result(
            state: CardState.learning,
            due: today,
            interval: 0,
            ease: ease,
            card: card,
            introducedOn: introducedOn,
          ),
          Rating.hard => _result(
            state: CardState.learning,
            due: addDays(today, 1),
            interval: 1,
            ease: ease,
            card: card,
            introducedOn: introducedOn,
          ),
          Rating.good => _result(
            state: CardState.review,
            due: addDays(today, 3),
            interval: 3,
            ease: ease,
            card: card,
            introducedOn: introducedOn,
          ),
          Rating.easy => _result(
            state: CardState.review,
            due: addDays(today, 5),
            interval: 5,
            ease: ease,
            card: card,
            introducedOn: introducedOn,
          ),
        };
      case CardState.review:
        final base = card.intervalDays < 1 ? 1 : card.intervalDays;
        final hardInterval = _interval(_maxInt(base + 1, (base * 1.2).round()));
        final goodInterval = _interval(
          _maxInt(base + 1, (base * ease).round()),
        );
        final easyInterval = _interval(
          _maxInt(goodInterval + 1, (base * ease * 1.3).round()),
        );
        return switch (rating) {
          Rating.again => _result(
            state: CardState.review,
            due: addDays(today, 1),
            interval: 1,
            ease: ease - 0.2,
            card: card,
            lapses: card.lapses + 1,
            introducedOn: introducedOn,
          ),
          Rating.hard => _result(
            state: CardState.review,
            due: addDays(today, hardInterval),
            interval: hardInterval,
            ease: ease - 0.15,
            card: card,
            introducedOn: introducedOn,
          ),
          Rating.good => _result(
            state: CardState.review,
            due: addDays(today, goodInterval),
            interval: goodInterval,
            ease: ease,
            card: card,
            introducedOn: introducedOn,
          ),
          Rating.easy => _result(
            state: CardState.review,
            due: addDays(today, easyInterval),
            interval: easyInterval,
            ease: ease + 0.15,
            card: card,
            introducedOn: introducedOn,
          ),
        };
    }
  }

  static ScheduleResult _result({
    required CardState state,
    required DateTime due,
    required int interval,
    required double ease,
    required StudyCard card,
    required String introducedOn,
    int? lapses,
  }) {
    return ScheduleResult(
      state: state,
      dueDate: dateOnly(due),
      intervalDays: _interval(interval),
      ease: ease.clamp(minEase, maxEase).toDouble(),
      reps: card.reps + 1,
      lapses: lapses ?? card.lapses,
      introducedOn: introducedOn,
    );
  }

  static int _interval(int value) {
    if (value < 0) return 0;
    return value > maxInterval ? maxInterval : value;
  }

  static int _maxInt(int a, int b) => a > b ? a : b;
}
