import '../core/dates.dart';

const List<int> reviewOffsets = [1, 3, 7, 15, 30];

enum Subject {
  chinese('语文'),
  math('数学'),
  english('英语'),
  physics('物理'),
  chemistry('化学'),
  biology('生物');

  const Subject(this.label);

  final String label;

  String get id => name;

  bool get hasContent => this == Subject.math;

  static Subject fromId(String value) => Subject.values.firstWhere(
    (subject) => subject.id == value,
    orElse: () => Subject.math,
  );
}

class Topic {
  const Topic({
    this.id,
    required this.subject,
    required this.chapter,
    required this.title,
    required this.sortOrder,
  });

  final int? id;
  final Subject subject;
  final String chapter;
  final String title;
  final int sortOrder;
}

class TopicProgress {
  const TopicProgress({
    required this.topicId,
    required this.learnedOn,
    this.stage = 0,
    this.lastReviewedOn,
    this.completedOn,
  });

  final int topicId;
  final DateTime learnedOn;
  final int stage;
  final DateTime? lastReviewedOn;
  final DateTime? completedOn;

  TopicProgress copyWith({
    int? topicId,
    DateTime? learnedOn,
    int? stage,
    DateTime? lastReviewedOn,
    DateTime? completedOn,
  }) {
    return TopicProgress(
      topicId: topicId ?? this.topicId,
      learnedOn: learnedOn ?? this.learnedOn,
      stage: stage ?? this.stage,
      lastReviewedOn: lastReviewedOn ?? this.lastReviewedOn,
      completedOn: completedOn ?? this.completedOn,
    );
  }
}

class TopicStatus {
  const TopicStatus({required this.topic, this.progress});

  final Topic topic;
  final TopicProgress? progress;

  bool get isNew => progress == null;

  bool get isCompleted => (progress?.stage ?? 0) >= 5;

  int get reviewStage =>
      progress == null ? 0 : (progress!.stage + 1).clamp(1, 5).toInt();

  DateTime? get nextReviewDate {
    final current = progress;
    if (current == null || current.stage >= reviewOffsets.length) return null;
    return addDays(current.learnedOn, reviewOffsets[current.stage]);
  }

  bool isDue(DateTime now) {
    final current = progress;
    if (current == null || current.stage >= reviewOffsets.length) return false;
    final next = nextReviewDate;
    if (next == null) return false;
    final today = dateOnly(now);
    if (next.isAfter(today)) return false;
    final last = current.lastReviewedOn;
    if (last != null && dateKey(last) == dateKey(today)) return false;
    return true;
  }
}

class ChapterPlan {
  const ChapterPlan({
    required this.name,
    required this.total,
    required this.learned,
    required this.completed,
    required this.due,
  });

  final String name;
  final int total;
  final int learned;
  final int completed;
  final int due;

  double get progress => total == 0 ? 0 : learned / total;
}

class DayCount {
  const DayCount(this.day, this.count);

  final DateTime day;
  final int count;
}

class SubjectPlan {
  const SubjectPlan({
    required this.subject,
    required this.topics,
    required this.dueTopics,
    required this.newTopics,
    required this.chapters,
    required this.forecast,
    required this.learnedToday,
    required this.reviewedToday,
    required this.streak,
  });

  factory SubjectPlan.empty(Subject subject) {
    return SubjectPlan(
      subject: subject,
      topics: const [],
      dueTopics: const [],
      newTopics: const [],
      chapters: const [],
      forecast: const [],
      learnedToday: 0,
      reviewedToday: 0,
      streak: 0,
    );
  }

  final Subject subject;
  final List<TopicStatus> topics;
  final List<TopicStatus> dueTopics;
  final List<Topic> newTopics;
  final List<ChapterPlan> chapters;
  final List<DayCount> forecast;
  final int learnedToday;
  final int reviewedToday;
  final int streak;

  int get total => topics.length;
  int get learned => topics.where((status) => !status.isNew).length;
  int get completed => topics.where((status) => status.isCompleted).length;
  int get remainingNew => newTopics.length;
  int get dueCount => dueTopics.length;

  double get progress => total == 0 ? 0 : learned / total;

  Map<int, int> get dueByStage {
    final counts = <int, int>{};
    for (final status in dueTopics) {
      final stage = status.progress?.stage;
      if (stage == null) continue;
      final label = stage + 1;
      counts[label] = (counts[label] ?? 0) + 1;
    }
    return counts;
  }
}
