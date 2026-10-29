import 'topic.dart';

enum PostMediaType { image, video }

extension PostMediaTypeJson on PostMediaType {
  String toJsonValue() => name;

  static PostMediaType fromJsonValue(String value) {
    return switch (value) {
      'image' => PostMediaType.image,
      'video' => PostMediaType.video,
      _ => throw FormatException('Unknown media type: $value'),
    };
  }
}

class DailyPost {
  const DailyPost({
    required this.id,
    required this.mediaPath,
    required this.mediaType,
    required this.topic,
    required this.createdAt,
    required this.comment,
    required this.mode,
    this.tripId,
    this.missionTitle,
  });

  final String id;
  final String mediaPath;
  final PostMediaType mediaType;
  final String topic;
  final DateTime createdAt;
  final String comment;
  final TopicMode mode;
  final String? tripId;
  final String? missionTitle;

  DailyPost copyWith({
    String? id,
    String? mediaPath,
    PostMediaType? mediaType,
    String? topic,
    DateTime? createdAt,
    String? comment,
    TopicMode? mode,
    String? tripId,
    String? missionTitle,
  }) {
    return DailyPost(
      id: id ?? this.id,
      mediaPath: mediaPath ?? this.mediaPath,
      mediaType: mediaType ?? this.mediaType,
      topic: topic ?? this.topic,
      createdAt: createdAt ?? this.createdAt,
      comment: comment ?? this.comment,
      mode: mode ?? this.mode,
      tripId: tripId ?? this.tripId,
      missionTitle: missionTitle ?? this.missionTitle,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mediaPath': mediaPath,
      'mediaType': mediaType.toJsonValue(),
      'topic': topic,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'comment': comment,
      'mode': mode.toJsonValue(),
      if (tripId != null) 'tripId': tripId,
      if (missionTitle != null) 'missionTitle': missionTitle,
    };
  }

  factory DailyPost.fromJson(Map<String, dynamic> json) {
    final createdAtRaw = json['createdAt'];
    if (createdAtRaw is! String) {
      throw FormatException('DailyPost.createdAt must be a String');
    }

    return DailyPost(
      id: json['id'] as String,
      mediaPath: json['mediaPath'] as String,
      mediaType: PostMediaTypeJson.fromJsonValue(json['mediaType'] as String),
      topic: json['topic'] as String,
      createdAt: DateTime.parse(createdAtRaw).toUtc(),
      comment: json['comment'] as String,
      mode:
          json['mode'] != null
              ? TopicModeJson.fromJsonValue(json['mode'] as String)
              : TopicMode.daily,
      tripId: json['tripId'] as String?,
      missionTitle: json['missionTitle'] as String?,
    );
  }
}
