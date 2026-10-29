import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../config/media_config.dart';
import '../models/daily_post.dart';
import '../models/mission.dart';
import '../models/topic.dart';
import '../models/travel_session.dart';
import '../models/travel_trip_record.dart';
import '../repositories/post_repository.dart';
import '../services/daily_recap_service.dart';
import '../services/media_storage.dart';
import '../services/topic_service.dart';
import '../services/travel_session_store.dart';
import '../services/travel_trip_history_store.dart';
import '../widgets/post_timeline.dart';
import 'daily_recap_screen.dart';
import 'post_edit_screen.dart';
import 'post_screen.dart';
import 'travel_mode_screen.dart';
import 'travel_trip_detail_screen.dart';
import 'world_mode_screen.dart';

class HomeScreen extends StatefulWidget {
  HomeScreen({
    super.key,
    this.initialMode = TopicMode.daily,
    TopicService? topicService,
    PostRepository? postRepository,
    TravelSessionStore? travelSessionStore,
    TravelTripHistoryStore? travelTripHistoryStore,
    DateTime Function()? nowProvider,
    this.worldModeBuilder,
  }) : topicService = topicService ?? const _DefaultTopicService(),
       postRepository = postRepository ?? const _DefaultPostRepository(),
       travelSessionStore =
           travelSessionStore ?? InMemoryTravelSessionStore(),
       travelTripHistoryStore =
           travelTripHistoryStore ?? InMemoryTravelTripHistoryStore(),
       nowProvider = nowProvider ?? DateTime.now;

  final TopicService topicService;
  final TopicMode initialMode;
  final PostRepository postRepository;
  final TravelSessionStore travelSessionStore;
  final TravelTripHistoryStore travelTripHistoryStore;
  final DateTime Function() nowProvider;
  final Widget Function()? worldModeBuilder;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class _DefaultTopicService implements TopicService {
  const _DefaultTopicService();

  @override
  Future<Topic> fetchTopic({required TopicMode mode, String? excludeTopicId}) {
    final service = FixedTopicService();
    return service.fetchTopic(mode: mode, excludeTopicId: excludeTopicId);
  }
}

class _DefaultPostRepository implements PostRepository {
  const _DefaultPostRepository();

  static final _delegate = InMemoryPostRepository();

  @override
  Future<List<DailyPost>> loadPosts() => _delegate.loadPosts();

  @override
  Future<DailyPost> addPost(DailyPost post) => _delegate.addPost(post);

  @override
  Future<DailyPost> updatePost(DailyPost post) => _delegate.updatePost(post);

  @override
  Future<void> deletePosts(List<String> ids) => _delegate.deletePosts(ids);
}

class HomeScreenState extends State<HomeScreen> {
  final _imagePicker = ImagePicker();
  final _worldModeKey = GlobalKey<WorldModeScreenState>();
  late TopicMode _selectedMode;
  Topic? _currentTopic;
  final List<DailyPost> _posts = [];
  List<TravelTripRecord> _tripHistory = [];
  TravelSession? _activeTravelSession;
  bool _isLoadingTopic = false;
  bool _isLoadingPosts = true;
  bool _isLoadingTripHistory = true;

  List<DailyPost> get _visiblePosts =>
      _posts.where((post) => post.mode == _selectedMode).toList();

  List<DailyPost> get _todayDailyRecapPosts =>
      todayDailyRecapPosts(_posts, now: widget.nowProvider());

  List<_TravelTripListEntry> get _travelTripEntries {
    final entries = <_TravelTripListEntry>[];
    final activeSession = _activeTravelSession;
    if (activeSession != null) {
      entries.add(
        _TravelTripListEntry(
          record: TravelTripRecord(
            id: activeSession.id,
            itinerary: activeSession.itinerary,
            startedAt: activeSession.startedAt,
            endedAt: widget.nowProvider(),
          ),
          isActive: true,
        ),
      );
    }

    for (final record in _tripHistory) {
      if (activeSession?.id == record.id) {
        continue;
      }
      entries.add(_TravelTripListEntry(record: record, isActive: false));
    }

    return entries;
  }

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
    _refreshTopic();
    _loadPosts();
  }

  void openWorldMode() {
    if (!mounted || _selectedMode == TopicMode.world) {
      return;
    }
    _selectMode(TopicMode.world);
  }

  Future<void> _loadPosts() async {
    try {
      final posts = await widget.postRepository.loadPosts();
      if (!mounted) {
        return;
      }

      setState(() {
        _posts
          ..clear()
          ..addAll(posts);
        _isLoadingPosts = false;
      });
      await _refreshTravelState();
    } on Exception {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingPosts = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('投稿の読み込みに失敗しました')));
    }
  }

  Future<void> _refreshTopic() async {
    if (_selectedMode != TopicMode.daily) {
      return;
    }

    setState(() {
      _isLoadingTopic = true;
    });

    final nextTopic = await widget.topicService.fetchTopic(
      mode: TopicMode.daily,
      excludeTopicId: _currentTopic?.id,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _currentTopic = nextTopic;
      _isLoadingTopic = false;
    });
  }

  Future<void> _refreshTravelState() async {
    final session = await widget.travelSessionStore.load();
    final history = await widget.travelTripHistoryStore.loadAll(
      postsForMigration: _posts,
    );
    if (!mounted) {
      return;
    }

    setState(() {
      _activeTravelSession = session;
      _tripHistory = history;
      _isLoadingTripHistory = false;
    });
  }

  void _selectMode(TopicMode mode) {
    setState(() {
      _selectedMode = mode;
    });

    if (mode == TopicMode.travel) {
      _refreshTravelState();
    }

    if (mode == TopicMode.daily && _currentTopic == null) {
      _refreshTopic();
    }
  }

  Future<void> _editPost(DailyPost post) async {
    if (_selectedMode == TopicMode.world || !mounted) {
      return;
    }

    final mediaStorage = MediaStorage();
    late final String resolvedPath;
    try {
      if (p.isAbsolute(post.mediaPath) && File(post.mediaPath).existsSync()) {
        resolvedPath = post.mediaPath;
      } else {
        resolvedPath = await mediaStorage.resolveAbsolutePath(post.mediaPath);
      }
    } on Exception {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('投稿を開けませんでした')));
      return;
    }

    if (!mounted) {
      return;
    }
    final updatedPost = await Navigator.of(context).push<DailyPost>(
      MaterialPageRoute<DailyPost>(
        builder:
            (_) => PostEditScreen(post: post, mediaPath: resolvedPath),
      ),
    );
    if (updatedPost == null || !mounted) {
      return;
    }

    try {
      final savedPost = await widget.postRepository.updatePost(updatedPost);
      if (!mounted) {
        return;
      }

      setState(() {
        final index = _posts.indexWhere((item) => item.id == savedPost.id);
        if (index >= 0) {
          _posts[index] = savedPost;
        }
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('投稿を更新しました')));
    } on Exception {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('投稿の更新に失敗しました')));
    }
  }

  Future<void> _deletePost(DailyPost post) async {
    if (_selectedMode == TopicMode.world || !mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('投稿を削除'),
            content: const Text('この投稿を削除しますか？この操作は取り消せません。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: const Text('削除'),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await widget.postRepository.deletePosts([post.id]);
      if (!mounted) {
        return;
      }

      setState(() {
        _posts.removeWhere((item) => item.id == post.id);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('投稿を削除しました')));
    } on Exception {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('投稿の削除に失敗しました')));
    }
  }

  Future<bool> _deleteTrip(TravelTripRecord trip, {required bool isActive}) async {
    if (isActive || !mounted) {
      return false;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('旅を削除'),
            content: const Text(
              'この旅と紐づく写真もすべて削除されます。この操作は取り消せません。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: const Text('削除'),
              ),
            ],
          ),
    );

    if (confirmed != true || !mounted) {
      return false;
    }

    final tripPostIds =
        tripRecapPosts(_posts, trip.id).map((post) => post.id).toList();

    try {
      if (tripPostIds.isNotEmpty) {
        await widget.postRepository.deletePosts(tripPostIds);
      }
      await widget.travelTripHistoryStore.delete(trip.id);
      if (!mounted) {
        return false;
      }

      setState(() {
        _posts.removeWhere((post) => tripPostIds.contains(post.id));
        _tripHistory.removeWhere((record) => record.id == trip.id);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('旅を削除しました')));
      return true;
    } on Exception {
      if (!mounted) {
        return false;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('旅の削除に失敗しました')));
      return false;
    }
  }

  Future<void> _openPostScreen() async {
    final topic = _currentTopic;
    if (topic == null || _selectedMode != TopicMode.daily) {
      return;
    }

    final selection = await _showMediaSourceSheet();
    if (selection == null || !mounted) {
      return;
    }

    final media = await _pickMedia(selection);
    if (media == null || !mounted) {
      return;
    }

    final post = await Navigator.of(context).push<DailyPost>(
      MaterialPageRoute<DailyPost>(
        builder:
            (_) => PostScreen(
              mediaPath: media.path,
              mediaType: selection.mediaType,
              topic: topic.text,
              createdAt: DateTime.now(),
              mode: _selectedMode,
            ),
      ),
    );

    if (post == null || !mounted) {
      return;
    }

    try {
      final savedPost = await widget.postRepository.addPost(post);
      if (!mounted) {
        return;
      }

      setState(() {
        _posts.add(savedPost);
        _posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });
    } on Exception {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('投稿の保存に失敗しました')));
      return;
    }

    await _refreshTopic();
  }

  Future<bool> _openTravelPost(TravelSession session, Mission mission) async {
    final selection = await _showMediaSourceSheet();
    if (selection == null || !mounted) {
      return false;
    }
    final media = await _pickMedia(selection);
    if (media == null || !mounted) {
      return false;
    }
    final post = await Navigator.of(context).push<DailyPost>(
      MaterialPageRoute<DailyPost>(
        builder:
            (_) => PostScreen(
              mediaPath: media.path,
              mediaType: selection.mediaType,
              topic: mission.title,
              createdAt: DateTime.now(),
              mode: TopicMode.travel,
              tripId: session.id,
              missionTitle: mission.title,
            ),
      ),
    );
    if (post == null || !mounted) {
      return false;
    }
    try {
      final savedPost = await widget.postRepository.addPost(post);
      if (!mounted) return false;
      setState(() {
        _posts.add(savedPost);
        _posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });
      await _refreshTravelState();
      return true;
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('投稿の保存に失敗しました')));
      }
      return false;
    }
  }

  void _openDailyRecap() {
    final posts = _todayDailyRecapPosts;
    if (posts.isEmpty) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DailyRecapScreen(posts: posts)),
    );
  }

  Future<void> _endTravel(TravelSession session) async {
    final endedAt = widget.nowProvider();
    final record = TravelTripRecord(
      id: session.id,
      itinerary: session.itinerary,
      startedAt: session.startedAt,
      endedAt: endedAt,
    );

    await widget.travelTripHistoryStore.add(record);
    await widget.travelSessionStore.clear();
    if (!mounted) {
      return;
    }

    setState(() {
      _activeTravelSession = null;
    });

    final recapPosts = tripRecapPosts(_posts, session.id);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder:
            (_) => DailyRecapScreen(
              posts: recapPosts,
              forceView: recapPosts.isEmpty,
              header:
                  recapPosts.isEmpty
                      ? TravelRecapHeader(
                        itinerary: session.itinerary,
                        startedAt: session.startedAt,
                        endedAt: endedAt,
                        showEmptyMessage: true,
                      )
                      : null,
            ),
      ),
    );

    if (!mounted) {
      return;
    }
    await _refreshTravelState();
  }

  Future<void> _openTravelTripDetail(
    TravelTripRecord trip, {
    required bool isActive,
  }) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder:
            (_) => TravelTripDetailScreen(
              trip: trip,
              posts: _posts,
              isActive: isActive,
              onEditPost: _editPost,
              onDeletePost: _deletePost,
              onDeleteTrip: (record) => _deleteTrip(record, isActive: isActive),
            ),
      ),
    );

    if (!mounted) {
      return;
    }
    await _refreshTravelState();
  }

  Future<_MediaSelection?> _showMediaSourceSheet() {
    return showModalBottomSheet<_MediaSelection>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    '写真・動画を追加',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _ImageSourceOption(
                  icon: Icons.photo_camera_outlined,
                  title: '写真を撮影',
                  color: colorScheme.primary,
                  onTap:
                      () => Navigator.of(context).pop(
                        const _MediaSelection(
                          ImageSource.camera,
                          PostMediaType.image,
                        ),
                      ),
                ),
                const SizedBox(height: 8),
                _ImageSourceOption(
                  icon: Icons.videocam_outlined,
                  title: '動画を撮影（5秒）',
                  color: colorScheme.primary,
                  onTap:
                      () => Navigator.of(context).pop(
                        const _MediaSelection(
                          ImageSource.camera,
                          PostMediaType.video,
                        ),
                      ),
                ),
                const SizedBox(height: 8),
                _ImageSourceOption(
                  icon: Icons.photo_library_outlined,
                  title: '写真ライブラリから選ぶ',
                  color: colorScheme.primary,
                  onTap:
                      () => Navigator.of(context).pop(
                        const _MediaSelection(
                          ImageSource.gallery,
                          PostMediaType.image,
                        ),
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<XFile?> _pickMedia(_MediaSelection selection) async {
    XFile? picked;

    try {
      picked = await _invokeMediaPicker(selection);
    } on Exception {
      if (selection.source != ImageSource.camera) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                selection.mediaType == PostMediaType.video
                    ? '動画を選択できませんでした'
                    : '写真を選択できませんでした',
              ),
            ),
          );
        }
        return null;
      }

      if (!mounted) {
        return null;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            selection.mediaType == PostMediaType.video
                ? 'カメラを使えないため、動画ライブラリを開きます'
                : 'カメラを使えないため、写真ライブラリを開きます',
          ),
        ),
      );

      try {
        picked = await _invokeMediaPicker(
          _MediaSelection(ImageSource.gallery, selection.mediaType),
        );
      } on Exception {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                selection.mediaType == PostMediaType.video
                    ? '動画を選択できませんでした'
                    : '写真を選択できませんでした',
              ),
            ),
          );
        }
        return null;
      }
    }

    if (picked == null) {
      return null;
    }

    if (selection.mediaType == PostMediaType.video) {
      return _validatePickedVideo(picked);
    }

    return picked;
  }

  Future<XFile?> _invokeMediaPicker(_MediaSelection selection) {
    if (selection.mediaType == PostMediaType.image) {
      return _imagePicker.pickImage(source: selection.source, imageQuality: 88);
    }

    return _imagePicker.pickVideo(
      source: selection.source,
      maxDuration:
          selection.source == ImageSource.camera
              ? kMaxVideoRecordingDuration
              : null,
    );
  }

  Future<Duration?> _readVideoDuration(String path) async {
    final controller = VideoPlayerController.file(File(path));
    try {
      await controller.initialize();
      return controller.value.duration;
    } finally {
      await controller.dispose();
    }
  }

  Future<XFile?> _validatePickedVideo(XFile video) async {
    Duration? duration;
    try {
      duration = await _readVideoDuration(video.path);
    } on Exception {
      duration = null;
    }

    if (!mounted) {
      return null;
    }

    if (duration == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('動画を確認できませんでした')));
      return null;
    }

    if (isVideoTooLong(duration)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('動画は5秒以内で撮影してください')));
      return null;
    }

    return video;
  }

  Widget _buildWorldMode() {
    final builder = widget.worldModeBuilder;
    if (builder != null) {
      return builder();
    }
    return WorldModeScreen(key: _worldModeKey);
  }

  Widget _buildBodyListView() {
    return ListView(
      physics:
          _selectedMode == TopicMode.world
              ? const AlwaysScrollableScrollPhysics()
              : null,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 96),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'Topit',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: _ModeTabs(
            selectedMode: _selectedMode,
            onSelected: _selectMode,
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child:
              _selectedMode == TopicMode.daily
                  ? _TopicCard(
                    key: ValueKey(_currentTopic?.id ?? 'loading'),
                    topic: _currentTopic,
                    isLoading: _isLoadingTopic,
                    onStartPost: _openPostScreen,
                    onRefresh: _refreshTopic,
                  )
                  : _selectedMode == TopicMode.travel
                  ? TravelModeScreen(
                    onStartPost: _openTravelPost,
                    onEndTravel: _endTravel,
                    onTravelSessionChanged: _refreshTravelState,
                    sessionStore: widget.travelSessionStore,
                  )
                  : _buildWorldMode(),
        ),
        if (_selectedMode == TopicMode.daily) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilledButton.icon(
              onPressed:
                  _todayDailyRecapPosts.isEmpty ? null : _openDailyRecap,
              icon: const Icon(Icons.auto_stories_outlined),
              label: const Text('今日を振り返る'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (_selectedMode == TopicMode.world)
          const SizedBox.shrink()
        else if (_selectedMode == TopicMode.travel)
          _isLoadingPosts || _isLoadingTripHistory
              ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
              : _travelTripEntries.isEmpty
              ? const _EmptyTravelHistoryCard()
              : _TravelTripList(
                entries: _travelTripEntries,
                posts: _posts,
                onTapTrip: _openTravelTripDetail,
              )
        else if (_isLoadingPosts)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_visiblePosts.isEmpty)
          const _EmptyPhotoAlbumCard()
        else
          PostTimeline(
            posts: _visiblePosts,
            onEditPost: _editPost,
            onDeletePost: _deletePost,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton:
          _selectedMode == TopicMode.daily
              ? FloatingActionButton(
                onPressed: _openPostScreen,
                tooltip: '写真を撮る',
                shape: const CircleBorder(),
                child: const Icon(Icons.photo_camera_outlined),
              )
              : null,
      body: SafeArea(
        child:
            _selectedMode == TopicMode.world
                ? RefreshIndicator(
                  onRefresh: () async {
                    await _worldModeKey.currentState?.refresh();
                  },
                  child: _buildBodyListView(),
                )
                : _buildBodyListView(),
      ),
    );
  }
}

class _MediaSelection {
  const _MediaSelection(this.source, this.mediaType);

  final ImageSource source;
  final PostMediaType mediaType;
}

class _ImageSourceOption extends StatelessWidget {
  const _ImageSourceOption({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeTabs extends StatelessWidget {
  const _ModeTabs({required this.selectedMode, required this.onSelected});

  final TopicMode selectedMode;
  final ValueChanged<TopicMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<TopicMode>(
        segments: const [
          ButtonSegment<TopicMode>(
            value: TopicMode.daily,
            label: Text('日常'),
            icon: Icon(Icons.wb_sunny_outlined),
          ),
          ButtonSegment<TopicMode>(
            value: TopicMode.travel,
            label: Text('旅行'),
            icon: Icon(Icons.flight_takeoff_outlined),
          ),
          ButtonSegment<TopicMode>(
            value: TopicMode.world,
            label: Text('世界'),
            icon: Icon(Icons.public_outlined),
          ),
        ],
        selected: {selectedMode},
        onSelectionChanged: (selection) => onSelected(selection.first),
        style: ButtonStyle(
          visualDensity: VisualDensity.comfortable,
          textStyle: WidgetStateProperty.all(
            Theme.of(context).textTheme.labelLarge,
          ),
        ),
      ),
    );
  }
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({
    super.key,
    required this.topic,
    required this.isLoading,
    required this.onStartPost,
    required this.onRefresh,
  });

  final Topic? topic;
  final bool isLoading;
  final VoidCallback onStartPost;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '今日のお題',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child:
                  isLoading && topic == null
                      ? const LinearProgressIndicator()
                      : Column(
                        key: ValueKey(topic?.id),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            topic?.text ?? 'お題を準備しています',
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (topic?.hint case final hint?
                              when hint.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              hint,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onPrimaryContainer
                                    .withValues(alpha: 0.72),
                              ),
                            ),
                          ],
                        ],
                      ),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final useVerticalLayout = constraints.maxWidth < 320;
                final captureButton = FilledButton.icon(
                  onPressed: topic == null ? null : onStartPost,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('撮影する'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2F8F76),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                );
                final refreshButton = OutlinedButton.icon(
                  onPressed: isLoading ? null : onRefresh,
                  icon: const Icon(Icons.shuffle),
                  label: const Text('別のお題を見る'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.78,
                    ),
                    backgroundColor: Colors.white.withValues(alpha: 0.78),
                    side: BorderSide(
                      color: colorScheme.onPrimaryContainer.withValues(
                        alpha: 0.2,
                      ),
                    ),
                    minimumSize: const Size.fromHeight(48),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                );

                if (useVerticalLayout) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      captureButton,
                      const SizedBox(height: 10),
                      refreshButton,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: captureButton),
                    const SizedBox(width: 10),
                    Expanded(child: refreshButton),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TravelTripListEntry {
  const _TravelTripListEntry({required this.record, required this.isActive});

  final TravelTripRecord record;
  final bool isActive;
}

class _TravelTripList extends StatelessWidget {
  const _TravelTripList({
    required this.entries,
    required this.posts,
    required this.onTapTrip,
  });

  final List<_TravelTripListEntry> entries;
  final List<DailyPost> posts;
  final Future<void> Function(TravelTripRecord trip, {required bool isActive})
  onTapTrip;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final entry in entries) ...[
          _TravelTripCard(
            entry: entry,
            photoCount: tripRecapPosts(posts, entry.record.id).length,
            onTap:
                () => onTapTrip(entry.record, isActive: entry.isActive),
          ),
          if (entry != entries.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _TravelTripCard extends StatelessWidget {
  const _TravelTripCard({
    required this.entry,
    required this.photoCount,
    required this.onTap,
  });

  final _TravelTripListEntry entry;
  final int photoCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final record = entry.record;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (entry.isActive)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '進行中',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      record.itinerary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _formatPeriod(record.startedAt, record.endedAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '写真 $photoCount 枚',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatPeriod(DateTime startedAt, DateTime endedAt) {
    String format(DateTime value) {
      final local = value.toLocal();
      return '${local.year}/${local.month}/${local.day}';
    }

    final start = format(startedAt);
    final end = format(endedAt);
    if (start == end) {
      return start;
    }
    return '$start 〜 $end';
  }
}

class _EmptyTravelHistoryCard extends StatelessWidget {
  const _EmptyTravelHistoryCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 220),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flight_takeoff_outlined,
              size: 56,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 18),
            Text(
              'まだ旅の記録はありません',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '旅を始めて、終了するとここに記録が残ります',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPhotoAlbumCard extends StatelessWidget {
  const _EmptyPhotoAlbumCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 280),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_camera_outlined,
              size: 56,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 18),
            Text(
              'まだ写真はありません',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '気が向いたら今日のひとコマを残してみよう',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
