import 'dart:math';

import '../models/daily_post.dart';
import '../models/topic.dart';

enum RecapKind { daily, travel }

enum RecapEndingBody { earth, moon }

const dailyRecapEndingMessages = [
  '日常であれば、発見がたくさんできたね',
  'ふとした一コマが、今日を形づくってるね',
  'いつもと違う視点で、今日を見られたね',
  '小さな瞬間に、いいものが写ってたね',
];

const travelRecapEndingMessages = [
  '旅の記憶が、ひとつ増えたね',
  '歩いた分だけ、景色が残ってるね',
  'この旅は、きっと忘れないね',
  'また新しい場所へ、出かけられるね',
];

RecapKind recapKindFor({
  required List<DailyPost> posts,
  bool hasTravelHeader = false,
}) {
  if (hasTravelHeader ||
      posts.any((post) => post.mode == TopicMode.travel)) {
    return RecapKind.travel;
  }
  return RecapKind.daily;
}

String pickRecapEndingMessage(
  RecapKind kind, {
  Random? random,
}) {
  final messages =
      kind == RecapKind.daily
          ? dailyRecapEndingMessages
          : travelRecapEndingMessages;
  return messages[(random ?? Random()).nextInt(messages.length)];
}

RecapEndingBody pickRecapEndingBody({Random? random}) {
  final rng = random ?? Random();
  return rng.nextInt(5) == 0 ? RecapEndingBody.moon : RecapEndingBody.earth;
}
