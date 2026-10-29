import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_post.dart';
import '../models/topic.dart';
import '../models/travel_trip_record.dart';

abstract class TravelTripHistoryStore {
  Future<List<TravelTripRecord>> loadAll({List<DailyPost> postsForMigration});

  Future<void> add(TravelTripRecord record);

  Future<TravelTripRecord?> findById(String id);

  Future<void> delete(String id);
}

class InMemoryTravelTripHistoryStore implements TravelTripHistoryStore {
  final List<TravelTripRecord> _records = [];

  @override
  Future<List<TravelTripRecord>> loadAll({
    List<DailyPost> postsForMigration = const [],
  }) async {
    final knownIds = _records.map((record) => record.id).toSet();
    _records.addAll(
      synthesizeTripRecordsFromPosts(postsForMigration)
          .where((record) => !knownIds.contains(record.id)),
    );
    return List<TravelTripRecord>.from(_records)
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
  }

  @override
  Future<void> add(TravelTripRecord record) async {
    final index = _records.indexWhere((item) => item.id == record.id);
    if (index < 0) {
      _records.add(record);
    } else {
      _records[index] = record;
    }
  }

  @override
  Future<TravelTripRecord?> findById(String id) async {
    for (final record in _records) {
      if (record.id == id) return record;
    }
    return null;
  }

  @override
  Future<void> delete(String id) async {
    _records.removeWhere((record) => record.id == id);
  }
}

const missingItineraryLabel = '（旅程情報なし）';

List<TravelTripRecord> synthesizeTripRecordsFromPosts(List<DailyPost> posts) {
  final grouped = <String, List<DailyPost>>{};
  for (final post in posts) {
    if (post.mode != TopicMode.travel) {
      continue;
    }
    final tripId = post.tripId;
    if (tripId == null || tripId.isEmpty) {
      continue;
    }
    grouped.putIfAbsent(tripId, () => []).add(post);
  }

  final records = <TravelTripRecord>[];
  for (final entry in grouped.entries) {
    final tripPosts = entry.value
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    records.add(
      TravelTripRecord(
        id: entry.key,
        itinerary: missingItineraryLabel,
        startedAt: tripPosts.first.createdAt,
        endedAt: tripPosts.last.createdAt,
      ),
    );
  }

  records.sort((a, b) => b.endedAt.compareTo(a.endedAt));
  return records;
}

class SharedPreferencesTravelTripHistoryStore
    implements TravelTripHistoryStore {
  SharedPreferencesTravelTripHistoryStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const historyKey = 'travel_trip_history';
  final SharedPreferencesAsync _preferences;
  var _migrationApplied = false;

  @override
  Future<List<TravelTripRecord>> loadAll({
    List<DailyPost> postsForMigration = const [],
  }) async {
    final records = await _readRecords();
    if (_migrationApplied || postsForMigration.isEmpty) {
      return _sortRecords(records);
    }

    final knownIds = records.map((record) => record.id).toSet();
    final synthesized = synthesizeTripRecordsFromPosts(postsForMigration)
        .where((record) => !knownIds.contains(record.id))
        .toList();
    if (synthesized.isEmpty) {
      _migrationApplied = true;
      return _sortRecords(records);
    }

    final merged = [...records, ...synthesized];
    await _writeRecords(merged);
    _migrationApplied = true;
    return _sortRecords(merged);
  }

  @override
  Future<void> add(TravelTripRecord record) async {
    final records = await _readRecords();
    final index = records.indexWhere((item) => item.id == record.id);
    if (index >= 0) {
      records[index] = record;
    } else {
      records.add(record);
    }
    await _writeRecords(records);
  }

  @override
  Future<TravelTripRecord?> findById(String id) async {
    final records = await _readRecords();
    for (final record in records) {
      if (record.id == id) {
        return record;
      }
    }
    return null;
  }

  @override
  Future<void> delete(String id) async {
    final records = await _readRecords();
    records.removeWhere((record) => record.id == id);
    await _writeRecords(records);
  }

  Future<List<TravelTripRecord>> _readRecords() async {
    final raw = await _preferences.getString(historyKey);
    if (raw == null) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw const FormatException('Invalid travel trip history');
      }

      return decoded
          .map(
            (item) => TravelTripRecord.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } catch (_) {
      await _preferences.remove(historyKey);
      return [];
    }
  }

  Future<void> _writeRecords(List<TravelTripRecord> records) {
    final payload = jsonEncode(records.map((record) => record.toJson()).toList());
    return _preferences.setString(historyKey, payload);
  }

  List<TravelTripRecord> _sortRecords(List<TravelTripRecord> records) {
    final sorted = List<TravelTripRecord>.from(records)
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    return sorted;
  }
}

class InMemoryTravelTripHistoryStore implements TravelTripHistoryStore {
  final List<TravelTripRecord> _records = [];
  var _migrationApplied = false;

  @override
  Future<void> add(TravelTripRecord record) async {
    final index = _records.indexWhere((item) => item.id == record.id);
    if (index >= 0) {
      _records[index] = record;
      return;
    }
    _records.add(record);
  }

  @override
  Future<TravelTripRecord?> findById(String id) async {
    for (final record in _records) {
      if (record.id == id) {
        return record;
      }
    }
    return null;
  }

  @override
  Future<List<TravelTripRecord>> loadAll({
    List<DailyPost> postsForMigration = const [],
  }) async {
    if (!_migrationApplied && postsForMigration.isNotEmpty) {
      final knownIds = _records.map((record) => record.id).toSet();
      final synthesized = synthesizeTripRecordsFromPosts(postsForMigration)
          .where((record) => !knownIds.contains(record.id));
      _records.addAll(synthesized);
      _migrationApplied = true;
    }

    final sorted = List<TravelTripRecord>.from(_records)
      ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
    return sorted;
  }

  @override
  Future<void> delete(String id) async {
    _records.removeWhere((record) => record.id == id);
  }
}
