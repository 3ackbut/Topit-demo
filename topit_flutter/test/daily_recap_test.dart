import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topit_flutter/models/daily_post.dart';
import 'package:topit_flutter/models/topic.dart';
import 'package:topit_flutter/repositories/post_repository.dart';
import 'package:topit_flutter/screens/daily_recap_screen.dart';
import 'package:topit_flutter/screens/home_screen.dart';
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
    PostMediaType mediaType = PostMediaType.image,
  }) {
    return DailyPost(
      id: id,
      mediaPath: 'media/$id.jpg',
      mediaType: mediaType,
      topic: 'お題$id',
      createdAt: createdAt,
      comment: '',
      mode: mode,
    );
  }

  Widget homeWithPosts(List<DailyPost> posts) {
    return MaterialApp(
      home: HomeScreen(
        topicService: FixedTopicService(),
        postRepository: InMemoryPostRepository(initialPosts: posts),
        travelSessionStore: InMemoryTravelSessionStore(),
        travelTripHistoryStore: InMemoryTravelTripHistoryStore(),
        nowProvider: () => DateTime(2026, 7, 12, 12),
      ),
    );
  }

  testWidgets('今日の日常投稿が0件の場合、「今日を振り返る」は無効', (tester) async {
    await tester.pumpWidget(homeWithPosts(const []));
    await tester.pump();
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '今日を振り返る'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('今日の日常投稿が1件以上の場合、振り返り画面を開ける', (tester) async {
    await tester.pumpWidget(
      homeWithPosts([post(id: 'today', createdAt: DateTime(2026, 7, 12, 9))]),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('今日を振り返る'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byTooltip('閉じる'), findsOneWidget);
    expect(find.text('お題today'), findsWidgets);
  });

  test('旅行投稿と世界投稿は振り返り対象に含まれない', () {
    final result = todayDailyRecapPosts([
      post(id: 'daily', createdAt: DateTime(2026, 7, 12, 9)),
      post(
        id: 'travel',
        createdAt: DateTime(2026, 7, 12, 10),
        mode: TopicMode.travel,
      ),
      post(
        id: 'world',
        createdAt: DateTime(2026, 7, 12, 11),
        mode: TopicMode.world,
      ),
    ], now: DateTime(2026, 7, 12, 12));

    expect(result.map((post) => post.id), ['daily']);
  });

  test('昨日以前の日常投稿は振り返り対象に含まれない', () {
    final result = todayDailyRecapPosts([
      post(id: 'yesterday', createdAt: DateTime(2026, 7, 11, 23, 59)),
      post(id: 'today', createdAt: DateTime(2026, 7, 12)),
    ], now: DateTime(2026, 7, 12, 12));

    expect(result.map((post) => post.id), ['today']);
  });

  test('写真投稿の表示時間は3秒として扱う', () {
    expect(
      recapDurationForPost(post(id: 'image', createdAt: DateTime(2026, 7, 12))),
      const Duration(seconds: 3),
    );
  });

  test('複数投稿は古い順に並ぶ', () {
    final result = todayDailyRecapPosts([
      post(id: 'new', createdAt: DateTime(2026, 7, 12, 18)),
      post(id: 'old', createdAt: DateTime(2026, 7, 12, 7)),
      post(id: 'middle', createdAt: DateTime(2026, 7, 12, 12)),
    ], now: DateTime(2026, 7, 12, 20));

    expect(result.map((post) => post.id), ['old', 'middle', 'new']);
  });

  Finder endingMessageFinder(List<String> messages) {
    return find.byWidgetPredicate(
      (widget) => widget is Text && messages.contains(widget.data),
    );
  }

  test('recapKindFor は日常投稿のみなら daily を返す', () {
    expect(
      recapKindFor(
        posts: [post(id: 'daily', createdAt: DateTime(2026, 7, 12))],
      ),
      RecapKind.daily,
    );
  });

  test('pickRecapEndingBody は1/5の確率で moon を返す', () {
    expect(
      pickRecapEndingBody(random: _FakeRandom(0)),
      RecapEndingBody.moon,
    );
    expect(
      pickRecapEndingBody(random: _FakeRandom(1)),
      RecapEndingBody.earth,
    );
    expect(
      pickRecapEndingBody(random: _FakeRandom(4)),
      RecapEndingBody.earth,
    );
  });
  test('pickRecapEndingMessage はプールから文言を返す', () {
    expect(
      dailyRecapEndingMessages,
      contains(pickRecapEndingMessage(RecapKind.daily, random: Random(42))),
    );
    expect(
      travelRecapEndingMessages,
      contains(pickRecapEndingMessage(RecapKind.travel, random: Random(42))),
    );
  });

  testWidgets('最後まで進むとエンディング画面が表示され、タップで閉じる', (tester) async {
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
                              id: 'last',
                              createdAt: DateTime(2026, 7, 12, 21),
                            ),
                          ],
                          endingBody: RecapEndingBody.earth,
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
    expect(find.byTooltip('閉じる'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(endingMessageFinder(dailyRecapEndingMessages), findsOneWidget);
    expect(find.byType(RecapEndingEarth), findsOneWidget);
    expect(find.byTooltip('閉じる'), findsNothing);

    await tester.tap(endingMessageFinder(dailyRecapEndingMessages));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('open'), findsOneWidget);
    expect(find.byType(RecapEndingEarth), findsNothing);
  });

  testWidgets('エンディング画面で月を表示できる', (tester) async {
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
                              id: 'moon',
                              createdAt: DateTime(2026, 7, 12, 21),
                            ),
                          ],
                          endingBody: RecapEndingBody.moon,
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

    expect(find.byType(RecapEndingEarth), findsOneWidget);
    expect(find.text('Luna'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName.contains('moon'),
      ),
      findsWidgets,
    );
  });

  test('recapEndingWrappedSpin は 1 周で折り返す', () {
    expect(recapEndingWrappedSpin(0), 0);
    expect(recapEndingWrappedSpin(1), 0);
    expect(recapEndingWrappedSpin(1.5), closeTo(0.5, 0.0001));
    expect(recapEndingWrappedSpin(-0.25), closeTo(0.75, 0.0001));
  });

  testWidgets('RecapEndingEarth のドラッグで表示位置が変わる', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: _RecapEndingEarthTestHarness()),
    );
    await tester.pump();

    final initial = tester.widget<Positioned>(find.byType(Positioned).first);
    final initialLeft = initial.left ?? 0;

    await tester.drag(find.byType(RecapEndingEarth), const Offset(-100, 0));
    await tester.pump();

    final afterHorizontal = tester.widget<Positioned>(find.byType(Positioned).first);
    expect(afterHorizontal.left, isNot(equals(initialLeft)));
  });

  testWidgets('RecapEndingEarth は何周ドラッグしても地図が途切れない', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: _RecapEndingEarthTestHarness()),
    );
    await tester.pump();

    await tester.drag(
      find.byType(RecapEndingEarth),
      const Offset(-2000, 0),
    );
    await tester.pump();

    expect(find.byType(Image), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('RecapEndingEarth のフリック後に慣性で動き、減衰後に停止する', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: _RecapEndingEarthTestHarness()),
    );
    await tester.pump();

    await tester.fling(
      find.byType(RecapEndingEarth),
      const Offset(-400, 0),
      1200,
    );
    await tester.pump();

    final afterFling = tester.widget<Positioned>(find.byType(Positioned).first);
    final leftAfterFling = afterFling.left ?? 0;

    await tester.pump(const Duration(milliseconds: 120));
    final whileMoving = tester.widget<Positioned>(find.byType(Positioned).first);
    expect(whileMoving.left, isNot(equals(leftAfterFling)));

    await tester.pump(const Duration(seconds: 3));
    final stopped = tester.widget<Positioned>(find.byType(Positioned).first);
    final stoppedLeft = stopped.left ?? 0;

    await tester.pump(const Duration(milliseconds: 500));
    final stillStopped = tester.widget<Positioned>(find.byType(Positioned).first);
    expect(stillStopped.left, equals(stoppedLeft));
  });

  testWidgets('エンディング画面で地球儀をタップしても閉じない', (tester) async {
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
                              id: 'earth-tap',
                              createdAt: DateTime(2026, 7, 12, 21),
                            ),
                          ],
                          endingBody: RecapEndingBody.earth,
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

    expect(find.byType(RecapEndingEarth), findsOneWidget);

    final earthCenter = tester.getCenter(find.byType(RecapEndingEarth));
    await tester.tapAt(earthCenter + const Offset(0, 120));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(RecapEndingEarth), findsOneWidget);
    expect(find.text('open'), findsNothing);
  });
}

class _RecapEndingEarthTestHarness extends StatefulWidget {
  const _RecapEndingEarthTestHarness();

  @override
  State<_RecapEndingEarthTestHarness> createState() =>
      _RecapEndingEarthTestHarnessState();
}

class _RecapEndingEarthTestHarnessState extends State<_RecapEndingEarthTestHarness>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: recapEndingRotationDuration,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RecapEndingEarth(
        rotationController: _controller,
        size: 200,
      ),
    );
  }
}

class _FakeRandom extends Fake implements Random {
  _FakeRandom(this.value);

  final int value;

  @override
  int nextInt(int max) => value;
}
