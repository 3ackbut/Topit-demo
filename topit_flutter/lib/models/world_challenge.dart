class WorldChallenge {
  const WorldChallenge({
    required this.id,
    required this.prompt,
    required this.startsAt,
    required this.expiresAt,
    required this.serverTime,
  });

  final String id;
  final String prompt;
  final DateTime startsAt;
  final DateTime expiresAt;
  final DateTime serverTime;

  factory WorldChallenge.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final prompt = json['prompt'];
    final startsAt = json['startsAt'];
    final expiresAt = json['expiresAt'];
    final serverTime = json['serverTime'];
    if (id is! String ||
        prompt is! String ||
        startsAt is! String ||
        expiresAt is! String ||
        serverTime is! String) {
      throw const FormatException('Invalid world challenge response');
    }

    return WorldChallenge(
      id: id,
      prompt: prompt,
      startsAt: DateTime.parse(startsAt).toUtc(),
      expiresAt: DateTime.parse(expiresAt).toUtc(),
      serverTime: DateTime.parse(serverTime).toUtc(),
    );
  }
}
