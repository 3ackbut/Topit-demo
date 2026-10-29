class TravelTripRecord {
  const TravelTripRecord({
    required this.id,
    required this.itinerary,
    required this.startedAt,
    required this.endedAt,
  });

  final String id;
  final String itinerary;
  final DateTime startedAt;
  final DateTime endedAt;

  TravelTripRecord copyWith({
    String? itinerary,
    DateTime? startedAt,
    DateTime? endedAt,
  }) => TravelTripRecord(
    id: id,
    itinerary: itinerary ?? this.itinerary,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'itinerary': itinerary,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'endedAt': endedAt.toUtc().toIso8601String(),
  };

  factory TravelTripRecord.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! String ||
        json['itinerary'] is! String ||
        json['startedAt'] is! String ||
        json['endedAt'] is! String) {
      throw const FormatException('Invalid travel trip record');
    }

    return TravelTripRecord(
      id: json['id'] as String,
      itinerary: json['itinerary'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String).toUtc(),
      endedAt: DateTime.parse(json['endedAt'] as String).toUtc(),
    );
  }
}
