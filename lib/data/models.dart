import '../core/dates.dart';

enum CardState {
  newCard,
  learning,
  review;

  String get dbValue => switch (this) {
    CardState.newCard => 'new',
    CardState.learning => 'learning',
    CardState.review => 'review',
  };

  String get label => switch (this) {
    CardState.newCard => '新卡',
    CardState.learning => '学习中',
    CardState.review => '复习中',
  };

  static CardState fromDb(String value) => switch (value) {
    'learning' => CardState.learning,
    'review' => CardState.review,
    _ => CardState.newCard,
  };
}

enum Rating {
  again,
  hard,
  good,
  easy;

  int get value => index;

  String get label => switch (this) {
    Rating.again => '忘记',
    Rating.hard => '困难',
    Rating.good => '记得',
    Rating.easy => '简单',
  };
}

enum CardFilter {
  all('全部'),
  due('待复习'),
  fresh('新卡'),
  mature('已掌握');

  const CardFilter(this.label);

  final String label;
}

class Deck {
  const Deck({
    this.id,
    required this.name,
    this.description = '',
    required this.createdAt,
  });

  final int? id;
  final String name;
  final String description;
  final DateTime createdAt;

  Deck copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? createdAt,
  }) {
    return Deck(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class DeckSummary {
  const DeckSummary({
    required this.deck,
    required this.total,
    required this.due,
    required this.newCount,
    required this.mature,
  });

  final Deck deck;
  final int total;
  final int due;
  final int newCount;
  final int mature;

  double get maturity => total == 0 ? 0 : mature / total;
  int get available => due + newCount;
}

class StudyCard {
  const StudyCard({
    this.id,
    required this.deckId,
    required this.front,
    required this.back,
    this.note = '',
    this.state = CardState.newCard,
    this.dueDate,
    this.intervalDays = 0,
    this.ease = 2.5,
    this.reps = 0,
    this.lapses = 0,
    this.introducedOn,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final int deckId;
  final String front;
  final String back;
  final String note;
  final CardState state;
  final DateTime? dueDate;
  final int intervalDays;
  final double ease;
  final int reps;
  final int lapses;
  final String? introducedOn;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool isDue(DateTime now) {
    if (state == CardState.newCard) return false;
    final due = dueDate;
    if (due == null) return false;
    return !dateOnly(due).isAfter(dateOnly(now));
  }

  StudyCard copyWith({
    int? id,
    int? deckId,
    String? front,
    String? back,
    String? note,
    CardState? state,
    DateTime? dueDate,
    int? intervalDays,
    double? ease,
    int? reps,
    int? lapses,
    String? introducedOn,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudyCard(
      id: id ?? this.id,
      deckId: deckId ?? this.deckId,
      front: front ?? this.front,
      back: back ?? this.back,
      note: note ?? this.note,
      state: state ?? this.state,
      dueDate: dueDate ?? this.dueDate,
      intervalDays: intervalDays ?? this.intervalDays,
      ease: ease ?? this.ease,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      introducedOn: introducedOn ?? this.introducedOn,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class ScheduleResult {
  const ScheduleResult({
    required this.state,
    required this.dueDate,
    required this.intervalDays,
    required this.ease,
    required this.reps,
    required this.lapses,
    required this.introducedOn,
  });

  final CardState state;
  final DateTime dueDate;
  final int intervalDays;
  final double ease;
  final int reps;
  final int lapses;
  final String introducedOn;
}

class DayCount {
  const DayCount(this.day, this.count);

  final DateTime day;
  final int count;
}

class OverviewData {
  const OverviewData({
    required this.dueCount,
    required this.newTotal,
    required this.learningCards,
    required this.youngCards,
    required this.matureCards,
    required this.totalCards,
    required this.reviewedToday,
    required this.introducedToday,
    required this.streak,
    required this.retention,
    required this.forecast,
    required this.activity,
  });

  final int dueCount;
  final int newTotal;
  final int learningCards;
  final int youngCards;
  final int matureCards;
  final int totalCards;
  final int reviewedToday;
  final int introducedToday;
  final int streak;
  final double retention;
  final List<DayCount> forecast;
  final List<DayCount> activity;

  int remainingNew(int dailyLimit) {
    final allowance = dailyLimit - introducedToday;
    if (allowance <= 0) return 0;
    return allowance < newTotal ? allowance : newTotal;
  }

  double progress(int dailyLimit) {
    final total = reviewedToday + dueCount + remainingNew(dailyLimit);
    if (total == 0) return 0;
    return (reviewedToday / total).clamp(0.0, 1.0).toDouble();
  }
}
