import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

abstract class WorldAnswerState {
  Future<String> clientId();

  Future<String?> answeredChallengeId();

  Future<void> markAnswered(String challengeId);

  Future<Set<String>> likedPostIds();

  Future<void> markLiked(String postId);
}

class InMemoryWorldAnswerState implements WorldAnswerState {
  String? _answeredChallengeId;
  String? _clientId;
  final Uuid _uuid = Uuid();
  final Set<String> _likedPostIds = {};

  @override
  Future<String> clientId() async => _clientId ??= _uuid.v4();

  @override
  Future<String?> answeredChallengeId() async => _answeredChallengeId;

  @override
  Future<void> markAnswered(String challengeId) async {
    _answeredChallengeId = challengeId;
  }

  @override
  Future<Set<String>> likedPostIds() async => Set<String>.from(_likedPostIds);

  @override
  Future<void> markLiked(String postId) async {
    _likedPostIds.add(postId);
  }
}

class WorldLocalState implements WorldAnswerState {
  WorldLocalState({SharedPreferencesAsync? preferences, Uuid? uuid})
    : _preferences = preferences ?? SharedPreferencesAsync(),
      _uuid = uuid ?? Uuid();

  static const _clientIdKey = 'world_client_id';
  static const _answeredChallengeIdKey = 'world_answered_challenge_id';
  static const _likedPostIdsKey = 'world_liked_post_ids';

  final SharedPreferencesAsync _preferences;
  final Uuid _uuid;

  @override
  Future<String> clientId() async {
    final existing = await _preferences.getString(_clientIdKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final clientId = _uuid.v4();
    await _preferences.setString(_clientIdKey, clientId);
    return clientId;
  }

  @override
  Future<String?> answeredChallengeId() {
    return _preferences.getString(_answeredChallengeIdKey);
  }

  @override
  Future<void> markAnswered(String challengeId) {
    return _preferences.setString(_answeredChallengeIdKey, challengeId);
  }

  @override
  Future<Set<String>> likedPostIds() async {
    final raw = await _preferences.getString(_likedPostIdsKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return {};
      }
      return decoded.whereType<String>().toSet();
    } on FormatException {
      return {};
    }
  }

  @override
  Future<void> markLiked(String postId) async {
    final liked = await likedPostIds();
    if (liked.contains(postId)) {
      return;
    }
    await _preferences.setString(
      _likedPostIdsKey,
      jsonEncode([...liked, postId]),
    );
  }
}
