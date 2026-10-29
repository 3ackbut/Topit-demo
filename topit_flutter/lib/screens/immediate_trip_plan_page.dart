import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/immediate_trip.dart';
import '../models/travel_place.dart';
import '../services/immediate_trip_logic.dart';
import '../services/immediate_trip_session.dart';
import '../services/travel_mission_service.dart';
import '../services/travel_session_store.dart';

class ImmediateTripPlanPage extends StatefulWidget {
  const ImmediateTripPlanPage({
    super.key,
    required this.place,
    this.sessionStore,
    this.missionService,
  });

  final TravelPlace place;
  final TravelSessionStore? sessionStore;
  final TravelMissionService? missionService;

  @override
  State<ImmediateTripPlanPage> createState() => _ImmediateTripPlanPageState();
}

class _ImmediateTripPlanPageState extends State<ImmediateTripPlanPage> {
  late final ImmediateTripPlan _plan;
  late final TravelSessionStore _sessionStore;
  late final TravelMissionService _missionService;
  bool _isStarting = false;

  @override
  void initState() {
    super.initState();
    _sessionStore =
        widget.sessionStore ?? InMemoryTravelSessionStore();
    _missionService = widget.missionService ?? TravelMissionService();
    _plan = createTripPlan(widget.place, DateTime.now());
  }

  String _formatClock(DateTime time) {
    final local = time.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _openMap() async {
    final place = widget.place;
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1'
      '&query=${place.coordinates.latitude},${place.coordinates.longitude}',
    );
    final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('地図アプリを開けませんでした')));
    }
  }

  Future<void> _startTrip() async {
    if (_isStarting) return;
    setState(() => _isStarting = true);
    try {
      final result = await startImmediateTripSession(
        place: widget.place,
        photoMission: _plan.photoMission,
        sessionStore: _sessionStore,
        missionService: _missionService,
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pop(ImmediateTripLaunchResult(usedFallback: result.usedFallback));
    } catch (_) {
      if (!mounted) return;
      setState(() => _isStarting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('旅の開始に失敗しました')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final roundTripCost = calculateRoundTripCost(place);
    final zeroCaution = zeroCostCaution(place);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('旅程の確認')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              place.name,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text('${place.municipality} ／ ${place.transport.mode}'),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _TimelineRow(
                      label: '現在時刻　出発',
                      value: _formatClock(_plan.departureAt),
                    ),
                    _TimelineRow(
                      label: '到着予定',
                      value: _formatClock(_plan.arrivalAt),
                    ),
                    _TimelineRow(
                      label: '現地滞在',
                      value:
                          '${_formatClock(_plan.arrivalAt)}〜${_formatClock(_plan.leavePlaceAt)}'
                          '（${formatMinutes(place.recommendedStayMinutes)}）',
                    ),
                    _TimelineRow(
                      label: '現地を出発',
                      value: _formatClock(_plan.leavePlaceAt),
                    ),
                    _TimelineRow(
                      label: '盛岡駅付近へ帰着予定',
                      value: _formatClock(_plan.returnAt),
                    ),
                    _TimelineRow(
                      label: '予備時間込みの終了予定',
                      value: _formatClock(_plan.returnWithBufferAt),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('往復移動費: $roundTripCost円'),
            if (zeroCaution != null) ...[
              const SizedBox(height: 4),
              Text(
                zeroCaution,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _openMap,
              icon: const Icon(Icons.map_outlined),
              label: const Text('地図で確認'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '地図上の位置は概略です',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '撮影お題の参考',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              '旅を始めると、この行き先をもとにAIがお題を3つ作成します。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _plan.photoMission,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isStarting ? null : _startTrip,
              icon:
                  _isStarting
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.play_arrow),
              label: Text(_isStarting ? 'お題を作成中…' : 'この旅を始める'),
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

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
