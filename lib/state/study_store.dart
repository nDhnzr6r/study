import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/study_repository.dart';

class StudyStore extends ChangeNotifier {
  StudyStore(this._repository);

  final StudyRepository _repository;

  Map<Subject, SubjectPlan> _plans = const {};
  ThemeMode _themeMode = ThemeMode.system;
  bool _ready = false;

  bool get isReady => _ready;
  ThemeMode get themeMode => _themeMode;
  String get databasePath => _repository.databasePath;

  SubjectPlan planFor(Subject subject) =>
      _plans[subject] ?? SubjectPlan.empty(subject);

  int get mathDueCount => planFor(Subject.math).dueCount;

  Future<void> load() async {
    final settings = await _repository.settings();
    _themeMode = _parseThemeMode(settings[SettingKeys.themeMode]);
    await refresh();
  }

  Future<void> refresh() async {
    final plans = await Future.wait(
      Subject.values.map((subject) => _repository.plan(subject)),
    );
    _plans = {
      for (var index = 0; index < Subject.values.length; index++)
        Subject.values[index]: plans[index],
    };
    _ready = true;
    notifyListeners();
  }

  Future<int> createTopic({
    required Subject subject,
    required String chapter,
    required String title,
  }) async {
    final id = await _repository.createTopic(
      subject: subject,
      chapter: chapter,
      title: title,
    );
    await refresh();
    return id;
  }

  Future<void> updateTopic(
    int topicId, {
    required String chapter,
    required String title,
  }) async {
    await _repository.updateTopic(topicId, chapter: chapter, title: title);
    await refresh();
  }

  Future<void> deleteTopic(int topicId) async {
    await _repository.deleteTopic(topicId);
    await refresh();
  }

  Future<int> markLearned(Iterable<Topic> topics) async {
    final ids = topics
        .where((topic) => topic.id != null)
        .map((topic) => topic.id!)
        .toList();
    if (ids.isEmpty) return 0;
    final count = await _repository.markLearned(ids, DateTime.now());
    await refresh();
    return count;
  }

  Future<int> markReviewed(Iterable<TopicStatus> statuses) async {
    final ids = statuses
        .where((status) => status.topic.id != null)
        .map((status) => status.topic.id!)
        .toList();
    if (ids.isEmpty) return 0;
    final count = await _repository.markReviewed(ids, DateTime.now());
    await refresh();
    return count;
  }

  Future<void> clearProgress() async {
    await _repository.clearProgress();
    await refresh();
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _repository.saveSetting(SettingKeys.themeMode, mode.name);
    notifyListeners();
  }

  static ThemeMode _parseThemeMode(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
