
import 'package:flutter/material.dart';

import '../models/mission.dart';
import '../models/travel_session.dart';
import '../services/immediate_trip_session.dart';
import '../services/travel_mission_service.dart';
import '../services/travel_session_store.dart';
import 'immediate_trip_search_page.dart';

class TravelModeScreen extends StatefulWidget {
  const TravelModeScreen({
    super.key,
    required this.onStartPost,
    required this.onEndTravel,
    this.onTravelSessionChanged,
    this.missionService,
    this.sessionStore,
  });

  final Future<bool> Function(TravelSession session, Mission mission)
  onStartPost;
  final Future<void> Function(TravelSession session) onEndTravel;
  final VoidCallback? onTravelSessionChanged;
  final TravelMissionService? missionService;
  final TravelSessionStore? sessionStore;

  @override
  State<TravelModeScreen> createState() => _TravelModeScreenState();
}

class _TravelModeScreenState extends State<TravelModeScreen> {
  late final TravelMissionService _missionService;
  late final TravelSessionStore _sessionStore;
  final _itineraryController = TextEditingController();
  final _itineraryFieldKey = GlobalKey();
  TravelSession? _session;
  String? _inputError;
  String? _notice;
  bool _isLoading = true;
  bool _isGenerating = false;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _missionService = widget.missionService ?? TravelMissionService();
    _sessionStore =
        widget.sessionStore ?? InMemoryTravelSessionStore();
    _restoreSession();
  }

  @override
  void dispose() {
    _itineraryController.dispose();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    final session = await _sessionStore.load();
    if (!mounted) return;
    setState(() {
      _session = session;
      _isLoading = false;
    });
    if (session != null) {
      widget.onTravelSessionChanged?.call();
    }
  }

  Future<void> _startTravel() async {
    final itinerary = _itineraryController.text.trim();
    if (itinerary.isEmpty) {
      setState(() => _inputError = '旅程を入力してください');
      return;
    }
    if (itinerary.length > 2000) {
      setState(() => _inputError = '旅程は2000文字以内で入力してください');
      return;
    }
    setState(() {
      _inputError = null;
      _notice = null;
      _isGenerating = true;
    });
    final result = await _missionService.fetchTravelMissionResult(
      itinerary: itinerary,
    );
    final now = DateTime.now();
    final session = TravelSession(
      id: 'trip-${now.millisecondsSinceEpoch}',
      itinerary: itinerary,
      startedAt: now,
      missions: result.missions,
      currentMissionIndex: 0,
      previousTitles: result.missions.map((mission) => mission.title).toList(),
    );
    await _sessionStore.save(session);
    if (!mounted) return;
    setState(() {
      _session = session;
      _isGenerating = false;
      _notice = result.usedFallback ? 'UI表示用のサンプルお題です' : null;
    });
    widget.onTravelSessionChanged?.call();
  }

  void _showNextMission() {
    final session = _session;
    if (session == null || _isGenerating || _isPosting) return;
    final nextIndex = _nextIncompleteIndex(
      session,
      session.currentMissionIndex,
    );
    if (nextIndex == session.currentMissionIndex) return;
    final next = session.copyWith(currentMissionIndex: nextIndex);
    _sessionStore.save(next);
    setState(() => _session = next);
  }

  Future<void> _startPost() async {
    final session = _session;
    if (session == null || _isGenerating || _isPosting) return;
    final mission = session.missions[session.currentMissionIndex];
    setState(() => _isPosting = true);
    final posted = await widget.onStartPost(session, mission);
    if (!mounted) return;
    if (!posted) {
      setState(() => _isPosting = false);
      return;
    }
    final completed =
        {
            ...session.completedMissionIndexes,
            session.currentMissionIndex,
          }.toList()
          ..sort();
    if (completed.length == session.missions.length) {
      await _generateNextSet(session);
      return;
    }
    final updated = session.copyWith(
      completedMissionIndexes: completed,
      currentMissionIndex: _nextIncompleteIndex(
        session.copyWith(completedMissionIndexes: completed),
        session.currentMissionIndex,
      ),
    );
    await _sessionStore.save(updated);
    if (!mounted) return;
    setState(() {
      _session = updated;
      _isPosting = false;
    });
    widget.onTravelSessionChanged?.call();
  }

  Future<void> _generateNextSet(TravelSession session) async {
    setState(() => _isGenerating = true);
    final result = await _missionService.fetchTravelMissionResult(
      itinerary: session.itinerary,
      previousTitles: session.previousTitles,
    );
    final updated = session.copyWith(
      missions: result.missions,
      currentMissionIndex: 0,
      completedMissionIndexes: const [],
      previousTitles: [
        ...session.previousTitles,
        ...result.missions.map((m) => m.title),
      ],
    );
    await _sessionStore.save(updated);
    if (!mounted) return;
    setState(() {
      _session = updated;
      _isGenerating = false;
      _isPosting = false;
      _notice = result.usedFallback ? 'UI表示用のサンプルお題です' : null;
    });
    widget.onTravelSessionChanged?.call();
  }

  int _nextIncompleteIndex(TravelSession session, int from) {
    for (var offset = 1; offset <= session.missions.length; offset++) {
      final index = (from + offset) % session.missions.length;
      if (!session.completedMissionIndexes.contains(index)) return index;
    }
    return from;
  }

  Future<void> _endTravel() async {
    final session = _session;
    if (session == null || _isGenerating || _isPosting) {
      return;
    }

    await widget.onEndTravel(session);
    if (!mounted) return;
    _itineraryController.clear();
    setState(() {
      _session = null;
      _notice = null;
      _inputError = null;
    });
    widget.onTravelSessionChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final session = _session;
    return session == null
        ? _buildStartForm(context)
        : _buildMission(context, session);
  }

  Future<void> _openImmediateTrip() async {
    final launchResult = await Navigator.of(
      context,
    ).push<ImmediateTripLaunchResult>(
      MaterialPageRoute<ImmediateTripLaunchResult>(
        builder: (_) => const ImmediateTripSearchPage(),
      ),
    );
    if (launchResult != null && mounted) {
      await _restoreSession();
      if (!mounted) return;
      if (launchResult.usedFallback) {
        setState(() {
          _notice = 'UI表示用のサンプルお題です';
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildStartForm(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Card(
          elevation: 0,
          clipBehavior: Clip.antiAlias,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEAF7F4), Color(0xFFF8FCFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD8EFE7),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.landscape_rounded,
                          color: Color(0xFF2F8068),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '岩手・盛岡駅発',
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(
                            color: const Color(0xFF2F8068),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '盛岡駅から岩手をめぐる',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '盛岡駅から、今行ける岩手の魅力を見つけよう',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed:
                        _isGenerating ? null : _openImmediateTrip,
                    icon: const Icon(Icons.directions_walk),
                    label: const Text('今から出発'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: const Color(0xFF2F8068),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '旅のお題を作る',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'このUI版では、入力内容に関係なくサンプルのお題を3つ表示します。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  key: _itineraryFieldKey,
                  controller: _itineraryController,
                  minLines: 4,
                  maxLines: 7,
                  maxLength: 2000,
                  enabled: !_isGenerating,
                  decoration: InputDecoration(
                    labelText: '旅程',
                    hintText: '例：盛岡駅から盛岡城跡公園へ行き、その後食事をする',
                    errorText: _inputError,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) {
                    if (_inputError != null) setState(() => _inputError = null);
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('写真から入力（停止中）'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '例:\n・今日は岩手県を旅行する\n・盛岡駅周辺を歩く\n・14時に盛岡城跡公園へ行く',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed:
                      _isGenerating ? null : _startTravel,
                  icon:
                      _isGenerating
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.auto_awesome_outlined),
                  label: Text(_isGenerating ? 'お題を作成中…' : '旅のお題を作る'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMission(BuildContext context, TravelSession session) {
    final mission = session.missions[session.currentMissionIndex];
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_notice != null) ...[
          MaterialBanner(
            content: Text(_notice!),
            leading: const Icon(Icons.info_outline),
            actions: [
              TextButton(
                onPressed: () => setState(() => _notice = null),
                child: const Text('閉じる'),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
        Card(
          elevation: 0,
          color: colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '今回の旅程',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  session.itinerary,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '旅のお題',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  mission.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                _MissionDetail(label: 'ヒント', text: mission.hint),
                const SizedBox(height: 10),
                _MissionDetail(label: '撮影のコツ', text: mission.shootingTip),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  children: [
                    Chip(label: Text('難易度 ${mission.difficulty}')),
                    Chip(label: Text('約${mission.estimatedMinutes}分')),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '${session.completedMissionIndexes.length}/3件を投稿済み',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.72,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed:
                      _isGenerating || _isPosting ? null : _showNextMission,
                  icon: const Icon(Icons.shuffle),
                  label: const Text('別のお題'),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _isGenerating || _isPosting ? null : _startPost,
                  icon:
                      _isPosting
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.photo_camera_outlined),
                  label: Text(_isPosting ? '投稿しています…' : '撮影を始める'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _isGenerating || _isPosting ? null : _endTravel,
          icon: const Icon(Icons.close),
          label: const Text('旅行を終了'),
        ),
      ],
    );
  }
}

class _MissionDetail extends StatelessWidget {
  const _MissionDetail({required this.label, required this.text});
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 3),
      Text(text),
    ],
  );
}
