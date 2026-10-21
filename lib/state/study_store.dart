import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../data/models.dart';
import '../data/study_repository.dart';
import '../domain/scheduler.dart';

class StudyStore extends ChangeNotifier {
  StudyStore(this._repository);

  final StudyRepository _repository;

  List<DeckSummary> _decks = const [];
  OverviewData? _overview;
  List<DayCount> _heatmap = const [];
  List<DayCount> _forecast = const [];
  ThemeMode _themeMode = ThemeMode.system;
  int _dailyNewLimit = 10;

  List<StudyCard> _sessionQueue = const [];
  int _sessionIndex = 0;
  bool _sessionAnswerShown = false;
  bool _sessionActive = false;
  bool _sessionFinished = false;
  int _sessionReviewed = 0;
  int _sessionAgain = 0;
  String _sessionScopeName = '全部卡片';
  DateTime _sessionStartedAt = DateTime.now();

  List<DeckSummary> get decks => _decks;
  OverviewData? get overview => _overview;
  List<DayCount> get heatmap => _heatmap;
  List<DayCount> get forecast => _forecast;
  ThemeMode get themeMode => _themeMode;
  int get dailyNewLimit => _dailyNewLimit;
  bool get isReady => _overview != null;
  String get databasePath => _repository.databasePath;

  int get dueCount => _overview?.dueCount ?? 0;
  int get reviewedToday => _overview?.reviewedToday ?? 0;
  int get newAvailable => _overview?.remainingNew(_dailyNewLimit) ?? 0;
  int get totalCards => _overview?.totalCards ?? 0;
  double get retention => _overview?.retention ?? 0;
  int get streak => _overview?.streak ?? 0;

  bool get sessionActive => _sessionActive;
  bool get sessionFinished => _sessionFinished;
  bool get sessionAnswerShown => _sessionAnswerShown;
  int get sessionReviewed => _sessionReviewed;
  int get sessionAgain => _sessionAgain;
  String get sessionScopeName => _sessionScopeName;
  int get sessionPosition => _sessionQueue.isEmpty
      ? 0
      : (_sessionIndex + 1).clamp(1, _sessionQueue.length).toInt();
  int get sessionTotal => _sessionQueue.length;
  double get sessionProgress => _sessionQueue.isEmpty
      ? 0
      : (_sessionIndex / _sessionQueue.length).clamp(0.0, 1.0).toDouble();
  Duration get sessionDuration => DateTime.now().difference(_sessionStartedAt);

  StudyCard? get currentCard {
    if (!_sessionActive ||
        _sessionIndex < 0 ||
        _sessionIndex >= _sessionQueue.length) {
      return null;
    }
    return _sessionQueue[_sessionIndex];
  }

  Future<void> load() async {
    final values = await _repository.settings();
    _dailyNewLimit = _parseDailyLimit(values[SettingKeys.dailyNewLimit]);
    _themeMode = _parseThemeMode(values[SettingKeys.themeMode]);
    await refresh();
  }

  Future<void> refresh() async {
    final decks = await _repository.deckSummaries();
    final overview = await _repository.overview();
    final heatmap = await _repository.activity(days: 91);
    final forecast = await _repository.forecast(days: 14);
    _decks = decks;
    _overview = overview;
    _heatmap = heatmap;
    _forecast = forecast;
    notifyListeners();
  }

  DeckSummary? summaryFor(int deckId) {
    for (final summary in _decks) {
      if (summary.deck.id == deckId) return summary;
    }
    return null;
  }

  Future<List<StudyCard>> cardsInDeck(
    int deckId, {
    String query = '',
    CardFilter filter = CardFilter.all,
  }) {
    return _repository.cardsInDeck(deckId, query: query, filter: filter);
  }

  Future<void> createDeck(String name, String description) async {
    await _repository.createDeck(name: name, description: description);
    await refresh();
  }

  Future<void> updateDeck(int deckId, String name, String description) async {
    await _repository.updateDeck(deckId, name: name, description: description);
    await refresh();
  }

  Future<void> deleteDeck(int deckId) async {
    await _repository.deleteDeck(deckId);
    await refresh();
  }

  Future<void> createCard({
    required int deckId,
    required String front,
    required String back,
    String note = '',
  }) async {
    await _repository.createCard(
      deckId: deckId,
      front: front,
      back: back,
      note: note,
    );
    await refresh();
  }

  Future<void> updateCard({
    required int cardId,
    required String front,
    required String back,
    String note = '',
  }) async {
    await _repository.updateCardContent(
      cardId,
      front: front,
      back: back,
      note: note,
    );
    await refresh();
  }

  Future<void> deleteCard(int cardId) async {
    await _repository.deleteCard(cardId);
    await refresh();
  }

  Future<bool> startSession({int? deckId}) async {
    if (_sessionActive) return true;
    final now = DateTime.now();
    final due = await _repository.dueCards(deckId: deckId, now: now);
    final introduced = await _repository.introducedOn(now);
    final allowance = _dailyNewLimit - introduced;
    final fresh = allowance > 0
        ? await _repository.newCards(deckId: deckId, limit: allowance)
        : const <StudyCard>[];
    final queue = <StudyCard>[...due, ...fresh];
    if (queue.isEmpty) return false;

    _sessionQueue = queue;
    _sessionIndex = 0;
    _sessionAnswerShown = false;
    _sessionActive = true;
    _sessionFinished = false;
    _sessionReviewed = 0;
    _sessionAgain = 0;
    _sessionScopeName = deckId == null ? '全部卡片' : _deckName(deckId);
    _sessionStartedAt = now;
    notifyListeners();
    return true;
  }

  void revealAnswer() {
    if (_sessionAnswerShown) return;
    _sessionAnswerShown = true;
    notifyListeners();
  }

  Future<void> rate(Rating rating) async {
    final card = currentCard;
    if (card == null || !_sessionAnswerShown) return;
    final now = DateTime.now();
    final result = Scheduler.schedule(card, rating, now);
    await _repository.recordReview(
      card: card,
      result: result,
      rating: rating,
      reviewedAt: now,
    );

    final updated = card.copyWith(
      state: result.state,
      dueDate: result.dueDate,
      intervalDays: result.intervalDays,
      ease: result.ease,
      reps: result.reps,
      lapses: result.lapses,
      introducedOn: result.introducedOn,
      updatedAt: now,
    );
    _sessionQueue[_sessionIndex] = updated;
    _sessionReviewed++;
    if (rating == Rating.again) _sessionAgain++;

    final repeatToday = !dateOnly(result.dueDate).isAfter(dateOnly(now));
    if (repeatToday) {
      _sessionQueue = [..._sessionQueue, updated];
    }
    _sessionIndex++;
    _sessionAnswerShown = false;

    if (_sessionIndex >= _sessionQueue.length) {
      _sessionFinished = true;
      notifyListeners();
      await refresh();
    } else {
      notifyListeners();
    }
  }

  Future<void> closeSession() async {
    _sessionActive = false;
    _sessionFinished = false;
    _sessionQueue = const [];
    _sessionIndex = 0;
    _sessionAnswerShown = false;
    notifyListeners();
    await refresh();
  }

  Future<void> updateDailyNewLimit(int value) async {
    final next = value.clamp(0, 100).toInt();
    _dailyNewLimit = next;
    await _repository.saveSetting(SettingKeys.dailyNewLimit, '$next');
    notifyListeners();
    await refresh();
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _repository.saveSetting(SettingKeys.themeMode, mode.name);
    notifyListeners();
  }

  Future<String> exportJson() => _repository.exportJson();

  Future<void> importJson(String source) async {
    await _repository.importJson(source);
    await refresh();
  }

  Future<void> clearAll() async {
    await _repository.clearAll();
    await refresh();
  }

  String _deckName(int deckId) {
    for (final summary in _decks) {
      if (summary.deck.id == deckId) return summary.deck.name;
    }
    return '卡组';
  }

  static int _parseDailyLimit(String? value) {
    final parsed = int.tryParse(value ?? '') ?? 10;
    return parsed.clamp(0, 100).toInt();
  }

  static ThemeMode _parseThemeMode(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
