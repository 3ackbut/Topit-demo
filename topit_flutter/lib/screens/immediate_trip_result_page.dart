import 'package:flutter/material.dart';

import '../models/immediate_trip.dart';
import '../models/travel_place.dart';
import '../services/immediate_trip_logic.dart';
import '../services/immediate_trip_session.dart';
import 'immediate_trip_plan_page.dart';

class ImmediateTripResultPage extends StatelessWidget {
  const ImmediateTripResultPage({
    super.key,
    required this.matches,
    required this.nearMisses,
    required this.suggestions,
    required this.condition,
    required this.searchType,
    this.iwateScore,
  });

  final List<TravelPlace> matches;
  final List<TravelPlace> nearMisses;
  final List<ConditionSuggestion> suggestions;
  final ImmediateTripSearchCondition condition;
  final ImmediateTripSearchType searchType;
  final double? iwateScore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('おすすめの旅')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (iwateScore != null) ...[
              Text(
                '岩手度 ${iwateScore!.round()}点を反映したおすすめ',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
            ],
            if (matches.isEmpty) ..._buildEmpty(context),
            if (matches.isNotEmpty) ...[
              Text(
                '条件に合う旅 ${matches.length}件',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ...matches.map(
                (place) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PlaceResultCard(
                    place: place,
                    selectable: true,
                    onSelect: () => _openPlan(context, place),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildEmpty(BuildContext context) {
    return [
      Text(
        '条件に完全一致する旅が見つかりませんでした',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(
        '超過しない範囲で、旅に使える時間の半分以上を使う候補だけを提案しています。条件を少し変えて、もう一度探してみてください。',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      if (suggestions.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(
          '条件緩和の提案',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...suggestions.map(
          (suggestion) => Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: Text(suggestion.message),
              trailing: const Icon(Icons.chevron_right),
              onTap:
                  () => Navigator.of(context).pop(
                    ImmediateTripConditionUpdate(condition: suggestion.condition),
                  ),
            ),
          ),
        ),
      ],
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('条件を変更する'),
      ),
      if (nearMisses.isNotEmpty) ...[
        const SizedBox(height: 24),
        Text(
          '条件外の近い候補',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          '参考表示のみです。選ぶには条件を変更して再検索してください。',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ...nearMisses.map(
          (place) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PlaceResultCard(place: place, selectable: false),
          ),
        ),
      ],
    ];
  }

  Future<void> _openPlan(BuildContext context, TravelPlace place) async {
    final launchResult = await Navigator.of(
      context,
    ).push<ImmediateTripLaunchResult>(
      MaterialPageRoute<ImmediateTripLaunchResult>(
        builder: (_) => ImmediateTripPlanPage(place: place),
      ),
    );
    if (launchResult != null && context.mounted) {
      Navigator.of(context).pop(launchResult);
    }
  }
}

class _PlaceResultCard extends StatelessWidget {
  const _PlaceResultCard({
    required this.place,
    required this.selectable,
    this.onSelect,
  });

  final TravelPlace place;
  final bool selectable;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    final requiredMinutes = calculateRequiredMinutes(place);
    final roundTripCost = calculateRoundTripCost(place);
    final zeroCaution = zeroCostCaution(place);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color:
          selectable
              ? colorScheme.surfaceContainerHighest
              : colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!selectable) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '条件外',
                  style: TextStyle(
                    color: colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              place.name,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(place.municipality),
            const SizedBox(height: 12),
            _InfoRow(label: '移動手段', value: place.transport.mode),
            _InfoRow(
              label: '片道時間',
              value: formatMinutes(place.transport.oneWayMinutes),
            ),
            _InfoRow(
              label: '推奨滞在時間',
              value: formatMinutes(place.recommendedStayMinutes),
            ),
            _InfoRow(label: '旅全体の所要時間', value: formatMinutes(requiredMinutes)),
            _InfoRow(label: '往復移動費', value: '$roundTripCost円'),
            _InfoRow(label: 'マニアック度', value: '${place.nicheLevel}'),
            const SizedBox(height: 10),
            Text(
              place.recommendation,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (place.seasonNote != null && place.seasonNote!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 18,
                    color: colorScheme.tertiary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      place.seasonNote!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
            if (zeroCaution != null) ...[
              const SizedBox(height: 8),
              Text(
                zeroCaution,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (selectable) ...[
              const SizedBox(height: 14),
              FilledButton(
                onPressed: onSelect,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: const Text('この旅に決める'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
