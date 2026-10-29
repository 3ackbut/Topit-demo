class WorldPost {
  const WorldPost({
    required this.id,
    required this.imageUrl,
    required this.createdAt,
    this.width,
    this.height,
    this.comment = '',
    this.likeCount = 0,
  });

  final String id;
  final String imageUrl;
  final DateTime createdAt;
  final int? width;
  final int? height;
  final String comment;
  final int likeCount;

  WorldPost copyWith({
    String? id,
    String? imageUrl,
    DateTime? createdAt,
    int? width,
    int? height,
    String? comment,
    int? likeCount,
  }) {
    return WorldPost(
      id: id ?? this.id,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      width: width ?? this.width,
      height: height ?? this.height,
      comment: comment ?? this.comment,
      likeCount: likeCount ?? this.likeCount,
    );
  }

  factory WorldPost.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final imageUrl = json['imageUrl'];
    final createdAt = json['createdAt'];
    if (id is! String || imageUrl is! String || createdAt is! String) {
      throw const FormatException('Invalid world post response');
    }

    return WorldPost(
      id: id,
      imageUrl: imageUrl,
      createdAt: DateTime.parse(createdAt).toUtc(),
      width: json['width'] as int?,
      height: json['height'] as int?,
      comment: json['comment'] as String? ?? '',
      likeCount: json['likeCount'] as int? ?? 0,
    );
  }
}
