import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/daily_post.dart';
import '../services/daily_recap_service.dart';
import '../services/media_storage.dart';
import '../services/recap_ending_messages.dart';
import '../widgets/recap_ending_earth.dart';

typedef RecapVideoDurationResolver = Future<Duration> Function(String path);

class TravelRecapHeader {
  const TravelRecapHeader({
    required this.itinerary,
    required this.startedAt,
    required this.endedAt,
    this.showEmptyMessage = false,
  });

  final String itinerary;
  final DateTime startedAt;
  final DateTime endedAt;
  final bool showEmptyMessage;
}

class DailyRecapScreen extends StatefulWidget {
  DailyRecapScreen({
    super.key,
    required List<DailyPost> posts,
    this.header,
    this.forceView = false,
    this.endingBody,
    MediaStorage? mediaStorage,
    this.videoDurationResolver,
  }) : posts = List<DailyPost>.unmodifiable(posts),
       mediaStorage = mediaStorage ?? MediaStorage();

  final List<DailyPost> posts;
  final TravelRecapHeader? header;
  final bool forceView;
  final RecapEndingBody? endingBody;
  final MediaStorage mediaStorage;
  final RecapVideoDurationResolver? videoDurationResolver;

  bool get _isHeaderOnly => posts.isEmpty && header != null;

  int get _slideCount => _isHeaderOnly ? 1 : posts.length;

  @override
  State<DailyRecapScreen> createState() => _DailyRecapScreenState();
}

class _DailyRecapScreenState extends State<DailyRecapScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _progressController;
  late final String _endingMessage;
  late final RecapEndingBody _endingBody;
  VideoPlayerController? _videoController;
  int _currentIndex = 0;
  int _playToken = 0;
  bool _isLoading = true;
  bool _showingEnding = false;
  String? _resolvedMediaPath;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _endingMessage = pickRecapEndingMessage(
      recapKindFor(
        posts: widget.posts,
        hasTravelHeader: widget.header != null,
      ),
    );
    _endingBody = widget.endingBody ?? pickRecapEndingBody();
    _pageController = PageController();
    _progressController = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _goToNextOrClose();
        }
      });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startSlide(0);
      }
    });
  }

  @override
  void dispose() {
    _playToken++;
    _progressController.dispose();
    _pageController.dispose();
    _disposeVideoController();
    super.dispose();
  }

  Future<void> _startSlide(int index) async {
    if (index < 0 || index >= widget._slideCount) {
      return;
    }

    if (widget._isHeaderOnly) {
      final token = ++_playToken;
      _progressController
        ..stop()
        ..reset();
      await _disposeVideoController();
      if (!mounted || token != _playToken) {
        return;
      }
      setState(() {
        _currentIndex = 0;
        _isLoading = false;
        _resolvedMediaPath = null;
        _errorMessage = null;
      });
      _runProgress(travelEmptyRecapDuration);
      return;
    }

    final token = ++_playToken;
    _progressController
      ..stop()
      ..reset();
    await _disposeVideoController();

    if (!mounted || token != _playToken) {
      return;
    }

    setState(() {
      _currentIndex = index;
      _isLoading = true;
      _resolvedMediaPath = null;
      _errorMessage = null;
    });

    final post = widget.posts[index];
    try {
      final resolvedPath = await widget.mediaStorage.resolveAbsolutePath(
        post.mediaPath,
      );
      if (!mounted || token != _playToken) {
        return;
      }

      setState(() {
        _resolvedMediaPath = resolvedPath;
      });

      if (post.mediaType == PostMediaType.image) {
        setState(() {
          _isLoading = false;
        });
        _runProgress(dailyRecapPhotoDuration);
        return;
      }

      await _startVideo(resolvedPath, token);
    } on Exception {
      if (!mounted || token != _playToken) {
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = 'メディアを読み込めませんでした';
      });
    }
  }

  Future<void> _startVideo(String path, int token) async {
    final controller = VideoPlayerController.file(File(path));
    _videoController = controller;

    try {
      await controller.initialize();
      final duration =
          await widget.videoDurationResolver?.call(path) ??
          controller.value.duration;
      if (!mounted || token != _playToken) {
        await controller.dispose();
        return;
      }

      await controller.seekTo(Duration.zero);
      await controller.play();
      setState(() {
        _isLoading = false;
      });
      _runProgress(
        duration > Duration.zero ? duration : controller.value.duration,
      );
    } on Exception {
      if (!mounted || token != _playToken) {
        await controller.dispose();
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = '動画を再生できませんでした';
      });
    }
  }

  void _runProgress(Duration duration) {
    if (!mounted) {
      return;
    }

    _progressController.duration =
        duration > Duration.zero ? duration : dailyRecapPhotoDuration;
    _progressController.forward(from: 0);
  }

  Future<void> _disposeVideoController() async {
    final controller = _videoController;
    _videoController = null;
    if (controller == null) {
      return;
    }

    await controller.pause();
    await controller.dispose();
  }

  void _goToNextOrClose() {
    if (!mounted) {
      return;
    }

    if (_currentIndex >= widget._slideCount - 1) {
      _showEnding();
      return;
    }

    _goToIndex(_currentIndex + 1);
  }

  void _showEnding() {
    _progressController
      ..stop()
      ..reset();
    unawaited(_disposeVideoController());
    setState(() {
      _showingEnding = true;
    });
  }

  void _closeRecap() {
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  void _goToPrevious() {
    if (widget.forceView) {
      return;
    }

    if (_currentIndex <= 0) {
      _startSlide(0);
      return;
    }

    _goToIndex(_currentIndex - 1);
  }

  void _goToIndex(int index) {
    if (index < 0 || index >= widget._slideCount) {
      return;
    }

    _progressController
      ..stop()
      ..reset();
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _handlePageChanged(int index) {
    _startSlide(index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget._slideCount == 0) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_showingEnding)
                _RecapEndingPage(
                  message: _endingMessage,
                  body: _endingBody,
                  onClose: _closeRecap,
                )
              else if (widget._isHeaderOnly)
                _TravelHeaderRecapPage(header: widget.header!)
              else
                PageView.builder(
                  controller: _pageController,
                  onPageChanged: _handlePageChanged,
                  itemCount: widget.posts.length,
                  itemBuilder: (context, index) {
                    return _RecapPage(
                      post: widget.posts[index],
                      isCurrent: index == _currentIndex,
                      isLoading: _isLoading && index == _currentIndex,
                      mediaPath:
                          index == _currentIndex ? _resolvedMediaPath : null,
                      videoController:
                          index == _currentIndex ? _videoController : null,
                      errorMessage:
                          index == _currentIndex ? _errorMessage : null,
                      onNext: _goToNextOrClose,
                    );
                  },
                ),
              if (!_showingEnding)
                Positioned.fill(
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: _goToPrevious,
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: _goToNextOrClose,
                        ),
                      ),
                    ],
                  ),
                ),
              if (!_showingEnding)
                _RecapChrome(
                  slideCount: widget._slideCount,
                  currentIndex: _currentIndex,
                  progress: _progressController,
                  onClose:
                      widget.forceView
                          ? null
                          : _closeRecap,
                ),
            ],
          ),
        ),
    );
  }
}

class _RecapEndingPage extends StatelessWidget {
  const _RecapEndingPage({
    required this.message,
    required this.body,
    required this.onClose,
  });

  final String message;
  final RecapEndingBody body;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: const ColoredBox(color: Colors.black),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (body == RecapEndingBody.moon) ...[
                  Text(
                    'Luna',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.42),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Stack(
                  alignment: Alignment.center,
                  children: [
                    RecapEndingEarth(body: body),
                    GestureDetector(
                      onTap: onClose,
                      behavior: HitTestBehavior.translucent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                height: 1.45,
                                shadows: const [
                                  Shadow(color: Colors.black87, blurRadius: 12),
                                ],
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TravelHeaderRecapPage extends StatelessWidget {
  const _TravelHeaderRecapPage({required this.header});

  final TravelRecapHeader header;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Colors.black),
        const _TopGradient(),
        const _BottomGradient(),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '旅の振り返り',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                header.itinerary,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _formatPeriod(header.startedAt, header.endedAt),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (header.showEmptyMessage) ...[
                const Spacer(),
                Text(
                  'この旅では写真を撮っていません',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _formatPeriod(DateTime startedAt, DateTime endedAt) {
    final start = startedAt.toLocal();
    final end = endedAt.toLocal();
    String format(DateTime value) {
      final month = value.month;
      final day = value.day;
      final hour = value.hour.toString().padLeft(2, '0');
      final minute = value.minute.toString().padLeft(2, '0');
      return '$month/$day $hour:$minute';
    }

    return '${format(start)} 〜 ${format(end)}';
  }
}

class _RecapPage extends StatelessWidget {
  const _RecapPage({
    required this.post,
    required this.isCurrent,
    required this.isLoading,
    required this.mediaPath,
    required this.videoController,
    required this.errorMessage,
    required this.onNext,
  });

  final DailyPost post;
  final bool isCurrent;
  final bool isLoading;
  final String? mediaPath;
  final VideoPlayerController? videoController;
  final String? errorMessage;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final mediaPath = this.mediaPath;
    final videoController = this.videoController;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (errorMessage != null)
          _RecapError(message: errorMessage!, onNext: onNext)
        else if (isLoading)
          const Center(child: CircularProgressIndicator(color: Colors.white))
        else if (post.mediaType == PostMediaType.image && mediaPath != null)
          Image.file(
            File(mediaPath),
            fit: BoxFit.contain,
            errorBuilder:
                (context, error, stackTrace) =>
                    _RecapError(message: '画像を表示できませんでした', onNext: onNext),
          )
        else if (post.mediaType == PostMediaType.video &&
            videoController != null &&
            videoController.value.isInitialized)
          FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(
              width: videoController.value.size.width,
              height: videoController.value.size.height,
              child: VideoPlayer(videoController),
            ),
          )
        else
          _RecapError(message: 'メディアを表示できませんでした', onNext: onNext),
        const _TopGradient(),
        const _BottomGradient(),
        Positioned(
          top: 42,
          left: 16,
          right: 72,
          child: Text(
            post.topic,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(post.createdAt),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                  fontWeight: FontWeight.w700,
                  shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
                ),
              ),
              if (post.comment.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  post.comment,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.28,
                    shadows: const [
                      Shadow(color: Colors.black87, blurRadius: 8),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static String _formatTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _RecapChrome extends StatelessWidget {
  const _RecapChrome({
    required this.slideCount,
    required this.currentIndex,
    required this.progress,
    required this.onClose,
  });

  final int slideCount;
  final int currentIndex;
  final Animation<double> progress;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      left: 10,
      right: 8,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: AnimatedBuilder(
                animation: progress,
                builder: (context, _) {
                  return Row(
                    children: [
                      for (var index = 0; index < slideCount; index++) ...[
                        Expanded(
                          child: _ProgressSegment(
                            value:
                                index < currentIndex
                                    ? 1
                                    : index == currentIndex
                                    ? progress.value
                                    : 0,
                          ),
                        ),
                        if (index != slideCount - 1) const SizedBox(width: 4),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
          if (onClose != null) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: '閉じる',
              onPressed: onClose,
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProgressSegment extends StatelessWidget {
  const _ProgressSegment({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        minHeight: 3,
        value: value.clamp(0, 1),
        color: Colors.white,
        backgroundColor: Colors.white.withValues(alpha: 0.32),
      ),
    );
  }
}

class _RecapError extends StatelessWidget {
  const _RecapError({required this.message, required this.onNext});

  final String message;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white70, size: 42),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onNext,
                icon: const Icon(Icons.skip_next),
                label: const Text('次へ'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopGradient extends StatelessWidget {
  const _TopGradient();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.topCenter,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xCC000000), Color(0x00000000)],
            ),
          ),
          child: SizedBox(height: 150, width: double.infinity),
        ),
      ),
    );
  }
}

class _BottomGradient extends StatelessWidget {
  const _BottomGradient();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.bottomCenter,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xD9000000), Color(0x00000000)],
            ),
          ),
          child: SizedBox(height: 220, width: double.infinity),
        ),
      ),
    );
  }
}
