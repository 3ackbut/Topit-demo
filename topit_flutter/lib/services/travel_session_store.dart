import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/travel_session.dart';

abstract class TravelSessionStore {
  Future<TravelSession?> load();
  Future<void> save(TravelSession session);
  Future<void> clear();
}

class SharedPreferencesTravelSessionStore implements TravelSessionStore {
  SharedPreferencesTravelSessionStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const activeSessionKey = 'travel_active_session';
  final SharedPreferencesAsync _preferences;

  @override
  Future<TravelSession?> load() async {
    final raw = await _preferences.getString(activeSessionKey);
    if (raw == null) return null;
    try {
      return TravelSession.fromJson(
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
  Future<void> save(TravelSession session) =>
      _preferences.setString(activeSessionKey, jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _preferences.remove(activeSessionKey);
}

class InMemoryTravelSessionStore implements TravelSessionStore {
  TravelSession? _session;

  @override
  Future<void> clear() async {
    _session = null;
  }

  @override
  Future<TravelSession?> load() async => _session;

  @override
  Future<void> save(TravelSession session) async {
    _session = session;
  }
}
