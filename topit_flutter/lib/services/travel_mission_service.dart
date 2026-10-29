import '../data/travel_fallback_missions.dart';
import '../models/mission.dart';

class TravelMissionFetchResult {
  const TravelMissionFetchResult({
    required this.missions,
    required this.usedFallback,
  });

  final List<Mission> missions;
  final bool usedFallback;
}

class TravelMissionService {
  Future<List<Mission>> fetchTravelMissions({
    required String itinerary,
    List<String> previousTitles = const [],
  }) async =>
      (await fetchTravelMissionResult(
        itinerary: itinerary,
        previousTitles: previousTitles,
      )).missions;

  Future<TravelMissionFetchResult> fetchTravelMissionResult({
    required String itinerary,
    List<String> previousTitles = const [],
  }) async {
    final previous = previousTitles.toSet();
    final fresh =
        travelFallbackMissions
            .where((mission) => !previous.contains(mission.title))
            .toList();
    final source = fresh.length >= 3 ? fresh : travelFallbackMissions;
    return TravelMissionFetchResult(
      missions: source.take(3).toList(),
      usedFallback: true,
    );
  }
}
