import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../models/daily_post.dart';
import '../services/media_storage.dart';

class PostTimeline extends StatelessWidget {
  const PostTimeline({
    super.key,
    required this.posts,
    required this.onEditPost,
    required this.onDeletePost,
  });

  final List<DailyPost> posts;
  final ValueChanged<DailyPost> onEditPost;
  final ValueChanged<DailyPost> onDeletePost;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final post in posts) ...[
          PostPhotoCard(
            key: ValueKey(post.id),
            post: post,
            onEdit: () => onEditPost(post),
            onDelete: () => onDeletePost(post),
          ),
          if (post != posts.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class PostPhotoCard extends StatefulWidget {
  const PostPhotoCard({
    super.key,
    required this.post,
    required this.onEdit,
    required this.onDelete,
  });

  final DailyPost post;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<PostPhotoCard> createState() => _PostPhotoCardState();
}

class _PostPhotoCardState extends State<PostPhotoCard> {
  final _mediaStorage = MediaStorage();
  VideoPlayerController? _videoController;
  String? _resolvedMediaPath;
  bool _isResolvingMedia = true;
  bool _isMuted = true;
  bool _isVisibleEnough = false;

  @override
  void initState() {
    super.initState();
    _resolveMediaPath();
  }

  @override
  void didUpdateWidget(covariant PostPhotoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.mediaPath == widget.post.mediaPath &&
        oldWidget.post.mediaType == widget.post.mediaType) {
      return;
    }

    _videoController?.dispose();
    _videoController = null;
    _resolvedMediaPath = null;
    _isResolvingMedia = true;
    _isMuted = true;
    _isVisibleEnough = false;
    _resolveMediaPath();
  }

  Future<void> _resolveMediaPath() async {
    final resolvedPath = await _mediaStorage.resolveAbsolutePath(
      widget.post.mediaPath,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _resolvedMediaPath = resolvedPath;
      _isResolvingMedia = false;
    });

    if (widget.post.mediaType == PostMediaType.video) {
      final controller = VideoPlayerController.file(File(resolvedPath));
      _videoController = controller;
      await controller.initialize();
      await controller.setVolume(0.0);
      await controller.setLooping(true);
      if (!mounted) {
        return;
      }
      setState(() {});
      if (_isVisibleEnough) {
        await controller.play();
      }
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final shouldPlay = info.visibleFraction >= 0.5;
    if (shouldPlay == _isVisibleEnough) {
      return;
    }

    _isVisibleEnough = shouldPlay;
    if (shouldPlay) {
      controller.play();
    } else {
      controller.pause();
    }
  }

  Future<void> _toggleMute() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    final nextMuted = !_isMuted;
    await controller.setVolume(nextMuted ? 0.0 : 1.0);
    if (!mounted) {
      return;
    }
    setState(() {
      _isMuted = nextMuted;
    });
  }

  void _showPostMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('編集'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  widget.onEdit();
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
                title: Text(
                  '削除',
                  style: TextStyle(
                    color: Theme.of(sheetContext).colorScheme.error,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  widget.onDelete();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final videoController = _videoController;
    final mediaPath = _resolvedMediaPath;

    return VisibilityDetector(
      key: Key('post-photo-${post.id}'),
      onVisibilityChanged:
          post.mediaType == PostMediaType.video ? _onVisibilityChanged : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_isResolvingMedia)
                ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  child: const Center(child: CircularProgressIndicator()),
                )
              else if (post.mediaType == PostMediaType.image && mediaPath != null)
                Image.file(
                  File(mediaPath),
                  fit: BoxFit.cover,
                  cacheWidth: 1200,
                  errorBuilder: (context, error, stackTrace) {
                    return ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      child: const Center(
                        child: Icon(Icons.image_not_supported_outlined, size: 40),
                      ),
                    );
                  },
                )
              else if (post.mediaType == PostMediaType.image)
                ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  child: const Center(
                    child: Icon(Icons.image_not_supported_outlined, size: 40),
                  ),
                )
              else if (videoController != null &&
                  videoController.value.isInitialized)
                GestureDetector(
                  onTap: _toggleMute,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: videoController.value.size.width,
                      height: videoController.value.size.height,
                      child: VideoPlayer(videoController),
                    ),
                  ),
                )
              else
                ColoredBox(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  child: const Center(child: CircularProgressIndicator()),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xAA000000),
                      Color(0x33000000),
                      Color(0xAA000000),
                    ],
                    stops: [0, 0.48, 1],
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 16,
                right: 56,
                child: Text(
                  post.topic,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(
                        color: Colors.black54,
                        offset: Offset(0, 1),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  key: Key('post-menu-${post.id}'),
                  onPressed: () => _showPostMenu(context),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black45,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(36, 36),
                    padding: const EdgeInsets.all(6),
                  ),
                  icon: const Icon(Icons.more_horiz, size: 20),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(post.createdAt),
                        style: Theme.of(
                          context,
                        ).textTheme.displayMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          shadows: const [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(0, 2),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                      if (post.comment.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          post.comment,
                          textAlign: TextAlign.center,
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            shadows: const [
                              Shadow(
                                color: Colors.black54,
                                offset: Offset(0, 1),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (post.mediaType == PostMediaType.video &&
                  videoController != null &&
                  videoController.value.isInitialized)
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: GestureDetector(
                    onTap: _toggleMute,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        _isMuted ? Icons.volume_off : Icons.volume_up,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
