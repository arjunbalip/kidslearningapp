import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the child has done, saved on this device only (no accounts,
/// nothing sent anywhere).
///
/// - [stars]: earned by tracing a shape and by finishing an activity.
/// - traced: letters and numbers traced, per kind ("upper", "lower",
///   "number"). These fill the strips in the world menus.
/// - seen: learn cards looked at. Shown only in the parent area, because
///   swiping is not the same as learning.
/// - [gamesFinished]: games played to the end.
/// - [memoryLevel]: Memory game level (0, 1, 2 = 3, 4, 6 pairs); goes up
///   after each win.
///
/// Usage: `Progress.instance.addStar()`; widgets listen to it (it is a
/// ChangeNotifier, like INotifyPropertyChanged).
class Progress extends ChangeNotifier {
  Progress._();

  static final instance = Progress._();

  static const _key = 'progress_v1';

  int _stars = 0;
  int _gamesFinished = 0;
  int _memoryLevel = 0;
  final Map<String, Set<String>> _traced = {};
  final Map<String, Set<String>> _seen = {};

  /// Star count for the star counters (kept in step with [stars]).
  final ValueNotifier<int> starCount = ValueNotifier<int>(0);

  int get stars => _stars;
  int get gamesFinished => _gamesFinished;
  int get memoryLevel => _memoryLevel;

  /// Item ids traced for a kind ("upper", "lower" or "number").
  Set<String> traced(String kind) => _traced[kind] ?? const {};

  /// Item ids seen in learn cards for a pack type ("letters" or "numbers").
  Set<String> seen(String type) => _seen[type] ?? const {};

  bool isTraced(String kind, String id) => traced(kind).contains(id);

  /// Call once at start.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) _fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      // Damaged or unreadable: start fresh rather than stop the app.
      debugPrint('Progress.load failed: $e');
    }
    starCount.value = _stars;
    notifyListeners();
  }

  void addStar([int n = 1]) {
    _stars += n;
    _changed();
  }

  void markTraced(String kind, String id) {
    if ((_traced[kind] ??= {}).add(id)) _changed();
  }

  void markSeen(String type, String id) {
    if ((_seen[type] ??= {}).add(id)) _changed();
  }

  void gameFinished() {
    _gamesFinished++;
    _changed();
  }

  /// A Memory game was won: one level harder next time, up to [maxLevel].
  void memoryWon(int maxLevel) {
    if (_memoryLevel < maxLevel) _memoryLevel++;
    _changed();
  }

  /// Parent area: clears everything.
  Future<void> reset() async {
    _stars = 0;
    _gamesFinished = 0;
    _memoryLevel = 0;
    _traced.clear();
    _seen.clear();
    _changed();
  }

  void _changed() {
    starCount.value = _stars;
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(_toJson()));
    } catch (e) {
      debugPrint('Progress.save failed: $e');
    }
  }

  Map<String, dynamic> _toJson() => {
        'stars': _stars,
        'gamesFinished': _gamesFinished,
        'memoryLevel': _memoryLevel,
        'traced': {
          for (final e in _traced.entries) e.key: (e.value.toList()..sort())
        },
        'seen': {
          for (final e in _seen.entries) e.key: (e.value.toList()..sort())
        },
      };

  void _fromJson(Map<String, dynamic> j) {
    Map<String, Set<String>> sets(Object? v) => {
          for (final e in ((v as Map<String, dynamic>?) ?? const {}).entries)
            e.key: {for (final id in e.value as List<dynamic>) '$id'},
        };
    _stars = (j['stars'] as num?)?.toInt() ?? 0;
    _gamesFinished = (j['gamesFinished'] as num?)?.toInt() ?? 0;
    _memoryLevel = (j['memoryLevel'] as num?)?.toInt() ?? 0;
    _traced
      ..clear()
      ..addAll(sets(j['traced']));
    _seen
      ..clear()
      ..addAll(sets(j['seen']));
  }

  /// For tests: forget what is in memory (not what is saved).
  @visibleForTesting
  void clearForTest() {
    _stars = 0;
    _gamesFinished = 0;
    _memoryLevel = 0;
    _traced.clear();
    _seen.clear();
    starCount.value = 0;
  }
}
