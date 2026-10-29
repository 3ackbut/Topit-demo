import '../models/daily_post.dart';
import '../models/topic.dart';

const dailyRecapPhotoDuration = Duration(seconds: 3);
const travelEmptyRecapDuration = Duration(seconds: 5);

bool isSameLocalDate(DateTime a, DateTime b) {
  final localA = a.toLocal();
  final localB = b.toLocal();
  return localA.year == localB.year &&
      localA.month == localB.month &&
      localA.day == localB.day;
}

List<DailyPost> todayDailyRecapPosts(
  List<DailyPost> posts, {
  required DateTime now,
}) {
  final todayPosts =
      posts
          .where(
            (post) =>
                post.mode == TopicMode.daily &&
                isSameLocalDate(post.createdAt, now),
          )
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  return todayPosts;
}

List<DailyPost> tripRecapPosts(List<DailyPost> posts, String tripId) {
  final tripPosts =
      posts
          .where(
            (post) => post.mode == TopicMode.travel && post.tripId == tripId,
          )
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  return tripPosts;
}

Duration recapDurationForPost(DailyPost post, {Duration? videoDuration}) {
  return switch (post.mediaType) {
    PostMediaType.image => dailyRecapPhotoDuration,
    PostMediaType.video => videoDuration ?? Duration.zero,
  };
}
