class Mission {
  const Mission({
    required this.title,
    required this.hint,
    required this.shootingTip,
    required this.difficulty,
    required this.estimatedMinutes,
  });

  final String title;
  final String hint;
  final String shootingTip;
  final int difficulty;
  final int estimatedMinutes;

  factory Mission.fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    final hint = json['hint'];
    final shootingTip = json['shooting_tip'];
    final difficulty = json['difficulty'];
    final estimatedMinutes = json['estimated_minutes'];
    if (title is! String ||
        title.trim().isEmpty ||
        hint is! String ||
        hint.trim().isEmpty ||
        shootingTip is! String ||
        shootingTip.trim().isEmpty ||
        difficulty is! int ||
        difficulty < 1 ||
        difficulty > 3 ||
        estimatedMinutes is! int ||
        !const {5, 10, 15}.contains(estimatedMinutes)) {
      throw const FormatException('Invalid travel mission');
    }
    return Mission(
      title: title.trim(),
      hint: hint.trim(),
      shootingTip: shootingTip.trim(),
      difficulty: difficulty,
      estimatedMinutes: estimatedMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'hint': hint,
    'shooting_tip': shootingTip,
    'difficulty': difficulty,
    'estimated_minutes': estimatedMinutes,
  };
}
