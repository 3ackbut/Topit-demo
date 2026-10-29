import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:topit_flutter/data/iwate_quiz_questions.dart';
import 'package:topit_flutter/models/immediate_trip.dart';
import 'package:topit_flutter/models/travel_place.dart';
import 'package:topit_flutter/services/immediate_trip_logic.dart';

TravelPlace _place({
  required int id,
  required String mode,
  required int oneWayMinutes,
  required int oneWayCostYen,
  required int stay,
  int niche = 3,
}) {
  return TravelPlace(
    id: id,
    timeBudgetMinutes: 30,
    timeBand: '30分以内',
    name: 'Place $id',
    municipality: '盛岡市',
    transport: TravelTransport(
      mode: mode,
      oneWayMinutes: oneWayMinutes,
      oneWayCostYen: oneWayCostYen,
      routeSummary: 'test',
      costNote: '片道運賃',
    ),
    recommendedStayMinutes: stay,
    nicheLevel: niche,
    coordinates: const TravelCoordinates(
      latitude: 39.7,
      longitude: 141.1,
      accuracy: '概略代表点',
    ),
    recommendation: 'おすすめ',
    seasonNote: null,
    estimateConfidence: 'high',
  );
}

void main() {
  test('filterPlaces respects time cost and modes', () {
    final places = [
      _place(id: 1, mode: '徒歩', oneWayMinutes: 10, oneWayCostYen: 0, stay: 30),
      _place(id: 2, mode: '車', oneWayMinutes: 20, oneWayCostYen: 0, stay: 30),
      _place(id: 3, mode: '未知', oneWayMinutes: 5, oneWayCostYen: 0, stay: 10),
    ];
    final condition = ImmediateTripSearchCondition(
      availableMinutes: 120,
      maxRoundTripCostYen: 0,
      availableModes: {TravelMode.walking},
    );
    final filtered = filterPlaces(places, condition);
    expect(filtered.map((p) => p.id), [1]);
  });

  test('filterPlaces excludes trips that are too short', () {
    // required = 10*2 + 30 + 20 = 70. With 180 available, min is 90.
    final shortPlace = _place(
      id: 1,
      mode: '徒歩',
      oneWayMinutes: 10,
      oneWayCostYen: 0,
      stay: 30,
    );
    // required = 40*2 + 60 + 20 = 160. Fits 180 and >= 90.
    final fitPlace = _place(
      id: 2,
      mode: '徒歩',
      oneWayMinutes: 40,
      oneWayCostYen: 0,
      stay: 60,
    );
    final condition = ImmediateTripSearchCondition(
      availableMinutes: 180,
      maxRoundTripCostYen: 0,
      availableModes: {TravelMode.walking},
    );
    final filtered = filterPlaces([shortPlace, fitPlace], condition);
    expect(filtered.map((p) => p.id), [2]);
  });

  test('createTripPlan includes buffer and photo mission', () {
    final place = _place(
      id: 1,
      mode: '徒歩',
      oneWayMinutes: 10,
      oneWayCostYen: 0,
      stay: 30,
    );
    final departure = DateTime(2026, 7, 12, 12, 0);
    final plan = createTripPlan(place, departure, photoMission: '固定お題');
    expect(plan.arrivalAt, DateTime(2026, 7, 12, 12, 10));
    expect(plan.leavePlaceAt, DateTime(2026, 7, 12, 12, 40));
    expect(plan.returnAt, DateTime(2026, 7, 12, 12, 50));
    expect(plan.returnWithBufferAt, DateTime(2026, 7, 12, 13, 10));
    expect(plan.photoMission, '固定お題');
  });

  test('iwate score maps to niche targets', () {
    expect(targetNicheLevelFromIwateScore(0), 1.5);
    expect(targetNicheLevelFromIwateScore(40), 2.5);
    expect(targetNicheLevelFromIwateScore(70), 3.5);
    expect(targetNicheLevelFromIwateScore(90), 4.5);
  });

  test('shuffleIwateQuizQuestions keeps choices and correct answer', () {
    final question = iwateQuizQuestions.first;
    final shuffled = shuffleIwateQuizQuestions(
      [question],
      random: Random(0),
    ).single;

    expect(shuffled.shuffledChoices.toSet(), question.choices.toSet());
    expect(
      shuffled.shuffledChoices[shuffled.shuffledCorrectIndex],
      question.choices[question.correctIndex],
    );
  });

  test('shuffleIwateQuizQuestions randomizes choice order', () {
    final shuffled = shuffleIwateQuizQuestions(
      iwateQuizQuestions,
      random: Random(0),
    );
    final originalOrder = iwateQuizQuestions
        .map((question) => question.choices)
        .toList();
    final shuffledOrder = shuffled
        .map((item) => item.shuffledChoices)
        .toList();

    expect(shuffledOrder, isNot(equals(originalOrder)));
  });

  test('findConditionSuggestions proposes shorter time when base has no matches', () {
    final shortPlace = _place(
      id: 1,
      mode: '徒歩',
      oneWayMinutes: 10,
      oneWayCostYen: 0,
      stay: 40,
    );
    final base = ImmediateTripSearchCondition(
      availableMinutes: 180,
      maxRoundTripCostYen: 0,
      availableModes: {TravelMode.walking},
    );
    expect(filterPlaces([shortPlace], base), isEmpty);

    final suggestions = findConditionSuggestions([shortPlace], base);
    expect(suggestions, isNotEmpty);
    expect(
      suggestions.first.message,
      contains('2時間30分'),
    );
    expect(
      filterPlaces([shortPlace], suggestions.first.condition),
      isNotEmpty,
    );
  });

  test('findConditionSuggestions proposes higher budget when cost blocks matches', () {
    final costlyPlace = _place(
      id: 1,
      mode: '徒歩',
      oneWayMinutes: 10,
      oneWayCostYen: 600,
      stay: 30,
    );
    final base = ImmediateTripSearchCondition(
      availableMinutes: 120,
      maxRoundTripCostYen: 1000,
      availableModes: {TravelMode.walking},
    );
    expect(filterPlaces([costlyPlace], base), isEmpty);

    final suggestions = findConditionSuggestions([costlyPlace], base);
    expect(
      suggestions.any((s) => s.message.contains('2,000円') || s.message.contains('2000円')),
      isTrue,
    );
  });
}
