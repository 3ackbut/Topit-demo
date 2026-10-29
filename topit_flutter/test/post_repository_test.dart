import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:topit_flutter/models/daily_post.dart';
import 'package:topit_flutter/models/topic.dart';
import 'package:topit_flutter/repositories/post_repository.dart';
import 'package:topit_flutter/services/media_storage.dart';

void main() {
  group('DailyPost', () {
    test('JSON 往復変換で値が保持される', () {
      final post = DailyPost(
        id: 'post-1',
        mediaPath: '/tmp/post-1.jpg',
        mediaType: PostMediaType.image,
        topic: '今日の空',
        createdAt: DateTime.utc(2026, 7, 11, 6),
        comment: 'きれいだった',
        mode: TopicMode.daily,
      );

      final restored = DailyPost.fromJson(post.toJson());

      expect(restored.id, post.id);
      expect(restored.mediaPath, post.mediaPath);
      expect(restored.mediaType, post.mediaType);
      expect(restored.topic, post.topic);
      expect(restored.createdAt, post.createdAt);
      expect(restored.comment, post.comment);
      expect(restored.mode, post.mode);
      expect(restored.tripId, isNull);
      expect(restored.missionTitle, isNull);
    });

    test('mode 付き JSON 往復変換で travel が保持される', () {
      final post = DailyPost(
        id: 'post-travel',
        mediaPath: 'media/post-travel.jpg',
        mediaType: PostMediaType.image,
        topic: '旅先の景色',
        createdAt: DateTime.utc(2026, 7, 11, 10),
        comment: '良い天気',
        mode: TopicMode.travel,
      );

      final restored = DailyPost.fromJson(post.toJson());

      expect(restored.mode, TopicMode.travel);
    });

    test('旅行投稿のメタデータを保存して復元する', () {
      final restored = DailyPost.fromJson(
        DailyPost(
          id: 'post-travel-metadata',
          mediaPath: 'media/post-travel.jpg',
          mediaType: PostMediaType.image,
          topic: '旅先の色',
          createdAt: DateTime.utc(2026, 7, 11, 10),
          comment: '',
          mode: TopicMode.travel,
          tripId: 'trip-1720700000000',
          missionTitle: '旅先の色',
        ).toJson(),
      );

      expect(restored.tripId, 'trip-1720700000000');
      expect(restored.missionTitle, '旅先の色');
    });

    test('mode がない JSON は daily として復元される', () {
      final restored = DailyPost.fromJson({
        'id': 'post-legacy',
        'mediaPath': 'media/post-legacy.jpg',
        'mediaType': 'image',
        'topic': '移行テスト',
        'createdAt': '2026-07-11T12:00:00.000Z',
        'comment': '',
      });

      expect(restored.mode, TopicMode.daily);
    });

    test('createdAt は UTC 保存後もローカル時刻を復元できる', () {
      final local = DateTime(2026, 7, 11, 21, 39, 32);
      final post = DailyPost(
        id: 'post-1',
        mediaPath: 'media/post-1.jpg',
        mediaType: PostMediaType.image,
        topic: '今日の空',
        createdAt: local.toUtc(),
        comment: 'きれいだった',
        mode: TopicMode.daily,
      );

      final restored = DailyPost.fromJson(post.toJson());

      expect(restored.createdAt.isUtc, isTrue);
      expect(restored.createdAt.toLocal().hour, 21);
      expect(restored.createdAt.toLocal().minute, 39);
    });
  });

  group('JsonFilePostRepository', () {
    late Directory tempDirectory;
    late JsonFilePostRepository repository;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp('topit-post-repo-');
      repository = JsonFilePostRepository(
        documentsDirectoryProvider: () async => tempDirectory,
      );
    });

    tearDown(() async {
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('投稿がない場合は空リストを返す', () async {
      final posts = await repository.loadPosts();
      expect(posts, isEmpty);
    });

    test('投稿を保存して読み込める', () async {
      final sourceFile = File(p.join(tempDirectory.path, 'source.jpg'));
      await sourceFile.writeAsBytes(<int>[1, 2, 3]);

      final post = DailyPost(
        id: 'post-123',
        mediaPath: sourceFile.path,
        mediaType: PostMediaType.image,
        topic: '季節を感じるもの',
        createdAt: DateTime.utc(2026, 7, 11, 8),
        comment: '木漏れ日',
        mode: TopicMode.daily,
      );

      final savedPost = await repository.addPost(post);
      final loadedPosts = await repository.loadPosts();

      expect(loadedPosts, hasLength(1));
      expect(savedPost.mediaPath, 'media/post-123.jpg');
      expect(
        File(
          p.join(
            tempDirectory.path,
            MediaStorage.storageRootName,
            savedPost.mediaPath,
          ),
        ).existsSync(),
        isTrue,
      );
      expect(loadedPosts.first.mediaPath, 'media/post-123.jpg');
      expect(loadedPosts.first.id, post.id);
      expect(loadedPosts.first.topic, post.topic);
      expect(loadedPosts.first.comment, post.comment);
      expect(loadedPosts.first.mode, TopicMode.daily);
    });

    test('投稿は createdAt の降順で返す', () async {
      Future<DailyPost> addPostWithSource(String id, DateTime createdAt) async {
        final sourceFile = File(p.join(tempDirectory.path, '$id.jpg'));
        await sourceFile.writeAsBytes(<int>[1, 2, 3]);

        return repository.addPost(
          DailyPost(
            id: id,
            mediaPath: sourceFile.path,
            mediaType: PostMediaType.image,
            topic: 'テスト',
            createdAt: createdAt,
            comment: '',
            mode: TopicMode.daily,
          ),
        );
      }

      await addPostWithSource('post-old', DateTime.utc(2026, 7, 11, 8));
      await addPostWithSource('post-new', DateTime.utc(2026, 7, 11, 12));
      await addPostWithSource('post-mid', DateTime.utc(2026, 7, 11, 10));

      final loadedPosts = await repository.loadPosts();

      expect(loadedPosts, hasLength(3));
      expect(loadedPosts.map((post) => post.id).toList(), [
        'post-new',
        'post-mid',
        'post-old',
      ]);
    });

    test('複数の写真投稿は異なる id と mediaPath で別ファイルに保存する', () async {
      final sourceA = File(p.join(tempDirectory.path, 'source-a.jpg'));
      final sourceB = File(p.join(tempDirectory.path, 'source-b.jpg'));
      await sourceA.writeAsBytes(<int>[1, 1, 1]);
      await sourceB.writeAsBytes(<int>[2, 2, 2]);

      final savedA = await repository.addPost(
        DailyPost(
          id: 'post-photo-a',
          mediaPath: sourceA.path,
          mediaType: PostMediaType.image,
          topic: 'お題A',
          createdAt: DateTime.utc(2026, 7, 11, 8),
          comment: '写真A',
          mode: TopicMode.daily,
        ),
      );
      final savedB = await repository.addPost(
        DailyPost(
          id: 'post-photo-b',
          mediaPath: sourceB.path,
          mediaType: PostMediaType.image,
          topic: 'お題B',
          createdAt: DateTime.utc(2026, 7, 11, 9),
          comment: '写真B',
          mode: TopicMode.daily,
        ),
      );

      final loadedPosts = await repository.loadPosts();
      final savedFileA = File(
        p.join(
          tempDirectory.path,
          MediaStorage.storageRootName,
          savedA.mediaPath,
        ),
      );
      final savedFileB = File(
        p.join(
          tempDirectory.path,
          MediaStorage.storageRootName,
          savedB.mediaPath,
        ),
      );

      expect(savedA.id, isNot(savedB.id));
      expect(savedA.mediaPath, isNot(savedB.mediaPath));
      expect(savedFileA.readAsBytesSync(), <int>[1, 1, 1]);
      expect(savedFileB.readAsBytesSync(), <int>[2, 2, 2]);
      expect(loadedPosts.map((post) => post.id), [
        'post-photo-b',
        'post-photo-a',
      ]);
      expect(loadedPosts.map((post) => post.mediaPath), [
        savedB.mediaPath,
        savedA.mediaPath,
      ]);
    });

    test('posts.json には相対 mediaPath を保存する', () async {
      final sourceFile = File(p.join(tempDirectory.path, 'source.mp4'));
      await sourceFile.writeAsBytes(<int>[9, 8, 7]);

      await repository.addPost(
        DailyPost(
          id: 'post-video',
          mediaPath: sourceFile.path,
          mediaType: PostMediaType.video,
          topic: '動画テスト',
          createdAt: DateTime.utc(2026, 7, 11, 9),
          comment: '',
          mode: TopicMode.daily,
        ),
      );

      final postsFile = File(
        p.join(tempDirectory.path, MediaStorage.storageRootName, 'posts.json'),
      );
      final decoded = jsonDecode(await postsFile.readAsString());

      expect(decoded['version'], JsonFilePostRepository.schemaVersion);
      expect(decoded['posts'], hasLength(1));
      expect(decoded['posts'][0]['mediaType'], 'video');
      expect(decoded['posts'][0]['mediaPath'], 'media/post-video.mp4');
      expect(decoded['posts'][0]['mode'], 'daily');
    });

    test('絶対 mediaPath は読み込み時に相対パスへ移行する', () async {
      final storageDirectory = Directory(
        p.join(tempDirectory.path, MediaStorage.storageRootName),
      );
      final mediaDirectory = Directory(
        p.join(storageDirectory.path, MediaStorage.mediaDirectoryName),
      );
      await mediaDirectory.create(recursive: true);
      final mediaFile = File(p.join(mediaDirectory.path, 'post-legacy.jpg'));
      await mediaFile.writeAsBytes(<int>[1, 2, 3]);

      final postsFile = File(p.join(storageDirectory.path, 'posts.json'));
      await postsFile.writeAsString(
        jsonEncode({
          'version': 1,
          'posts': [
            {
              'id': 'post-legacy',
              'mediaPath': mediaFile.path,
              'mediaType': 'image',
              'topic': '移行テスト',
              'createdAt': '2026-07-11T12:00:00.000Z',
              'comment': '',
            },
          ],
        }),
      );

      final loadedPosts = await repository.loadPosts();
      final migrated = jsonDecode(await postsFile.readAsString());

      expect(loadedPosts, hasLength(1));
      expect(loadedPosts.first.mediaPath, 'media/post-legacy.jpg');
      expect(loadedPosts.first.mode, TopicMode.daily);
      expect(migrated['posts'][0]['mediaPath'], 'media/post-legacy.jpg');
      expect(migrated['posts'][0]['mode'], 'daily');
    });

    test('破損した posts.json は退避して空リストを返す', () async {
      final storageDirectory = Directory(
        p.join(tempDirectory.path, MediaStorage.storageRootName),
      );
      await storageDirectory.create(recursive: true);
      final postsFile = File(p.join(storageDirectory.path, 'posts.json'));
      await postsFile.writeAsString('not-json');

      final posts = await repository.loadPosts();
      final backupFile = File(
        p.join(
          storageDirectory.path,
          JsonFilePostRepository.postsBackupFileName,
        ),
      );

      expect(posts, isEmpty);
      expect(postsFile.existsSync(), isFalse);
      expect(backupFile.existsSync(), isTrue);
    });

    test('updatePost でコメントを更新できる', () async {
      final sourceFile = File(p.join(tempDirectory.path, 'source.jpg'));
      await sourceFile.writeAsBytes(<int>[1, 2, 3]);

      final savedPost = await repository.addPost(
        DailyPost(
          id: 'post-update',
          mediaPath: sourceFile.path,
          mediaType: PostMediaType.image,
          topic: '更新テスト',
          createdAt: DateTime.utc(2026, 7, 11, 8),
          comment: '元のコメント',
          mode: TopicMode.daily,
        ),
      );

      final updatedPost = await repository.updatePost(
        savedPost.copyWith(comment: '更新後のコメント'),
      );
      final loadedPosts = await repository.loadPosts();

      expect(updatedPost.comment, '更新後のコメント');
      expect(loadedPosts, hasLength(1));
      expect(loadedPosts.first.comment, '更新後のコメント');
    });

    test('deletePosts で投稿とメディアファイルを削除できる', () async {
      final sourceFile = File(p.join(tempDirectory.path, 'source.jpg'));
      await sourceFile.writeAsBytes(<int>[1, 2, 3]);

      final savedPost = await repository.addPost(
        DailyPost(
          id: 'post-delete',
          mediaPath: sourceFile.path,
          mediaType: PostMediaType.image,
          topic: '削除テスト',
          createdAt: DateTime.utc(2026, 7, 11, 8),
          comment: '',
          mode: TopicMode.daily,
        ),
      );

      await repository.deletePosts([savedPost.id]);
      final loadedPosts = await repository.loadPosts();
      final mediaFile = File(
        p.join(
          tempDirectory.path,
          MediaStorage.storageRootName,
          savedPost.mediaPath,
        ),
      );

      expect(loadedPosts, isEmpty);
      expect(mediaFile.existsSync(), isFalse);
    });
  });

  group('MediaStorage', () {
    late Directory tempDirectory;
    late MediaStorage mediaStorage;

    setUp(() async {
      tempDirectory = await Directory.systemTemp.createTemp('topit-media-');
      mediaStorage = MediaStorage(
        documentsDirectoryProvider: () async => tempDirectory,
      );
    });

    tearDown(() async {
      if (tempDirectory.existsSync()) {
        await tempDirectory.delete(recursive: true);
      }
    });

    test('拡張子がない画像は .jpg で保存する', () async {
      final sourceFile = File(p.join(tempDirectory.path, 'source'));
      await sourceFile.writeAsBytes(<int>[1]);

      final persistedPath = await mediaStorage.persistMedia(
        sourcePath: sourceFile.path,
        postId: 'post-abc',
        mediaType: PostMediaType.image,
      );

      expect(persistedPath, 'media/post-abc.jpg');
      final absolutePath = await mediaStorage.resolveAbsolutePath(
        persistedPath,
      );
      expect(File(absolutePath).existsSync(), isTrue);
    });

    test('絶対 mediaPath を現在の Documents から解決できる', () async {
      final mediaDirectory = await mediaStorage.mediaDirectory();
      final mediaFile = File(p.join(mediaDirectory.path, 'post-legacy.jpg'));
      await mediaFile.writeAsBytes(<int>[1, 2, 3]);

      final resolvedPath = await mediaStorage.resolveAbsolutePath(
        mediaFile.path,
      );

      expect(resolvedPath, mediaFile.path);
    });

    test('deleteMedia で保存済みファイルを削除できる', () async {
      final mediaDirectory = await mediaStorage.mediaDirectory();
      final mediaFile = File(p.join(mediaDirectory.path, 'post-delete.jpg'));
      await mediaFile.writeAsBytes(<int>[1, 2, 3]);

      await mediaStorage.deleteMedia('media/post-delete.jpg');

      expect(mediaFile.existsSync(), isFalse);
    });
  });
}
