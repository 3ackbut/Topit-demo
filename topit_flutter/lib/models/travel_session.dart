import 'mission.dart';

class TravelSession {
  const TravelSession({
    required this.id,
    required this.itinerary,
    required this.startedAt,
    required this.missions,
    required this.currentMissionIndex,
    this.completedMissionIndexes = const [],
    this.previousTitles = const [],
  });

  final String id;
  final String itinerary;
  final DateTime startedAt;
  final List<Mission> missions;
  final int currentMissionIndex;
  final List<int> completedMissionIndexes;
  final List<String> previousTitles;

  TravelSession copyWith({
    List<Mission>? missions,
    int? currentMissionIndex,
    List<int>? completedMissionIndexes,
    List<String>? previousTitles,
  }) => TravelSession(
    id: id,
    itinerary: itinerary,
    startedAt: startedAt,
    missions: missions ?? this.missions,
    currentMissionIndex: currentMissionIndex ?? this.currentMissionIndex,
    completedMissionIndexes:
        completedMissionIndexes ?? this.completedMissionIndexes,
    previousTitles: previousTitles ?? this.previousTitles,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'itinerary': itinerary,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'currentMissionIndex': currentMissionIndex,
    'missions': missions.map((mission) => mission.toJson()).toList(),
    'completedMissionIndexes': completedMissionIndexes,
    'previousTitles': previousTitles,
  };

  factory TravelSession.fromJson(Map<String, dynamic> json) {
    final missionsRaw = json['missions'];
    if (json['id'] is! String ||
        json['itinerary'] is! String ||
        json['startedAt'] is! String ||
        json['currentMissionIndex'] is! int ||
        missionsRaw is! List) {
      throw const FormatException('Invalid travel session');
    }
    final missions =
        missionsRaw
            .map(
              (item) =>
                  Mission.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .toList();
    final currentIndex = json['currentMissionIndex'] as int;
    if (missions.length != 3 ||
        currentIndex < 0 ||
        currentIndex >= missions.length) {
      throw const FormatException('Invalid travel session missions');
    }
    final completed =
        (json['completedMissionIndexes'] as List? ?? const [])
            .whereType<int>()
            .where((index) => index >= 0 && index < missions.length)
            .toSet()
            .toList()
          ..sort();
    final previousTitles =
        (json['previousTitles'] as List? ?? const [])
            .whereType<String>()
            .where((title) => title.trim().isNotEmpty)
            .map((title) => title.trim())
            .toList();
    return TravelSession(
      id: json['id'] as String,
      itinerary: json['itinerary'] as String,
      startedAt: DateTime.parse(json['startedAt'] as String).toUtc(),
      missions: missions,
      currentMissionIndex: currentIndex,
      completedMissionIndexes: completed,
      previousTitles: previousTitles,
    );
  }
}
