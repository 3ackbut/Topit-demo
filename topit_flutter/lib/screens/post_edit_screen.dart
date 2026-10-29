import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/daily_post.dart';
import 'post_screen.dart';

class PostEditScreen extends StatefulWidget {
  const PostEditScreen({
    super.key,
    required this.post,
    required this.mediaPath,
  });

  final DailyPost post;
  final String mediaPath;

  @override
  State<PostEditScreen> createState() => _PostEditScreenState();
}

class _PostEditScreenState extends State<PostEditScreen> {
  late final TextEditingController _commentController;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _commentController = TextEditingController(text: widget.post.comment);
    if (widget.post.mediaType == PostMediaType.video) {
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

  void _savePost() {
    final updatedPost = widget.post.copyWith(
      comment: _commentController.text.trim(),
    );
    Navigator.of(context).pop(updatedPost);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('投稿を編集')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            PostMediaPreview(
              mediaPath: widget.mediaPath,
              mediaType: widget.post.mediaType,
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
                      widget.post.topic,
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
              onPressed: _savePost,
              icon: const Icon(Icons.check),
              label: const Text('保存する'),
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
