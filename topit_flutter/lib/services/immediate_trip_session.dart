import '../models/immediate_trip.dart';
import '../models/travel_place.dart';
import '../models/travel_session.dart';
import 'travel_mission_service.dart';
import 'travel_session_store.dart';

class ImmediateTripStartResult {
  const ImmediateTripStartResult({
    required this.session,
    required this.usedFallback,
  });

  final TravelSession session;
  final bool usedFallback;
}

/// Navigator result bubbled back to TravelModeScreen.
class ImmediateTripLaunchResult {
  const ImmediateTripLaunchResult({required this.usedFallback});

  final bool usedFallback;
}

class ImmediateTripConditionUpdate {
  const ImmediateTripConditionUpdate({required this.condition});

  final ImmediateTripSearchCondition condition;
}

Future<ImmediateTripStartResult> startImmediateTripSession({
  required TravelPlace place,
  required String photoMission,
  required TravelSessionStore sessionStore,
  TravelMissionService? missionService,
}) async {
  final service = missionService ?? TravelMissionService();
  final itinerary =
      '盛岡駅から${place.name}（${place.municipality}）へ行く旅。'
      '移動は${place.transport.mode}、片道約${place.transport.oneWayMinutes}分。'
      '滞在の目安は約${place.recommendedStayMinutes}分。'
      'スポットの特徴: ${place.recommendation}'
      '${place.seasonNote == null || place.seasonNote!.isEmpty ? '' : '。注意: ${place.seasonNote}'}。'
      '参考の撮影テーマ: $photoMission';

  final result = await service.fetchTravelMissionResult(itinerary: itinerary);
  final now = DateTime.now();
  final session = TravelSession(
    id: 'trip-${now.millisecondsSinceEpoch}',
    itinerary: itinerary,
    startedAt: now,
    missions: result.missions,
    currentMissionIndex: 0,
    previousTitles: result.missions.map((mission) => mission.title).toList(),
  );
  await sessionStore.save(session);
  return ImmediateTripStartResult(
    session: session,
    usedFallback: result.usedFallback,
  );
}
