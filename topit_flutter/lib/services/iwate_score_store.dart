import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SavedIwateScore {
  const SavedIwateScore({
    required this.score,
    required this.targetNicheLevel,
    required this.measuredAt,
  });

  final double score;
  final double targetNicheLevel;
  final DateTime measuredAt;

  Map<String, dynamic> toJson() => {
    'score': score,
    'targetNicheLevel': targetNicheLevel,
    'measuredAt': measuredAt.toIso8601String(),
  };

  factory SavedIwateScore.fromJson(Map<String, dynamic> json) {
    final score = json['score'];
    final targetNicheLevel = json['targetNicheLevel'];
    final measuredAt = json['measuredAt'];
    if (score is! num || targetNicheLevel is! num || measuredAt is! String) {
      throw const FormatException('Invalid saved iwate score');
    }
    return SavedIwateScore(
      score: score.toDouble(),
      targetNicheLevel: targetNicheLevel.toDouble(),
      measuredAt: DateTime.parse(measuredAt),
    );
  }
}

abstract class IwateScoreStore {
  Future<SavedIwateScore?> load();
  Future<void> save(SavedIwateScore score);
  Future<void> clear();
}

class SharedPreferencesIwateScoreStore implements IwateScoreStore {
  SharedPreferencesIwateScoreStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const scoreKey = 'iwate_score_result';
  final SharedPreferencesAsync _preferences;

  @override
  Future<SavedIwateScore?> load() async {
    final raw = await _preferences.getString(scoreKey);
    if (raw == null) return null;
    try {
      return SavedIwateScore.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      try {
        await clear();
      } catch (_) {}
      return null;
    }
  }

  @override
  Future<void> save(SavedIwateScore score) =>
      _preferences.setString(scoreKey, jsonEncode(score.toJson()));

  @override
  Future<void> clear() => _preferences.remove(scoreKey);
}

class InMemoryIwateScoreStore implements IwateScoreStore {
  SavedIwateScore? _score;

  @override
  Future<void> clear() async {
    _score = null;
  }

  @override
  Future<SavedIwateScore?> load() async => _score;

  @override
  Future<void> save(SavedIwateScore score) async {
    _score = score;
  }
}
