import 'dart:async';

import 'package:flutter/material.dart';

import '../models/world_challenge.dart';
import '../models/world_post.dart';
import '../services/world_ui_data_service.dart';
import '../services/world_local_state.dart';

class WorldModeScreen extends StatefulWidget {
  WorldModeScreen({
    super.key,
    WorldUiDataService? dataService,
    WorldAnswerState? localState,
  }) : _dataService = dataService ?? WorldUiDataService(),
       _localState = localState ?? InMemoryWorldAnswerState();

  final WorldUiDataService _dataService;
  final WorldAnswerState _localState;

  @override
  State<WorldModeScreen> createState() => WorldModeScreenState();
}

class WorldModeScreenState extends State<WorldModeScreen> {
  Timer? _timer;
  WorldChallenge? _challenge;
  List<WorldPost> _posts = const [];
  Set<String> _likedPostIds = const {};
  Duration? _remainingAtFetch;
  DateTime? _fetchedAt;
  bool _isLoading = true;
  bool _isAnswered = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> refresh() => _refresh(showFullScreenLoading: false);

  Future<void> _refresh({bool showFullScreenLoading = true}) async {
    final hasContent = _challenge != null || _posts.isNotEmpty;
    if (showFullScreenLoading || !hasContent) {
      setState(() => _isLoading = true);
    }
    try {
      final results = await Future.wait([
        widget._dataService.fetchChallenge(),
        widget._dataService.fetchPosts(),
        widget._localState.likedPostIds(),
      ]);
      final challenge = results[0] as WorldChallenge;
      final posts = (results[1] as WorldPostPage).items;
      final likedPostIds = results[2] as Set<String>;
      final answeredChallengeId =
          await widget._localState.answeredChallengeId();
      if (!mounted) {
        return;
      }
      setState(() {
        _challenge = challenge;
        _posts = posts;
        _likedPostIds = likedPostIds;
        _isAnswered = answeredChallengeId == challenge.id;
        _remainingAtFetch = challenge.expiresAt.difference(
          challenge.serverTime,
        );
        _fetchedAt = DateTime.now();
        _isLoading = false;
      });
    } on Exception {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      _showMessage('世界のお題を読み込めませんでした');
    }
  }

  void _tick() {
    final remaining = _remaining;
    if (remaining != null && remaining <= Duration.zero) {
      _refresh();
      return;
    }
    if (mounted) {
      setState(() {});
    }
  }

  Duration? get _remaining {
    final remainingAtFetch = _remainingAtFetch;
    final fetchedAt = _fetchedAt;
    if (remainingAtFetch == null || fetchedAt == null) {
      return null;
    }
    return remainingAtFetch - DateTime.now().difference(fetchedAt);
  }

  Future<void> _likePost(String postId) async {
    if (_likedPostIds.contains(postId)) {
      return;
    }

    final index = _posts.indexWhere((post) => post.id == postId);
    if (index < 0) {
      return;
    }

    final previousPost = _posts[index];
    final previousLikedPostIds = _likedPostIds;
    setState(() {
      _likedPostIds = {..._likedPostIds, postId};
      _posts = [
        for (var i = 0; i < _posts.length; i++)
          if (i == index)
            previousPost.copyWith(likeCount: previousPost.likeCount + 1)
          else
            _posts[i],
      ];
    });

    try {
      final likeCount = await widget._dataService.likePost(postId);
      await widget._localState.markLiked(postId);
      if (!mounted) {
        return;
      }
      setState(() {
        _posts = [
          for (var i = 0; i < _posts.length; i++)
            if (i == index) previousPost.copyWith(likeCount: likeCount) else _posts[i],
        ];
      });
    } on Exception {
      if (!mounted) {
        return;
      }
      setState(() {
        _likedPostIds = previousLikedPostIds;
        _posts = [
          for (var i = 0; i < _posts.length; i++)
            if (i == index) previousPost else _posts[i],
        ];
      });
      _showMessage('いいねを送れませんでした');
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final challenge = _challenge;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child:
                _isLoading && challenge == null
                    ? const LinearProgressIndicator()
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '今日のお題',
                          style: Theme.of(
                            context,
                          ).textTheme.titleMedium?.copyWith(
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          challenge?.prompt ?? 'お題を準備しています',
                          style: Theme.of(
                            context,
                          ).textTheme.headlineSmall?.copyWith(
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '次のお題まで ${_formatRemaining(_remaining)}',
                          style: Theme.of(
                            context,
                          ).textTheme.titleSmall?.copyWith(
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (_isAnswered)
                          Text(
                            '今日のお題には回答済みです',
                            style: Theme.of(
                              context,
                            ).textTheme.titleSmall?.copyWith(
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        else
                          const FilledButton.icon(
                            onPressed: null,
                            icon: Icon(Icons.photo_camera_outlined),
                            label: Text('投稿機能は停止中です'),
                          ),
                      ],
                    ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          '世界の回答',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        if (_isLoading && _posts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_posts.isEmpty)
          const _EmptyWorldPosts()
        else
          _WorldTimeline(
            posts: _posts,
            likedPostIds: _likedPostIds,
            onLike: _likePost,
          ),
      ],
    );
  }

  static String _formatRemaining(Duration? remaining) {
    if (remaining == null) {
      return '--';
    }
    final safe = remaining.isNegative ? Duration.zero : remaining;
    final hours = safe.inHours;
    final minutes = safe.inMinutes.remainder(60);
    if (safe.inMinutes < 1) {
      return '${safe.inSeconds.remainder(60)}秒';
    }
    return '$hours時間$minutes分';
  }
}

class _WorldTimeline extends StatelessWidget {
  const _WorldTimeline({
    required this.posts,
    required this.likedPostIds,
    required this.onLike,
  });

  final List<WorldPost> posts;
  final Set<String> likedPostIds;
  final Future<void> Function(String postId) onLike;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final post in posts) ...[
          _WorldPostCard(
            post: post,
            isLiked: likedPostIds.contains(post.id),
            onLike: () => onLike(post.id),
          ),
          if (post != posts.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _WorldPostCard extends StatefulWidget {
  const _WorldPostCard({
    required this.post,
    required this.isLiked,
    required this.onLike,
  });

  final WorldPost post;
  final bool isLiked;
  final VoidCallback onLike;

  @override
  State<_WorldPostCard> createState() => _WorldPostCardState();
}

class _WorldPostCardState extends State<_WorldPostCard>
    with TickerProviderStateMixin {
  TapDownDetails? _doubleTapDetails;
  Offset? _burstPosition;
  AnimationController? _burstController;
  late final AnimationController _badgePulseController;
  late final Animation<double> _badgePulseScale;

  @override
  void initState() {
    super.initState();
    _badgePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _badgePulseScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1, end: 1.45), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.45, end: 1), weight: 45),
    ]).animate(CurvedAnimation(parent: _badgePulseController, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant _WorldPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isLiked && widget.isLiked) {
      _badgePulseController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _burstController?.dispose();
    _badgePulseController.dispose();
    super.dispose();
  }

  Future<void> _playBurstAt(Offset localPosition) async {
    _burstController?.dispose();
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _burstController = controller;
    setState(() => _burstPosition = localPosition);
    await controller.forward();
    if (!mounted) {
      return;
    }
    setState(() => _burstPosition = null);
    controller.dispose();
    if (_burstController == controller) {
      _burstController = null;
    }
  }

  void _handleDoubleTap() {
    if (widget.isLiked) {
      return;
    }
    final details = _doubleTapDetails;
    _doubleTapDetails = null;
    if (details != null) {
      unawaited(_playBurstAt(details.localPosition));
    }
    widget.onLike();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: GestureDetector(
          key: ValueKey('world-post-image-${widget.post.id}'),
          behavior: HitTestBehavior.opaque,
          onDoubleTapDown: (details) => _doubleTapDetails = details,
          onDoubleTapCancel: () => _doubleTapDetails = null,
          onDoubleTap: _handleDoubleTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                widget.post.imageUrl,
                fit: BoxFit.cover,
                cacheWidth: 1200,
                errorBuilder:
                    (_, _, _) => ColoredBox(
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      child: const Center(
                        child: Icon(Icons.image_not_supported_outlined, size: 40),
                      ),
                    ),
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return ColoredBox(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
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
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(widget.post.createdAt),
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
                      if (widget.post.comment.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          widget.post.comment,
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
              if (_burstPosition != null && _burstController != null)
                _LikeBurstOverlay(
                  position: _burstPosition!,
                  controller: _burstController!,
                ),
              Positioned(
                right: 16,
                bottom: 16,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ScaleTransition(
                      scale: _badgePulseScale,
                      child: Icon(
                        widget.isLiked ? Icons.favorite : Icons.favorite_border,
                        color:
                            widget.isLiked ? Colors.redAccent : Colors.white70,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.post.likeCount}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
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
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _LikeBurstOverlay extends StatelessWidget {
  const _LikeBurstOverlay({
    required this.position,
    required this.controller,
  });

  final Offset position;
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    const size = 88.0;
    final scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.15, end: 1.15), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1), weight: 55),
    ]).animate(CurvedAnimation(parent: controller, curve: Curves.easeOut));
    final opacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: controller,
        curve: const Interval(0.35, 1, curve: Curves.easeOut),
      ),
    );

    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) => Opacity(
            opacity: opacity.value,
            child: Transform.scale(scale: scale.value, child: child),
          ),
          child: Icon(
            Icons.favorite,
            size: size,
            color: Colors.redAccent.withValues(alpha: 0.95),
            shadows: const [
              Shadow(
                color: Colors.black45,
                offset: Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyWorldPosts extends StatelessWidget {
  const _EmptyWorldPosts();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Text(
        'まだ回答はありません。最初の一枚を投稿してみよう。',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
