import 'package:flutter_test/flutter_test.dart';

import 'package:topit_flutter/services/iwate_score_store.dart';

void main() {
  test('SavedIwateScore serializes to json', () {
    final saved = SavedIwateScore(
      score: 75,
      targetNicheLevel: 3.5,
      measuredAt: DateTime(2026, 7, 12, 10, 30),
    );

    final restored = SavedIwateScore.fromJson(saved.toJson());
    expect(restored.score, 75);
    expect(restored.targetNicheLevel, 3.5);
    expect(restored.measuredAt, DateTime(2026, 7, 12, 10, 30));
  });

  test('InMemoryIwateScoreStore saves loads and clears score', () async {
    final store = InMemoryIwateScoreStore();
    expect(await store.load(), isNull);

    await store.save(
      SavedIwateScore(
        score: 62.5,
        targetNicheLevel: 3.5,
        measuredAt: DateTime(2026, 7, 12),
      ),
    );

    final loaded = await store.load();
    expect(loaded?.score, 62.5);
    expect(loaded?.targetNicheLevel, 3.5);

    await store.clear();
    expect(await store.load(), isNull);
  });
}
