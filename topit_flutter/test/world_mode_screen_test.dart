import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:topit_flutter/models/world_challenge.dart';
import 'package:topit_flutter/models/world_post.dart';
import 'package:topit_flutter/screens/world_mode_screen.dart';
import 'package:topit_flutter/services/world_ui_data_service.dart';
import 'package:topit_flutter/services/world_local_state.dart';

class _FakeWorldUiDataService extends WorldUiDataService {
  _FakeWorldUiDataService({this.initialLikeCount = 0});

  final int initialLikeCount;
  int likeCallCount = 0;
  int fetchChallengeCallCount = 0;
  int fetchPostsCallCount = 0;
  int currentLikeCount = 0;

  @override
  Future<WorldChallenge> fetchChallenge() async {
    fetchChallengeCallCount += 1;
    return WorldChallenge(
      id: '2026-07-11',
      prompt: '今日見つけた丸いものを撮ろう',
      startsAt: DateTime.utc(2026, 7, 11),
      expiresAt: DateTime.utc(2026, 7, 12),
      serverTime: DateTime.utc(2026, 7, 11, 12),
    );
  }

  @override
  Future<WorldPostPage> fetchPosts({int? cursor, int limit = 30}) async {
    fetchPostsCallCount += 1;
    currentLikeCount = initialLikeCount;
    return WorldPostPage(
      items: [
        WorldPost(
          id: 'post-1',
          imageUrl: 'https://example.com/post-1',
          createdAt: DateTime.utc(2026, 7, 11, 12),
          width: 1200,
          height: 1600,
          likeCount: initialLikeCount,
        ),
      ],
    );
  }

  @override
  Future<int> likePost(String postId) async {
    likeCallCount += 1;
    currentLikeCount += 1;
    return currentLikeCount;
  }
}

class _FakeWorldLocalState implements WorldAnswerState {
  _FakeWorldLocalState({Set<String>? likedPostIds})
    : _likedPostIds = {...?likedPostIds};

  final Set<String> _likedPostIds;

  @override
  Future<String?> answeredChallengeId() async => null;

  @override
  Future<String> clientId() async => 'client-1';

  @override
  Future<void> markAnswered(String challengeId) async {}

  @override
  Future<Set<String>> likedPostIds() async => _likedPostIds;

  @override
  Future<void> markLiked(String postId) async {
    _likedPostIds.add(postId);
  }
}

Future<void> _pumpWorldModeScreen(
  WidgetTester tester, {
  required WorldUiDataService dataService,
  required WorldAnswerState localState,
  Size viewportSize = const Size(800, 600),
}) async {
  tester.view.physicalSize = viewportSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView(
          children: [
            WorldModeScreen(
              dataService: dataService,
              localState: localState,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _doubleTap(WidgetTester tester, Finder finder) async {
  final center = tester.getCenter(finder);
  final firstTap = await tester.startGesture(center);
  await firstTap.up();
  await tester.pump(kDoubleTapMinTime);
  final secondTap = await tester.startGesture(center);
  await secondTap.up();
}

void main() {
  testWidgets('世界モードにお題、残り時間、投稿グリッドを表示する', (tester) async {
    await _pumpWorldModeScreen(
      tester,
      dataService: _FakeWorldUiDataService(),
      localState: _FakeWorldLocalState(),
    );

    expect(find.text('今日のお題'), findsOneWidget);
    expect(find.text('今日見つけた丸いものを撮ろう'), findsOneWidget);
    expect(find.textContaining('次のお題まで'), findsOneWidget);
    expect(find.text('投稿機能は停止中です'), findsOneWidget);
    expect(find.text('世界の回答'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('いいね数を右下に表示する', (tester) async {
    await _pumpWorldModeScreen(
      tester,
      dataService: _FakeWorldUiDataService(initialLikeCount: 3),
      localState: _FakeWorldLocalState(),
    );

    expect(find.text('3'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });

  testWidgets('画像ダブルタップでいいねを送信しカウントを増やす', (tester) async {
    final dataService = _FakeWorldUiDataService(initialLikeCount: 2);
    await _pumpWorldModeScreen(
      tester,
      dataService: dataService,
      localState: _FakeWorldLocalState(),
      viewportSize: const Size(800, 1400),
    );

    await _doubleTap(tester, find.byKey(const ValueKey('world-post-image-post-1')));
    await tester.pumpAndSettle();

    expect(dataService.likeCallCount, 1);
    expect(find.text('3'), findsOneWidget);
    expect(find.byIcon(Icons.favorite), findsOneWidget);
  });

  testWidgets('いいね済み投稿は再ダブルタップしてもAPIを呼ばない', (tester) async {
    final dataService = _FakeWorldUiDataService(initialLikeCount: 4);
    await _pumpWorldModeScreen(
      tester,
      dataService: dataService,
      localState: _FakeWorldLocalState(likedPostIds: {'post-1'}),
      viewportSize: const Size(800, 1400),
    );

    expect(find.byIcon(Icons.favorite), findsOneWidget);
    expect(find.text('4'), findsOneWidget);

    await _doubleTap(tester, find.byKey(const ValueKey('world-post-image-post-1')));
    await tester.pumpAndSettle();

    expect(dataService.likeCallCount, 0);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('下向きに引っ張るとデータを再取得する', (tester) async {
    final dataService = _FakeWorldUiDataService();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RefreshIndicator(
            onRefresh: () async {
              final state = tester.state<WorldModeScreenState>(
                find.byType(WorldModeScreen),
              );
              await state.refresh();
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                WorldModeScreen(
                  dataService: dataService,
                  localState: _FakeWorldLocalState(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(dataService.fetchChallengeCallCount, 1);
    expect(dataService.fetchPostsCallCount, 1);

    await tester.fling(find.byType(Scrollable), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(dataService.fetchChallengeCallCount, 2);
    expect(dataService.fetchPostsCallCount, 2);
  });
}
