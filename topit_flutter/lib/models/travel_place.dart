class TravelCoordinates {
  final double latitude;
  final double longitude;
  final String accuracy;

  const TravelCoordinates({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });

  factory TravelCoordinates.fromJson(Map<String, dynamic> json) {
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    final accuracy = json['accuracy'];
    if (latitude is! num || longitude is! num || accuracy is! String) {
      throw const FormatException('Invalid travel coordinates');
    }
    return TravelCoordinates(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      accuracy: accuracy,
    );
  }
}

class TravelTransport {
  final String mode;
  final int oneWayMinutes;
  final int oneWayCostYen;
  final String routeSummary;
  final String costNote;

  const TravelTransport({
    required this.mode,
    required this.oneWayMinutes,
    required this.oneWayCostYen,
    required this.routeSummary,
    required this.costNote,
  });

  factory TravelTransport.fromJson(Map<String, dynamic> json) {
    final mode = json['mode'];
    final oneWayMinutes = json['one_way_minutes'];
    final oneWayCostYen = json['one_way_cost_yen'];
    final routeSummary = json['route_summary'];
    final costNote = json['cost_note'];
    if (mode is! String ||
        oneWayMinutes is! int ||
        oneWayCostYen is! int ||
        routeSummary is! String ||
        costNote is! String) {
      throw const FormatException('Invalid travel transport');
    }
    return TravelTransport(
      mode: mode,
      oneWayMinutes: oneWayMinutes,
      oneWayCostYen: oneWayCostYen,
      routeSummary: routeSummary,
      costNote: costNote,
    );
  }
}

class TravelPlace {
  final int id;
  final int timeBudgetMinutes;
  final String timeBand;
  final String name;
  final String municipality;
  final TravelTransport transport;
  final int recommendedStayMinutes;
  final int nicheLevel;
  final TravelCoordinates coordinates;
  final String recommendation;
  final String? seasonNote;
  final String estimateConfidence;

  const TravelPlace({
    required this.id,
    required this.timeBudgetMinutes,
    required this.timeBand,
    required this.name,
    required this.municipality,
    required this.transport,
    required this.recommendedStayMinutes,
    required this.nicheLevel,
    required this.coordinates,
    required this.recommendation,
    required this.seasonNote,
    required this.estimateConfidence,
  });

  factory TravelPlace.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final timeBudgetMinutes = json['time_budget_minutes'];
    final timeBand = json['time_band'];
    final name = json['name'];
    final municipality = json['municipality'];
    final transportRaw = json['transport'];
    final recommendedStayMinutes = json['recommended_stay_minutes'];
    final nicheLevel = json['niche_level'];
    final coordinatesRaw = json['coordinates'];
    final recommendation = json['recommendation'];
    final seasonNote = json['season_note'];
    final estimateConfidence = json['estimate_confidence'];

    if (id is! int ||
        timeBudgetMinutes is! int ||
        timeBand is! String ||
        name is! String ||
        municipality is! String ||
        transportRaw is! Map ||
        recommendedStayMinutes is! int ||
        nicheLevel is! int ||
        coordinatesRaw is! Map ||
        recommendation is! String ||
        estimateConfidence is! String ||
        (seasonNote != null && seasonNote is! String)) {
      throw const FormatException('Invalid travel place');
    }

    return TravelPlace(
      id: id,
      timeBudgetMinutes: timeBudgetMinutes,
      timeBand: timeBand,
      name: name,
      municipality: municipality,
      transport: TravelTransport.fromJson(
        Map<String, dynamic>.from(transportRaw),
      ),
      recommendedStayMinutes: recommendedStayMinutes,
      nicheLevel: nicheLevel,
      coordinates: TravelCoordinates.fromJson(
        Map<String, dynamic>.from(coordinatesRaw),
      ),
      recommendation: recommendation,
      seasonNote: seasonNote as String?,
      estimateConfidence: estimateConfidence,
    );
  }
}
