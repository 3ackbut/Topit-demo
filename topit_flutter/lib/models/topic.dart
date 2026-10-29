enum TopicMode { daily, travel, world }

extension TopicModeJson on TopicMode {
  String toJsonValue() => name;

  static TopicMode fromJsonValue(String value) {
    return switch (value) {
      'daily' => TopicMode.daily,
      'travel' => TopicMode.travel,
      _ => throw FormatException('Unknown topic mode: $value'),
    };
  }
}

class Topic {
  const Topic({required this.id, required this.text, this.hint});

  final String id;
  final String text;
  final String? hint;
}
