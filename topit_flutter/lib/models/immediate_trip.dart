import 'travel_place.dart';

enum ImmediateTripSearchType { standard, iwateQuiz }

enum TravelMode { walking, bicycle, publicTransit, car }

TravelMode? travelModeFromJson(String value) {
  switch (value) {
    case '徒歩':
      return TravelMode.walking;
    case '自転車':
      return TravelMode.bicycle;
    case '公共交通機関/徒歩':
      return TravelMode.publicTransit;
    case '車':
      return TravelMode.car;
    default:
      return null;
  }
}

String travelModeLabel(TravelMode mode) {
  switch (mode) {
    case TravelMode.walking:
      return '徒歩';
    case TravelMode.bicycle:
      return '自転車';
    case TravelMode.publicTransit:
      return '公共交通';
    case TravelMode.car:
      return '車';
  }
}

class ImmediateTripSearchCondition {
  final int availableMinutes;
  final int maxRoundTripCostYen;
  final Set<TravelMode> availableModes;
  final double? targetNicheLevel;

  const ImmediateTripSearchCondition({
    required this.availableMinutes,
    required this.maxRoundTripCostYen,
    required this.availableModes,
    this.targetNicheLevel,
  });

  ImmediateTripSearchCondition copyWith({
    int? availableMinutes,
    int? maxRoundTripCostYen,
    Set<TravelMode>? availableModes,
    double? targetNicheLevel,
  }) => ImmediateTripSearchCondition(
    availableMinutes: availableMinutes ?? this.availableMinutes,
    maxRoundTripCostYen: maxRoundTripCostYen ?? this.maxRoundTripCostYen,
    availableModes: availableModes ?? this.availableModes,
    targetNicheLevel: targetNicheLevel ?? this.targetNicheLevel,
  );
}

class ImmediateTripPlan {
  final TravelPlace place;
  final DateTime departureAt;
  final DateTime arrivalAt;
  final DateTime leavePlaceAt;
  final DateTime returnAt;
  final DateTime returnWithBufferAt;
  final String photoMission;

  const ImmediateTripPlan({
    required this.place,
    required this.departureAt,
    required this.arrivalAt,
    required this.leavePlaceAt,
    required this.returnAt,
    required this.returnWithBufferAt,
    required this.photoMission,
  });
}

const costOptions = <int>[0, 500, 1000, 2000, 3000, 5000];
