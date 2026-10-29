import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topit_flutter/models/daily_post.dart';
import 'package:topit_flutter/models/mission.dart';
import 'package:topit_flutter/models/topic.dart';
import 'package:topit_flutter/models/travel_session.dart';
import 'package:topit_flutter/models/travel_trip_record.dart';
import 'package:topit_flutter/repositories/post_repository.dart';
import 'package:topit_flutter/screens/daily_recap_screen.dart';
import 'package:topit_flutter/screens/home_screen.dart';
import 'package:topit_flutter/screens/travel_trip_detail_screen.dart';
import 'package:topit_flutter/services/daily_recap_service.dart';
import 'package:topit_flutter/services/media_storage.dart';
import 'package:topit_flutter/services/recap_ending_messages.dart';
import 'package:topit_flutter/services/topic_service.dart';
import 'package:topit_flutter/services/travel_session_store.dart';
import 'package:topit_flutter/services/travel_trip_history_store.dart';
import 'package:topit_flutter/widgets/recap_ending_earth.dart';

void main() {
  DailyPost post({
    required String id,
    required DateTime createdAt,
    TopicMode mode = TopicMode.daily,
    String? tripId,
    String topic = 'お題',
  }) {
    return DailyPost(
      id: id,
      mediaPath: 'media/$id.jpg',
      mediaType: PostMediaType.image,
      topic: topic,
      createdAt: createdAt,
      comment: '',
      mode: mode,
      tripId: tripId,
    );
  }

  Widget homeWith({
    List<DailyPost> posts = const [],
    TravelSessionStore? travelSessionStore,
    TravelTripHistoryStore? travelTripHistoryStore,
    DateTime Function()? nowProvider,
  }) {
    return MaterialApp(
      home: HomeScreen(
        topicService: FixedTopicService(),
        postRepository: InMemoryPostRepository(initialPosts: posts),
        travelSessionStore: travelSessionStore ?? InMemoryTravelSessionStore(),
        travelTripHistoryStore:
            travelTripHistoryStore ?? InMemoryTravelTripHistoryStore(),
        nowProvider: nowProvider ?? (() => DateTime(2026, 7, 12, 18)),
      ),
    );
  }

  test('tripRecapPosts は tripId と travel モードでフィルタして古い順に並べる', () {
    final result = tripRecapPosts([
      post(
        id: 'new',
        createdAt: DateTime(2026, 7, 12, 18),
        mode: TopicMode.travel,
        tripId: 'trip-1',
      ),
      post(
        id: 'other-trip',
        createdAt: DateTime(2026, 7, 12, 9),
        mode: TopicMode.travel,
        tripId: 'trip-2',
      ),
      post(
        id: 'old',
        createdAt: DateTime(2026, 7, 12, 7),
        mode: TopicMode.travel,
        tripId: 'trip-1',
      ),
      post(id: 'daily', createdAt: DateTime(2026, 7, 12, 6)),
    ], 'trip-1');

    expect(result.map((item) => item.id), ['old', 'new']);
  });

  test('synthesizeTripRecordsFromPosts は tripId ごとに記録を作る', () {
    final records = synthesizeTripRecordsFromPosts([
      post(
        id: 'a',
        createdAt: DateTime(2026, 7, 10, 8),
        mode: TopicMode.travel,
        tripId: 'trip-a',
      ),
      post(
        id: 'b',
        createdAt: DateTime(2026, 7, 10, 20),
        mode: TopicMode.travel,
        tripId: 'trip-a',
      ),
    ]);

    expect(records, hasLength(1));
    expect(records.first.id, 'trip-a');
    expect(records.first.itinerary, missingItineraryLabel);
    expect(records.first.startedAt, DateTime(2026, 7, 10, 8));
    expect(records.first.endedAt, DateTime(2026, 7, 10, 20));
  });

  test('InMemoryTravelTripHistoryStore.delete は指定 ID の記録のみ削除する', () async {
    final store = InMemoryTravelTripHistoryStore();
    await store.add(
      TravelTripRecord(
        id: 'trip-a',
        itinerary: '東京',
        startedAt: DateTime(2026, 7, 10, 8),
        endedAt: DateTime(2026, 7, 10, 20),
      ),
    );
    await store.add(
      TravelTripRecord(
        id: 'trip-b',
        itinerary: '鎌倉',
        startedAt: DateTime(2026, 7, 12, 8),
        endedAt: DateTime(2026, 7, 12, 20),
      ),
    );

    await store.delete('trip-a');

    final records = await store.loadAll();
    expect(records.map((record) => record.id), ['trip-b']);
  });

  testWidgets('旅行終了で写真ありの振り返り画面が開く', (tester) async {
    final sessionStore = InMemoryTravelSessionStore();
    final historyStore = InMemoryTravelTripHistoryStore();
    final session = TravelSession(
      id: 'trip-active',
      itinerary: '盛岡〜平泉',
      startedAt: DateTime(2026, 7, 12, 9),
      missions: const [
        Mission(
          title: '駅舎',
          hint: 'hint',
          shootingTip: 'tip',
          difficulty: 1,
          estimatedMinutes: 5,
        ),
        Mission(
          title: '橋',
          hint: 'hint',
          shootingTip: 'tip',
          difficulty: 1,
          estimatedMinutes: 5,
        ),
        Mission(
          title: '市場',
          hint: 'hint',
          shootingTip: 'tip',
          difficulty: 1,
          estimatedMinutes: 5,
        ),
      ],
      currentMissionIndex: 0,
    );
    await sessionStore.save(session);

    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      homeWith(
        posts: [
          post(
            id: 'travel-1',
            createdAt: DateTime(2026, 7, 12, 10),
            mode: TopicMode.travel,
            tripId: 'trip-active',
            topic: '旅の1枚目',
          ),
        ],
        travelSessionStore: sessionStore,
        travelTripHistoryStore: historyStore,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('旅行'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('旅行を終了'));
    await tester.tap(find.text('旅行を終了'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(DailyRecapScreen), findsOneWidget);
    expect(find.byTooltip('閉じる'), findsOneWidget);
    expect(find.text('旅の1枚目'), findsWidgets);
  });

  testWidgets('旅行終了・写真0枚では強制振り返りが表示される', (tester) async {
    final sessionStore = InMemoryTravelSessionStore();
    final historyStore = InMemoryTravelTripHistoryStore();
    final session = TravelSession(
      id: 'trip-empty',
      itinerary: '盛岡市内散策',
      startedAt: DateTime(2026, 7, 12, 9),
      missions: const [
        Mission(
          title: '駅舎',
          hint: 'hint',
          shootingTip: 'tip',
          difficulty: 1,
          estimatedMinutes: 5,
        ),
        Mission(
          title: '橋',
          hint: 'hint',
          shootingTip: 'tip',
          difficulty: 1,
          estimatedMinutes: 5,
        ),
        Mission(
          title: '市場',
          hint: 'hint',
          shootingTip: 'tip',
          difficulty: 1,
          estimatedMinutes: 5,
        ),
      ],
      currentMissionIndex: 0,
    );
    await sessionStore.save(session);

    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      homeWith(
        travelSessionStore: sessionStore,
        travelTripHistoryStore: historyStore,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('旅行'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('旅行を終了'));
    await tester.tap(find.text('旅行を終了'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(DailyRecapScreen), findsOneWidget);
    expect(find.byTooltip('閉じる'), findsNothing);
    expect(find.text('盛岡市内散策'), findsWidgets);
    expect(find.text('この旅では写真を撮っていません'), findsOneWidget);
    expect(find.text('盛岡市内散策'), findsWidgets);
  });

  testWidgets('旅一覧に完了した旅が表示され、詳細で振り返りを開ける', (
    tester,
  ) async {
    final historyStore = InMemoryTravelTripHistoryStore();
    await historyStore.add(
      TravelTripRecord(
        id: 'trip-history',
        itinerary: '東京〜鎌倉',
        startedAt: DateTime(2026, 7, 10, 8),
        endedAt: DateTime(2026, 7, 10, 20),
      ),
    );

    await tester.pumpWidget(
      homeWith(
        posts: [
          post(
            id: 'travel-history',
            createdAt: DateTime(2026, 7, 10, 12),
            mode: TopicMode.travel,
            tripId: 'trip-history',
            topic: '鎌倉の1枚目',
          ),
        ],
        travelTripHistoryStore: historyStore,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('旅行'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('東京〜鎌倉'),
      120,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('東京〜鎌倉'), findsOneWidget);
    expect(find.text('写真 1 枚'), findsOneWidget);

    await tester.tap(find.text('東京〜鎌倉'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(TravelTripDetailScreen), findsOneWidget);
    expect(find.text('鎌倉の1枚目'), findsOneWidget);

    await tester.tap(find.text('旅を振り返る'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(DailyRecapScreen), findsOneWidget);
    expect(find.text('鎌倉の1枚目'), findsWidgets);
  });

  testWidgets('終了済み旅の詳細から旅と写真を削除できる', (tester) async {
    final historyStore = InMemoryTravelTripHistoryStore();
    await historyStore.add(
      TravelTripRecord(
        id: 'trip-delete',
        itinerary: '京都散策',
        startedAt: DateTime(2026, 7, 8, 8),
        endedAt: DateTime(2026, 7, 8, 20),
      ),
    );

    await tester.pumpWidget(
      homeWith(
        posts: [
          post(
            id: 'travel-delete',
            createdAt: DateTime(2026, 7, 8, 12),
            mode: TopicMode.travel,
            tripId: 'trip-delete',
            topic: '京都の1枚目',
          ),
        ],
        travelTripHistoryStore: historyStore,
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('旅行'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.scrollUntilVisible(
      find.text('京都散策'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('京都散策'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byTooltip('旅を削除'), findsOneWidget);

    await tester.tap(find.byTooltip('旅を削除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.text('この旅と紐づく写真もすべて削除されます。この操作は取り消せません。'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, '削除').last);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('旅を削除しました'), findsOneWidget);
    expect(find.byType(TravelTripDetailScreen), findsNothing);
    expect(find.text('京都の1枚目'), findsNothing);
    expect(await historyStore.findById('trip-delete'), isNull);
  });

  testWidgets('進行中の旅の詳細には削除ボタンが表示されない', (tester) async {
    final sessionStore = InMemoryTravelSessionStore();
    await sessionStore.save(
      TravelSession(
        id: 'trip-active-delete',
        itinerary: '進行中削除テスト用の旅',
        startedAt: DateTime(2026, 7, 12, 9),
        missions: const [
          Mission(
            title: '駅舎',
            hint: 'hint',
            shootingTip: 'tip',
            difficulty: 1,
            estimatedMinutes: 5,
          ),
        ],
        currentMissionIndex: 0,
      ),
    );

    await tester.binding.setSurfaceSize(const Size(800, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      homeWith(
        travelSessionStore: sessionStore,
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('旅行'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.ensureVisible(find.text('進行中削除テスト用の旅').last);
    await tester.tap(find.text('進行中削除テスト用の旅').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(TravelTripDetailScreen), findsOneWidget);
    expect(find.byTooltip('旅を削除'), findsNothing);
  });

  Finder endingMessageFinder(List<String> messages) {
    return find.byWidgetPredicate(
      (widget) => widget is Text && messages.contains(widget.data),
    );
  }

  testWidgets('旅行振り返りの最後に旅行向けエンディングが表示される', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder:
                        (_) => DailyRecapScreen(
                          posts: [
                            post(
                              id: 'travel-ending',
                              createdAt: DateTime(2026, 7, 12, 21),
                              mode: TopicMode.travel,
                              tripId: 'trip-1',
                            ),
                          ],
                          mediaStorage: MediaStorage(
                            documentsDirectoryProvider:
                                () async => Directory.systemTemp,
                          ),
                        ),
                  ),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(endingMessageFinder(travelRecapEndingMessages), findsOneWidget);
    expect(find.byType(RecapEndingEarth), findsOneWidget);

    await tester.tap(endingMessageFinder(travelRecapEndingMessages));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('写真0枚の旅振り返りの後に旅行向けエンディングが表示される', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder:
                        (_) => DailyRecapScreen(
                          posts: const [],
                          forceView: true,
                          header: TravelRecapHeader(
                            itinerary: '盛岡市内散策',
                            startedAt: DateTime(2026, 7, 12, 9),
                            endedAt: DateTime(2026, 7, 12, 18),
                            showEmptyMessage: true,
                          ),
                        ),
                  ),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.pump(const Duration(seconds: 6));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(endingMessageFinder(travelRecapEndingMessages), findsOneWidget);
    expect(find.byType(RecapEndingEarth), findsOneWidget);
  });
}
