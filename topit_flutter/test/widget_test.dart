import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topit_flutter/models/daily_post.dart';
import 'package:topit_flutter/models/topic.dart';
import 'package:topit_flutter/repositories/post_repository.dart';
import 'package:topit_flutter/screens/home_screen.dart';
import 'package:topit_flutter/screens/post_screen.dart';
import 'package:topit_flutter/services/topic_service.dart';
import 'package:topit_flutter/services/travel_session_store.dart';
import 'package:topit_flutter/services/travel_trip_history_store.dart';
import 'package:topit_flutter/models/travel_trip_record.dart';
import 'package:topit_flutter/models/travel_place.dart';
import 'package:topit_flutter/services/travel_places_repository.dart';
import 'package:topit_flutter/services/iwate_score_store.dart';
import 'package:topit_flutter/screens/immediate_trip_search_page.dart';

Widget _testApp() {
  return MaterialApp(
    home: HomeScreen(
      topicService: FixedTopicService(),
      postRepository: InMemoryPostRepository(),
      travelSessionStore: InMemoryTravelSessionStore(),
      travelTripHistoryStore: InMemoryTravelTripHistoryStore(),
    ),
  );
}

class SequenceTopicService implements TopicService {
  SequenceTopicService(this.topics);

  final List<Topic> topics;
  int _index = 0;

  @override
  Future<Topic> fetchTopic({
    required TopicMode mode,
    String? excludeTopicId,
  }) async {
    final topic = topics[_index.clamp(0, topics.length - 1)];
    _index += 1;
    return topic;
  }
}

Widget _homeWithPosts(List<DailyPost> posts) {
  return MaterialApp(
    home: HomeScreen(
      topicService: FixedTopicService(),
      postRepository: InMemoryPostRepository(initialPosts: posts),
      travelSessionStore: InMemoryTravelSessionStore(),
      travelTripHistoryStore: InMemoryTravelTripHistoryStore(),
    ),
  );
}

Future<void> _scrollToPost(WidgetTester tester, String postId) async {
  await tester.scrollUntilVisible(
    find.byKey(ValueKey(postId)),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

void main() {
  testWidgets('ホーム画面に日常のお題と空の写真カードを表示する', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    expect(find.text('Topit'), findsOneWidget);
    expect(find.text('トピット'), findsNothing);
    expect(find.text('日常'), findsOneWidget);
    expect(find.text('旅行'), findsOneWidget);
    expect(find.text('今日のお題'), findsOneWidget);
    expect(find.text('撮影する'), findsOneWidget);
    expect(find.text('別のお題を見る'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '撮影する'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '別のお題を見る'), findsOneWidget);
    expect(find.text('まだ写真はありません'), findsOneWidget);
    expect(find.text('気が向いたら今日のひとコマを残してみよう'), findsOneWidget);
    expect(find.byTooltip('写真を撮る'), findsOneWidget);

    final captureLeft = tester.getTopLeft(
      find.widgetWithText(FilledButton, '撮影する'),
    );
    final refreshLeft = tester.getTopLeft(
      find.widgetWithText(OutlinedButton, '別のお題を見る'),
    );
    expect(captureLeft.dx, lessThan(refreshLeft.dx));
  });

  testWidgets('カメラボタンから画像ソースを選べる', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('写真を撮る'));
    await tester.pumpAndSettle();

    expect(find.text('写真・動画を追加'), findsOneWidget);
    expect(find.text('写真を撮影'), findsOneWidget);
    expect(find.text('動画を撮影（5秒）'), findsOneWidget);
    expect(find.text('写真ライブラリから選ぶ'), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_outlined), findsWidgets);
    expect(find.byIcon(Icons.photo_library_outlined), findsOneWidget);
  });

  testWidgets('お題カードの撮影ボタンはお題を変更せず既存の画像ソース選択を開く', (tester) async {
    const firstTopic = Topic(id: 'first', text: '最初のお題');
    const secondTopic = Topic(id: 'second', text: '次のお題');

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          topicService: SequenceTopicService([firstTopic, secondTopic]),
          postRepository: InMemoryPostRepository(),
          travelSessionStore: InMemoryTravelSessionStore(),
          travelTripHistoryStore: InMemoryTravelTripHistoryStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(firstTopic.text), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '撮影する'));
    await tester.pumpAndSettle();

    expect(find.text('写真・動画を追加'), findsOneWidget);
    expect(find.text(firstTopic.text), findsOneWidget);
    expect(find.text(secondTopic.text), findsNothing);
  });

  testWidgets('別のお題を見るボタンだけがお題を変更する', (tester) async {
    const firstTopic = Topic(id: 'first', text: '最初のお題');
    const secondTopic = Topic(id: 'second', text: '次のお題');

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          topicService: SequenceTopicService([firstTopic, secondTopic]),
          postRepository: InMemoryPostRepository(),
          travelSessionStore: InMemoryTravelSessionStore(),
          travelTripHistoryStore: InMemoryTravelTripHistoryStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, '別のお題を見る'));
    await tester.pumpAndSettle();

    expect(find.text(firstTopic.text), findsNothing);
    expect(find.text(secondTopic.text), findsOneWidget);
  });

  testWidgets('旅行モードの今から出発エリアに盛岡駅発の地域性を表示する', (tester) async {
    await tester.pumpWidget(_testApp());
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getCenter(find.text('旅行')));
    await tester.pumpAndSettle();

    expect(find.text('岩手・盛岡駅発'), findsOneWidget);
    expect(find.text('盛岡駅から岩手をめぐる'), findsOneWidget);
    expect(find.textContaining('盛岡駅'), findsWidgets);
    expect(find.widgetWithText(FilledButton, '今から出発'), findsOneWidget);
    expect(find.byIcon(Icons.landscape_rounded), findsOneWidget);
    expect(find.text('自然'), findsNothing);
    expect(find.text('グルメ'), findsNothing);
    expect(find.text('歴史'), findsNothing);
  });

  testWidgets('今から出発で条件を探す画面が直接開く', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ImmediateTripSearchPage(
          repository: _ImmediateTestPlacesRepository(),
          iwateScoreStore: InMemoryIwateScoreStore(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('条件を探す'), findsOneWidget);
    expect(find.text('旅を探す'), findsOneWidget);
    expect(find.text('🐻 岩手度を測定して探す'), findsOneWidget);
    expect(find.text('探し方を選ぶ'), findsNothing);
    expect(find.text('2時間'), findsOneWidget);
  });

  testWidgets('保存済み岩手度があると利用して探すを表示する', (tester) async {
    final store = InMemoryIwateScoreStore();
    await store.save(
      SavedIwateScore(
        score: 75,
        targetNicheLevel: 3.5,
        measuredAt: DateTime(2026, 7, 12),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ImmediateTripSearchPage(
          repository: _ImmediateTestPlacesRepository(),
          iwateScoreStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('🐻 岩手度を利用して探す'), findsOneWidget);
    expect(find.text('岩手度 75点（前回の測定）'), findsOneWidget);
    expect(find.text('🐻 岩手度を測定して探す'), findsNothing);
    expect(find.text('長押しで岩手度を再測定'), findsOneWidget);
  });

  testWidgets('保存済み岩手度があると長押しでクイズを開始できる', (tester) async {
    final store = InMemoryIwateScoreStore();
    await store.save(
      SavedIwateScore(
        score: 75,
        targetNicheLevel: 3.5,
        measuredAt: DateTime(2026, 7, 12),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ImmediateTripSearchPage(
          repository: _ImmediateTestPlacesRepository(),
          iwateScoreStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.longPress(find.text('🐻 岩手度を利用して探す'));
    await tester.pumpAndSettle();

    expect(find.text('岩手度クイズ'), findsOneWidget);
    expect(find.text('1 / 8'), findsOneWidget);
  });

  testWidgets('コメント入力画面で投稿データを返す', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final tempFile = File('${Directory.systemTemp.path}/topit-test-image.jpg');
    tempFile.writeAsBytesSync(<int>[0]);

    const topic = '今日見つけた、少し気になるもの';

    await tester.pumpWidget(
      MaterialApp(
        home: PostScreen(
          mediaPath: tempFile.path,
          mediaType: PostMediaType.image,
          topic: topic,
          createdAt: DateTime(2026, 7, 11, 15),
          mode: TopicMode.daily,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('写真を投稿'), findsOneWidget);
    expect(find.text(topic), findsOneWidget);
    expect(find.text('コメント'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '帰り道で見つけた');
    await tester.tap(find.text('投稿する'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('モード切替で表示するタイムラインが変わる', (tester) async {
    final historyStore = InMemoryTravelTripHistoryStore();
    await historyStore.add(
      TravelTripRecord(
        id: 'trip-widget-test',
        itinerary: missingItineraryLabel,
        startedAt: DateTime.utc(2026, 7, 11, 8),
        endedAt: DateTime.utc(2026, 7, 11, 9),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          topicService: FixedTopicService(),
          postRepository: InMemoryPostRepository(
            initialPosts: [
              DailyPost(
                id: 'post-daily',
                mediaPath: 'media/post-daily.jpg',
                mediaType: PostMediaType.image,
                topic: '日常のお題テスト',
                createdAt: DateTime.utc(2026, 7, 11, 8),
                comment: '',
                mode: TopicMode.daily,
              ),
              DailyPost(
                id: 'post-travel',
                mediaPath: 'media/post-travel.jpg',
                mediaType: PostMediaType.image,
                topic: '旅行のお題テスト',
                createdAt: DateTime.utc(2026, 7, 11, 9),
                comment: '',
                mode: TopicMode.travel,
                tripId: 'trip-widget-test',
              ),
            ],
          ),
          travelSessionStore: InMemoryTravelSessionStore(),
          travelTripHistoryStore: historyStore,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('日常のお題テスト'), findsOneWidget);
    expect(find.text('旅行のお題テスト'), findsNothing);

    await tester.tapAt(tester.getCenter(find.text('旅行')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('旅のお題を作る'), findsWidgets);
    expect(find.text('日常のお題テスト'), findsNothing);
    await tester.scrollUntilVisible(
      find.text(missingItineraryLabel),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text(missingItineraryLabel), findsOneWidget);

    await tester.tap(find.text(missingItineraryLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('旅行のお題テスト'), findsOneWidget);
  });

  testWidgets('通知起動時の初期モードとして世界を選択できる', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          initialMode: TopicMode.world,
          topicService: FixedTopicService(),
          postRepository: InMemoryPostRepository(),
          travelSessionStore: InMemoryTravelSessionStore(),
          travelTripHistoryStore: InMemoryTravelTripHistoryStore(),
          worldModeBuilder: () => const SizedBox(),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is SegmentedButton<TopicMode> &&
            widget.selected.contains(TopicMode.world),
      ),
      findsOneWidget,
    );
  });

  testWidgets('投稿メニューから編集と削除を選べる', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _homeWithPosts([
        DailyPost(
          id: 'post-daily',
          mediaPath: 'media/post-daily.jpg',
          mediaType: PostMediaType.image,
          topic: '日常のお題テスト',
          createdAt: DateTime.utc(2026, 7, 11, 8),
          comment: 'テストコメント',
          mode: TopicMode.daily,
        ),
      ]),
    );
    await tester.pump();
    await tester.pump();

    await _scrollToPost(tester, 'post-daily');
    await tester.tap(find.byKey(const ValueKey('post-menu-post-daily')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('編集'), findsOneWidget);
    expect(find.text('削除'), findsOneWidget);
  });

  testWidgets('編集画面でコメントを更新できる', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final tempFile = File(
      '${Directory.systemTemp.path}/topit-edit-test-${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    tempFile.writeAsBytesSync(<int>[1, 2, 3]);
    addTearDown(() {
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
      }
    });

    final repository = InMemoryPostRepository(
      initialPosts: [
        DailyPost(
          id: 'post-daily',
          mediaPath: tempFile.path,
          mediaType: PostMediaType.image,
          topic: '日常のお題テスト',
          createdAt: DateTime.utc(2026, 7, 11, 8),
          comment: '元のコメント',
          mode: TopicMode.daily,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          topicService: FixedTopicService(),
          postRepository: repository,
          travelSessionStore: InMemoryTravelSessionStore(),
          travelTripHistoryStore: InMemoryTravelTripHistoryStore(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await _scrollToPost(tester, 'post-daily');
    await tester.tap(find.byKey(const ValueKey('post-menu-post-daily')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('編集'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('投稿を開けませんでした'), findsNothing);
    expect(find.text('投稿を編集'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '更新後のコメント');
    await tester.tap(find.widgetWithText(FilledButton, '保存する'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('元のコメント'), findsNothing);
    expect(find.text('投稿を更新しました'), findsOneWidget);

    final posts = await repository.loadPosts();
    expect(posts.single.comment, '更新後のコメント');
  });

  testWidgets('メニューから投稿を削除できる', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repository = InMemoryPostRepository(
      initialPosts: [
        DailyPost(
          id: 'post-daily',
          mediaPath: 'media/post-daily.jpg',
          mediaType: PostMediaType.image,
          topic: '日常のお題テスト',
          createdAt: DateTime.utc(2026, 7, 11, 8),
          comment: '',
          mode: TopicMode.daily,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          topicService: FixedTopicService(),
          postRepository: repository,
          travelSessionStore: InMemoryTravelSessionStore(),
          travelTripHistoryStore: InMemoryTravelTripHistoryStore(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await _scrollToPost(tester, 'post-daily');
    await tester.tap(find.byKey(const ValueKey('post-menu-post-daily')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('削除'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('この投稿を削除しますか？この操作は取り消せません。'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '削除').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('日常のお題テスト'), findsNothing);
    expect(find.text('まだ写真はありません'), findsOneWidget);
    expect(find.text('投稿を削除しました'), findsOneWidget);
    expect((await repository.loadPosts()), isEmpty);
  });
}

class _ImmediateTestPlacesRepository extends TravelPlacesRepository {
  @override
  Future<TravelPlacesLoadResult> load() async {
    return TravelPlacesLoadResult.success([
      TravelPlace(
        id: 1,
        timeBudgetMinutes: 30,
        timeBand: '30分以内',
        name: 'テストスポット',
        municipality: '盛岡市',
        transport: const TravelTransport(
          mode: '徒歩',
          oneWayMinutes: 10,
          oneWayCostYen: 0,
          routeSummary: 'test',
          costNote: '片道運賃',
        ),
        recommendedStayMinutes: 40,
        nicheLevel: 3,
        coordinates: const TravelCoordinates(
          latitude: 39.7,
          longitude: 141.1,
          accuracy: '概略代表点',
        ),
        recommendation: 'テスト用',
        seasonNote: null,
        estimateConfidence: 'high',
      ),
    ]);
  }
}
