import 'dart:math';

import '../data/common_travel_photo_missions.dart';
import '../models/immediate_trip.dart';
import '../models/iwate_quiz_question.dart';
import '../models/travel_place.dart';

class ShuffledIwateQuizQuestion {
  const ShuffledIwateQuizQuestion({
    required this.question,
    required this.shuffledChoices,
    required this.shuffledCorrectIndex,
  });

  final IwateQuizQuestion question;
  final List<String> shuffledChoices;
  final int shuffledCorrectIndex;
}

List<ShuffledIwateQuizQuestion> shuffleIwateQuizQuestions(
  List<IwateQuizQuestion> questions, {
  Random? random,
}) {
  final rng = random ?? Random();
  return [
    for (final question in questions)
      () {
        final indices = List<int>.generate(
          question.choices.length,
          (index) => index,
        )..shuffle(rng);
        return ShuffledIwateQuizQuestion(
          question: question,
          shuffledChoices: [
            for (final index in indices) question.choices[index],
          ],
          shuffledCorrectIndex: indices.indexOf(question.correctIndex),
        );
      }(),
  ];
}

String formatMinutes(int minutes) {
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;

  if (hours == 0) {
    return '$remainingMinutes分';
  }

  if (remainingMinutes == 0) {
    return '$hours時間';
  }

  return '$hours時間$remainingMinutes分';
}

int calculateRequiredMinutes(TravelPlace place) {
  const bufferMinutes = 20;

  return place.transport.oneWayMinutes * 2 +
      place.recommendedStayMinutes +
      bufferMinutes;
}

int calculateRoundTripCost(TravelPlace place) {
  return place.transport.oneWayCostYen * 2;
}

/// Ideal usage is ~80% of available time. Shorter than half is treated as
/// too brief for a recommendation.
const minTimeUsageRatio = 0.5;

int minimumRequiredMinutes(int availableMinutes) {
  return (availableMinutes * minTimeUsageRatio).ceil();
}

bool fitsAvailableTime({
  required int requiredMinutes,
  required int availableMinutes,
}) {
  if (availableMinutes <= 0) {
    return false;
  }
  return requiredMinutes <= availableMinutes &&
      requiredMinutes >= minimumRequiredMinutes(availableMinutes);
}

List<TravelPlace> filterPlaces(
  List<TravelPlace> places,
  ImmediateTripSearchCondition condition,
) {
  return places.where((place) {
    final mode = travelModeFromJson(place.transport.mode);

    if (mode == null) {
      return false;
    }

    final requiredMinutes = calculateRequiredMinutes(place);
    final roundTripCost = calculateRoundTripCost(place);

    return fitsAvailableTime(
          requiredMinutes: requiredMinutes,
          availableMinutes: condition.availableMinutes,
        ) &&
        roundTripCost <= condition.maxRoundTripCostYen &&
        condition.availableModes.contains(mode);
  }).toList();
}

double calculateTimeFit({
  required int requiredMinutes,
  required int availableMinutes,
}) {
  if (availableMinutes <= 0) {
    return 0;
  }

  final ratio = requiredMinutes / availableMinutes;
  const idealRatio = 0.8;

  final score = 1.0 - ((ratio - idealRatio).abs() / idealRatio);
  return score.clamp(0.0, 1.0);
}

double confidenceScore(String confidence) {
  switch (confidence) {
    case 'high':
      return 1.0;
    case 'medium':
      return 0.7;
    default:
      return 0.4;
  }
}

double calculateStandardScore(
  TravelPlace place,
  ImmediateTripSearchCondition condition,
  double randomValue,
) {
  final timeFit = calculateTimeFit(
    requiredMinutes: calculateRequiredMinutes(place),
    availableMinutes: condition.availableMinutes,
  );

  final confidence = confidenceScore(place.estimateConfidence);

  return timeFit * 0.65 + confidence * 0.20 + randomValue * 0.15;
}

double calculateIwateScore({
  required int correctAnswers,
  required int totalQuestions,
}) {
  if (totalQuestions <= 0) {
    return 0;
  }

  return correctAnswers / totalQuestions * 100;
}

double targetNicheLevelFromIwateScore(double score) {
  if (score < 25) {
    return 1.5;
  }

  if (score < 50) {
    return 2.5;
  }

  if (score < 75) {
    return 3.5;
  }

  return 4.5;
}

double calculateNicheMatch({
  required int placeNicheLevel,
  required double targetNicheLevel,
}) {
  final distance = (placeNicheLevel - targetNicheLevel).abs();
  return (1.0 - distance / 4.0).clamp(0.0, 1.0);
}

double calculateIwateQuizScore(
  TravelPlace place,
  ImmediateTripSearchCondition condition,
  double randomValue,
) {
  final targetNiche = condition.targetNicheLevel ?? 2.5;

  final nicheMatch = calculateNicheMatch(
    placeNicheLevel: place.nicheLevel,
    targetNicheLevel: targetNiche,
  );

  final timeFit = calculateTimeFit(
    requiredMinutes: calculateRequiredMinutes(place),
    availableMinutes: condition.availableMinutes,
  );

  final confidence = confidenceScore(place.estimateConfidence);

  return nicheMatch * 0.45 +
      timeFit * 0.30 +
      confidence * 0.10 +
      randomValue * 0.15;
}

Map<int, double> generateSearchRandomValues(
  List<TravelPlace> places, [
  Random? random,
]) {
  final rng = random ?? Random();
  return {for (final place in places) place.id: rng.nextDouble()};
}

List<TravelPlace> rankPlaces({
  required List<TravelPlace> filtered,
  required ImmediateTripSearchCondition condition,
  required ImmediateTripSearchType searchType,
  required Map<int, double> randomValues,
  int limit = 5,
}) {
  final scored =
      filtered.map((place) {
          final randomValue = randomValues[place.id] ?? 0.0;
          final score =
              searchType == ImmediateTripSearchType.iwateQuiz
                  ? calculateIwateQuizScore(place, condition, randomValue)
                  : calculateStandardScore(place, condition, randomValue);
          return (place: place, score: score);
        }).toList()
        ..sort((a, b) => b.score.compareTo(a.score));

  return scored.take(limit).map((entry) => entry.place).toList();
}

/// Excess cost for near-miss ranking: lower is closer to matching.
double placeConditionExcess(
  TravelPlace place,
  ImmediateTripSearchCondition condition,
) {
  final mode = travelModeFromJson(place.transport.mode);
  if (mode == null) {
    return double.infinity;
  }

  final requiredMinutes = calculateRequiredMinutes(place);
  final roundTripCost = calculateRoundTripCost(place);
  final minRequired = minimumRequiredMinutes(condition.availableMinutes);

  final timeOverExcess =
      requiredMinutes > condition.availableMinutes
          ? (requiredMinutes - condition.availableMinutes).toDouble()
          : 0.0;
  final timeUnderExcess =
      requiredMinutes < minRequired
          ? (minRequired - requiredMinutes).toDouble()
          : 0.0;
  final costExcess =
      roundTripCost > condition.maxRoundTripCostYen
          ? (roundTripCost - condition.maxRoundTripCostYen).toDouble()
          : 0.0;
  final modeExcess = condition.availableModes.contains(mode) ? 0.0 : 1000.0;

  // Already matching places are not near-misses.
  if (timeOverExcess == 0 &&
      timeUnderExcess == 0 &&
      costExcess == 0 &&
      modeExcess == 0) {
    return double.infinity;
  }

  return timeOverExcess + timeUnderExcess + costExcess / 10.0 + modeExcess;
}

List<TravelPlace> findNearMissPlaces(
  List<TravelPlace> places,
  ImmediateTripSearchCondition condition, {
  int limit = 3,
}) {
  final ranked =
      places
          .map(
            (place) => (
              place: place,
              excess: placeConditionExcess(place, condition),
            ),
          )
          .where((entry) => entry.excess.isFinite)
          .toList()
        ..sort((a, b) => a.excess.compareTo(b.excess));

  return ranked.take(limit).map((entry) => entry.place).toList();
}

ImmediateTripPlan createTripPlan(
  TravelPlace place,
  DateTime departureAt, {
  String? photoMission,
  Random? random,
}) {
  final arrivalAt = departureAt.add(
    Duration(minutes: place.transport.oneWayMinutes),
  );

  final leavePlaceAt = arrivalAt.add(
    Duration(minutes: place.recommendedStayMinutes),
  );

  final returnAt = leavePlaceAt.add(
    Duration(minutes: place.transport.oneWayMinutes),
  );

  final returnWithBufferAt = returnAt.add(const Duration(minutes: 20));

  final mission =
      photoMission ??
      commonTravelPhotoMissions[(random ?? Random()).nextInt(
        commonTravelPhotoMissions.length,
      )];

  return ImmediateTripPlan(
    place: place,
    departureAt: departureAt,
    arrivalAt: arrivalAt,
    leavePlaceAt: leavePlaceAt,
    returnAt: returnAt,
    returnWithBufferAt: returnWithBufferAt,
    photoMission: mission,
  );
}

String? zeroCostCaution(TravelPlace place) {
  if (place.transport.oneWayCostYen != 0) {
    return null;
  }
  final mode = travelModeFromJson(place.transport.mode);
  switch (mode) {
    case TravelMode.car:
      return 'ガソリン代、駐車料金、車両調達費は含まれません';
    case TravelMode.bicycle:
      return '自転車の調達・レンタル料金は含まれません';
    default:
      return place.transport.costNote.isNotEmpty
          ? place.transport.costNote
          : null;
  }
}

int? nextCostOption(int current) {
  for (final option in costOptions) {
    if (option > current) {
      return option;
    }
  }
  return null;
}

TravelMode? suggestAdditionalMode(Set<TravelMode> current) {
  for (final mode in TravelMode.values) {
    if (!current.contains(mode)) {
      return mode;
    }
  }
  return null;
}

class ConditionSuggestion {
  const ConditionSuggestion({
    required this.message,
    required this.condition,
    required this.matchCount,
  });

  final String message;
  final ImmediateTripSearchCondition condition;
  final int matchCount;
}

double _conditionChangeDistance(
  ImmediateTripSearchCondition base,
  ImmediateTripSearchCondition candidate,
) {
  final timeDelta =
      (candidate.availableMinutes - base.availableMinutes).abs().toDouble();
  final costDelta =
      (candidate.maxRoundTripCostYen - base.maxRoundTripCostYen).abs() / 100.0;
  final modeDelta =
      (candidate.availableModes.difference(base.availableModes).length * 50)
          .toDouble();
  return timeDelta + costDelta + modeDelta;
}

String _buildSuggestionMessage({
  required ImmediateTripSearchCondition base,
  required ImmediateTripSearchCondition candidate,
  required int matchCount,
}) {
  if (candidate.availableMinutes != base.availableMinutes &&
      candidate.maxRoundTripCostYen == base.maxRoundTripCostYen &&
      candidate.availableModes.length == base.availableModes.length) {
    return 'この時間（${formatMinutes(candidate.availableMinutes)}）なら$matchCount件見つかります';
  }

  if (candidate.maxRoundTripCostYen != base.maxRoundTripCostYen &&
      candidate.availableMinutes == base.availableMinutes &&
      candidate.availableModes.length == base.availableModes.length) {
    final costLabel =
        candidate.maxRoundTripCostYen == 0
            ? '0円'
            : '${candidate.maxRoundTripCostYen}円';
    return '予算を$costLabelに増やすと$matchCount件見つかります';
  }

  if (candidate.availableModes.length > base.availableModes.length) {
    final addedMode = candidate.availableModes.difference(base.availableModes);
    final modeLabel =
        addedMode.isEmpty ? '移動手段' : travelModeLabel(addedMode.first);
    return '「$modeLabel」を追加すると$matchCount件見つかります';
  }

  return '条件を変えると$matchCount件見つかります';
}

List<ConditionSuggestion> findConditionSuggestions(
  List<TravelPlace> places,
  ImmediateTripSearchCondition base, {
  int limit = 4,
}) {
  final candidates = <ImmediateTripSearchCondition>[];

  final shortenedTime = (base.availableMinutes - 30).clamp(30, 480);
  if (shortenedTime != base.availableMinutes) {
    candidates.add(base.copyWith(availableMinutes: shortenedTime));
  }

  final lengthenedTime = (base.availableMinutes + 30).clamp(30, 480);
  if (lengthenedTime != base.availableMinutes) {
    candidates.add(base.copyWith(availableMinutes: lengthenedTime));
  }

  final nextCost = nextCostOption(base.maxRoundTripCostYen);
  if (nextCost != null) {
    candidates.add(base.copyWith(maxRoundTripCostYen: nextCost));
  }

  final extraMode = suggestAdditionalMode(base.availableModes);
  if (extraMode != null) {
    candidates.add(
      base.copyWith(availableModes: {...base.availableModes, extraMode}),
    );
  }

  final suggestions = <ConditionSuggestion>[];
  final seen = <String>{};

  for (final candidate in candidates) {
    final key =
        '${candidate.availableMinutes}|'
        '${candidate.maxRoundTripCostYen}|'
        '${candidate.availableModes.map(travelModeLabel).join(',')}';
    if (seen.contains(key)) continue;
    seen.add(key);

    final matchCount = filterPlaces(places, candidate).length;
    if (matchCount == 0) continue;

    suggestions.add(
      ConditionSuggestion(
        message: _buildSuggestionMessage(
          base: base,
          candidate: candidate,
          matchCount: matchCount,
        ),
        condition: candidate,
        matchCount: matchCount,
      ),
    );
  }

  suggestions.sort(
    (a, b) => _conditionChangeDistance(base, a.condition).compareTo(
      _conditionChangeDistance(base, b.condition),
    ),
  );

  return suggestions.take(limit).toList();
}
