import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/daily_post.dart';
import '../models/topic.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({
    super.key,
    required this.mediaPath,
    required this.mediaType,
    required this.topic,
    required this.createdAt,
    required this.mode,
    this.tripId,
    this.missionTitle,
  });

  final String mediaPath;
  final PostMediaType mediaType;
  final String topic;
  final DateTime createdAt;
  final TopicMode mode;
  final String? tripId;
  final String? missionTitle;

  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  final _commentController = TextEditingController();
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == PostMediaType.video) {
      _videoController = VideoPlayerController.file(File(widget.mediaPath))
        ..initialize().then((_) {
          if (mounted) setState(() {});
        });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _submitPost() {
    final post = DailyPost(
      id: 'post-${widget.createdAt.microsecondsSinceEpoch}',
      mediaPath: widget.mediaPath,
      mediaType: widget.mediaType,
      topic: widget.topic,
      createdAt: widget.createdAt,
      comment: _commentController.text.trim(),
      mode: widget.mode,
      tripId: widget.tripId,
      missionTitle: widget.missionTitle,
    );

    Navigator.of(context).pop(post);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.mediaType == PostMediaType.video ? '動画を投稿' : '写真を投稿',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            PostMediaPreview(
              mediaPath: widget.mediaPath,
              mediaType: widget.mediaType,
              videoController: _videoController,
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今回のお題',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.topic,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'コメント',
                hintText: '今日のひとコマについて書く',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _submitPost,
              icon: const Icon(Icons.check),
              label: const Text('投稿する'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PostMediaPreview extends StatelessWidget {
  const PostMediaPreview({
    super.key,
    required this.mediaPath,
    required this.mediaType,
    required this.videoController,
  });

  final String mediaPath;
  final PostMediaType mediaType;
  final VideoPlayerController? videoController;

  @override
  Widget build(BuildContext context) {
    final controller = videoController;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child:
            mediaType == PostMediaType.image
                ? Image.file(
                  File(mediaPath),
                  fit: BoxFit.cover,
                  errorBuilder:
                      (_, _, _) => const ColoredBox(
                        color: Color(0xFFE5E5E5),
                        child: Center(
                          child: Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
                )
                : controller != null && controller.value.isInitialized
                ? Stack(
                  fit: StackFit.expand,
                  children: [
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: controller.value.size.width,
                        height: controller.value.size.height,
                        child: VideoPlayer(controller),
                      ),
                    ),
                    Center(
                      child: IconButton.filled(
                        onPressed:
                            () =>
                                controller.value.isPlaying
                                    ? controller.pause()
                                    : controller.play(),
                        icon: Icon(
                          controller.value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                        ),
                      ),
                    ),
                  ],
                )
                : const ColoredBox(
                  color: Color(0xFFE5E5E5),
                  child: Center(child: CircularProgressIndicator()),
                ),
      ),
    );
  }
}
