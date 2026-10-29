import '../models/world_challenge.dart';
import '../models/world_post.dart';

class WorldFeatureDisabledException implements Exception {
  const WorldFeatureDisabledException();
}

class WorldPostPage {
  const WorldPostPage({required this.items, this.nextCursor});

  final List<WorldPost> items;
  final int? nextCursor;
}

/// Local UI data only. No posts, uploads, likes, or network requests are made.
class WorldUiDataService {
  Future<WorldChallenge> fetchChallenge() async {
    final now = DateTime.now().toUtc();
    final startsAt = DateTime.utc(now.year, now.month, now.day);
    final expiresAt = startsAt.add(const Duration(days: 1));
    return WorldChallenge(
      id: startsAt.toIso8601String().substring(0, 10),
      prompt: '今日見つけた丸いものを撮ろう',
      startsAt: startsAt,
      expiresAt: expiresAt,
      serverTime: now,
    );
  }

  Future<WorldPostPage> fetchPosts({int? cursor, int limit = 30}) async {
    return const WorldPostPage(items: []);
  }

  Future<int> likePost(String postId) async {
    throw const WorldFeatureDisabledException();
  }
}
