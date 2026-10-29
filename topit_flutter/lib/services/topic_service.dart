import 'dart:math';

import '../data/daily_topics.dart';
import '../models/topic.dart';

abstract class TopicService {
  Future<Topic> fetchTopic({required TopicMode mode, String? excludeTopicId});
}

class FixedTopicService implements TopicService {
  FixedTopicService({Random? random}) : _random = random ?? Random();

  final Random _random;

  @override
  Future<Topic> fetchTopic({
    required TopicMode mode,
    String? excludeTopicId,
  }) async {
    return switch (mode) {
      TopicMode.daily => _pickDailyTopic(excludeTopicId),
      TopicMode.travel => throw UnsupportedError('旅行モードのお題生成は未実装です'),
      TopicMode.world => throw UnsupportedError('世界モードは専用データを使用します'),
    };
  }

  Topic _pickDailyTopic(String? excludeTopicId) {
    final candidates =
        dailyTopics.length > 1 && excludeTopicId != null
            ? dailyTopics.where((topic) => topic.id != excludeTopicId).toList()
            : dailyTopics;

    return candidates[_random.nextInt(candidates.length)];
  }
}
