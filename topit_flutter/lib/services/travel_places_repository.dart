import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/travel_place.dart';

class TravelPlacesLoadResult {
  const TravelPlacesLoadResult._({this.places, this.errorMessage});

  const TravelPlacesLoadResult.success(List<TravelPlace> places)
    : this._(places: places);

  const TravelPlacesLoadResult.failure(String errorMessage)
    : this._(errorMessage: errorMessage);

  final List<TravelPlace>? places;
  final String? errorMessage;

  bool get isSuccess => places != null;
}

class TravelPlacesRepository {
  TravelPlacesRepository({
    this.assetPath = 'assets/data/iwate_morioka_100_places.json',
    AssetBundle? bundle,
  }) : _bundle = bundle;

  final String assetPath;
  final AssetBundle? _bundle;

  Future<TravelPlacesLoadResult> load() async {
    try {
      final bundle = _bundle ?? rootBundle;
      final raw = await bundle.loadString(assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return const TravelPlacesLoadResult.failure('スポットデータの形式が正しくありません');
      }

      final root = Map<String, dynamic>.from(decoded);
      final placesRaw = root['places'];
      if (placesRaw is! List) {
        return const TravelPlacesLoadResult.failure('スポット一覧が見つかりませんでした');
      }

      final places = <TravelPlace>[];
      for (final item in placesRaw) {
        if (item is! Map) {
          continue;
        }
        try {
          places.add(TravelPlace.fromJson(Map<String, dynamic>.from(item)));
        } catch (_) {
          // Skip invalid entries so one bad row does not crash the app.
        }
      }

      if (places.isEmpty) {
        return const TravelPlacesLoadResult.failure('読み込めるスポットがありませんでした');
      }

      return TravelPlacesLoadResult.success(places);
    } catch (_) {
      return const TravelPlacesLoadResult.failure('スポットデータの読み込みに失敗しました');
    }
  }
}
