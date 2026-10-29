import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/daily_post.dart';

class MediaStorage {
  MediaStorage({Future<Directory> Function()? documentsDirectoryProvider})
    : _documentsDirectoryProvider =
          documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  final Future<Directory> Function() _documentsDirectoryProvider;

  static const storageRootName = 'topit';
  static const mediaDirectoryName = 'media';

  Future<Directory> mediaDirectory() async {
    final documentsDirectory = await _documentsDirectoryProvider();
    final directory = Directory(
      p.join(documentsDirectory.path, storageRootName, mediaDirectoryName),
    );
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String toStoredMediaPath(String fileName) {
    return p.join(mediaDirectoryName, fileName);
  }

  Future<String> resolveAbsolutePath(String mediaPath) async {
    final normalizedPath = _normalizeStoredMediaPath(mediaPath);
    final documentsDirectory = await _documentsDirectoryProvider();
    final resolvedPath = p.join(
      documentsDirectory.path,
      storageRootName,
      normalizedPath,
    );

    if (File(resolvedPath).existsSync()) {
      return resolvedPath;
    }

    if (p.isAbsolute(mediaPath) && File(mediaPath).existsSync()) {
      return mediaPath;
    }

    return resolvedPath;
  }

  String _normalizeStoredMediaPath(String mediaPath) {
    if (!p.isAbsolute(mediaPath)) {
      return mediaPath;
    }

    return p.join(mediaDirectoryName, p.basename(mediaPath));
  }

  Future<String> persistMedia({
    required String sourcePath,
    required String postId,
    required PostMediaType mediaType,
  }) async {
    final sourceFile = File(sourcePath);
    if (!sourceFile.existsSync()) {
      throw FileSystemException('Source media file does not exist', sourcePath);
    }

    final extension = _resolveExtension(sourcePath, mediaType);
    final fileName = '$postId$extension';
    final destinationFile = File(
      p.join((await mediaDirectory()).path, fileName),
    );

    if (sourceFile.path != destinationFile.path) {
      final bytes = await sourceFile.readAsBytes();
      await destinationFile.writeAsBytes(bytes, flush: true);
    }

    return toStoredMediaPath(fileName);
  }

  Future<void> deleteMedia(String mediaPath) async {
    final absolutePath = await resolveAbsolutePath(mediaPath);
    final file = File(absolutePath);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  String _resolveExtension(String sourcePath, PostMediaType mediaType) {
    final extension = p.extension(sourcePath);
    if (extension.isNotEmpty) {
      return extension;
    }

    return switch (mediaType) {
      PostMediaType.image => '.jpg',
      PostMediaType.video => '.mp4',
    };
  }
}
