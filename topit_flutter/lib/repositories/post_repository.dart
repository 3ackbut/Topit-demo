import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/daily_post.dart';
import '../services/media_storage.dart';

abstract class PostRepository {
  Future<List<DailyPost>> loadPosts();

  Future<DailyPost> addPost(DailyPost post);

  Future<DailyPost> updatePost(DailyPost post);

  Future<void> deletePosts(List<String> ids);
}

class JsonFilePostRepository implements PostRepository {
  JsonFilePostRepository({
    MediaStorage? mediaStorage,
    Future<Directory> Function()? documentsDirectoryProvider,
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _mediaStorage =
           mediaStorage ??
           MediaStorage(
             documentsDirectoryProvider:
                 documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
           );

  static const postsFileName = 'posts.json';
  static const postsTempFileName = 'posts.json.tmp';
  static const postsBackupFileName = 'posts.json.bak';
  static const schemaVersion = 1;

  final MediaStorage _mediaStorage;
  final Future<Directory> Function() _documentsDirectoryProvider;

  Future<Directory> _storageDirectory() async {
    final documentsDirectory = await _documentsDirectoryProvider();
    final directory = Directory(
      p.join(documentsDirectory.path, MediaStorage.storageRootName),
    );
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  Future<File> _postsFile() async {
    final directory = await _storageDirectory();
    return File(p.join(directory.path, postsFileName));
  }

  @override
  Future<List<DailyPost>> loadPosts() async {
    final postsFile = await _postsFile();
    if (!postsFile.existsSync()) {
      return [];
    }

    try {
      final decoded = jsonDecode(await postsFile.readAsString());
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('posts.json root must be an object');
      }

      final postsRaw = decoded['posts'];
      if (postsRaw is! List<dynamic>) {
        throw const FormatException('posts.json posts must be an array');
      }

      final posts = <DailyPost>[];
      var shouldRewrite = false;

      for (final item in postsRaw) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Each post must be an object');
        }

        final post = DailyPost.fromJson(item);
        final normalizedPost = _normalizeStoredPost(post);
        if (normalizedPost.mediaPath != post.mediaPath) {
          shouldRewrite = true;
        }
        if (!item.containsKey('mode')) {
          shouldRewrite = true;
        }
        posts.add(normalizedPost);
      }

      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (shouldRewrite) {
        await _writePosts(posts);
      }

      return posts;
    } catch (_) {
      final backupFile = File(
        p.join(postsFile.parent.path, postsBackupFileName),
      );
      if (backupFile.existsSync()) {
        await backupFile.delete();
      }
      await postsFile.rename(backupFile.path);
      return [];
    }
  }

  @override
  Future<DailyPost> addPost(DailyPost post) async {
    final storedPath = await _mediaStorage.persistMedia(
      sourcePath: post.mediaPath,
      postId: post.id,
      mediaType: post.mediaType,
    );
    final savedPost = post.copyWith(mediaPath: storedPath);

    final posts =
        await loadPosts()
          ..add(savedPost);
    posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _writePosts(posts);
    return savedPost;
  }

  @override
  Future<DailyPost> updatePost(DailyPost post) async {
    final posts = await loadPosts();
    final index = posts.indexWhere((item) => item.id == post.id);
    if (index < 0) {
      throw StateError('Post not found: ${post.id}');
    }

    posts[index] = post;
    posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _writePosts(posts);
    return post;
  }

  @override
  Future<void> deletePosts(List<String> ids) async {
    if (ids.isEmpty) {
      return;
    }

    final idSet = ids.toSet();
    final posts = await loadPosts();
    final toDelete = posts.where((post) => idSet.contains(post.id)).toList();
    if (toDelete.isEmpty) {
      return;
    }

    for (final post in toDelete) {
      await _mediaStorage.deleteMedia(post.mediaPath);
    }

    posts.removeWhere((post) => idSet.contains(post.id));
    await _writePosts(posts);
  }

  DailyPost _normalizeStoredPost(DailyPost post) {
    if (!p.isAbsolute(post.mediaPath)) {
      return post;
    }

    return post.copyWith(
      mediaPath: _mediaStorage.toStoredMediaPath(p.basename(post.mediaPath)),
    );
  }

  Future<void> _writePosts(List<DailyPost> posts) async {
    final postsFile = await _postsFile();
    final tempFile = File(p.join(postsFile.parent.path, postsTempFileName));
    final payload = jsonEncode({
      'version': schemaVersion,
      'posts': posts.map((post) => post.toJson()).toList(),
    });

    await tempFile.writeAsString(payload, flush: true);
    if (postsFile.existsSync()) {
      await postsFile.delete();
    }
    await tempFile.rename(postsFile.path);
  }
}

class InMemoryPostRepository implements PostRepository {
  InMemoryPostRepository({List<DailyPost>? initialPosts})
    : _posts = List<DailyPost>.from(initialPosts ?? const []);

  final List<DailyPost> _posts;

  @override
  Future<List<DailyPost>> loadPosts() async {
    return List<DailyPost>.from(_posts)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<DailyPost> addPost(DailyPost post) async {
    _posts.add(post);
    _posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return post;
  }

  @override
  Future<DailyPost> updatePost(DailyPost post) async {
    final index = _posts.indexWhere((item) => item.id == post.id);
    if (index < 0) {
      throw StateError('Post not found: ${post.id}');
    }

    _posts[index] = post;
    _posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return post;
  }

  @override
  Future<void> deletePosts(List<String> ids) async {
    if (ids.isEmpty) {
      return;
    }

    final idSet = ids.toSet();
    _posts.removeWhere((post) => idSet.contains(post.id));
  }
}
