import 'package:flutter/material.dart';

import '../data/iwate_quiz_questions.dart';
import '../models/immediate_trip.dart';
import '../models/travel_place.dart';
import '../services/immediate_trip_logic.dart';
import '../services/immediate_trip_session.dart';
import '../services/iwate_score_store.dart';
import '../services/travel_places_repository.dart';
import 'immediate_trip_result_page.dart';

class ImmediateTripSearchPage extends StatefulWidget {
  const ImmediateTripSearchPage({
    super.key,
    this.repository,
    this.iwateScoreStore,
  });

  final TravelPlacesRepository? repository;
  final IwateScoreStore? iwateScoreStore;

  @override
  State<ImmediateTripSearchPage> createState() =>
      _ImmediateTripSearchPageState();
}

enum _SearchStep { conditions, quiz, quizResult }

class _ImmediateTripSearchPageState extends State<ImmediateTripSearchPage> {
  late final TravelPlacesRepository _repository;
  late final IwateScoreStore _iwateScoreStore;
  _SearchStep _step = _SearchStep.conditions;

  List<TravelPlace>? _places;
  String? _loadError;
  bool _isLoading = true;

  int _availableMinutes = 120;
  int _maxRoundTripCostYen = 1000;
  Set<TravelMode> _availableModes = {
    TravelMode.walking,
    TravelMode.publicTransit,
  };

  int _quizIndex = 0;
  final Map<String, int> _quizAnswers = {};
  List<ShuffledIwateQuizQuestion> _shuffledQuestions = [];
  double? _iwateScore;
  double? _targetNicheLevel;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? TravelPlacesRepository();
    _iwateScoreStore = widget.iwateScoreStore ?? InMemoryIwateScoreStore();
    _loadPlaces();
    _loadSavedIwateScore();
  }

  Future<void> _loadSavedIwateScore() async {
    final saved = await _iwateScoreStore.load();
    if (!mounted || saved == null) return;
    setState(() {
      _iwateScore = saved.score;
      _targetNicheLevel = saved.targetNicheLevel;
    });
  }

  Future<void> _loadPlaces() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    final result = await _repository.load();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _places = result.places;
        _loadError = null;
      } else {
        _places = null;
        _loadError = result.errorMessage;
      }
    });
  }

  bool get _canSearch => _availableModes.isNotEmpty && _places != null;

  bool get _hasSavedIwateScore => _iwateScore != null && _targetNicheLevel != null;

  ImmediateTripSearchCondition get _condition => ImmediateTripSearchCondition(
    availableMinutes: _availableMinutes,
    maxRoundTripCostYen: _maxRoundTripCostYen,
    availableModes: Set<TravelMode>.from(_availableModes),
    targetNicheLevel: _targetNicheLevel,
  );

  void _applyCondition(ImmediateTripSearchCondition condition) {
    setState(() {
      _availableMinutes = condition.availableMinutes;
      _maxRoundTripCostYen = condition.maxRoundTripCostYen;
      _availableModes = Set<TravelMode>.from(condition.availableModes);
    });
  }

  Future<void> _runSearch({
    ImmediateTripSearchType searchType = ImmediateTripSearchType.standard,
  }) async {
    final places = _places;
    if (places == null || !_canSearch) return;

    final condition =
        searchType == ImmediateTripSearchType.iwateQuiz
            ? _condition.copyWith(targetNicheLevel: _targetNicheLevel)
            : _condition.copyWith(targetNicheLevel: null);

    final filtered = filterPlaces(places, condition);
    final randomValues = generateSearchRandomValues(places);
    final ranked = rankPlaces(
      filtered: filtered,
      condition: condition,
      searchType: searchType,
      randomValues: randomValues,
    );
    final nearMisses =
        ranked.isEmpty
            ? findNearMissPlaces(places, condition)
            : const <TravelPlace>[];
    final suggestions =
        ranked.isEmpty
            ? findConditionSuggestions(places, condition)
            : const <ConditionSuggestion>[];

    if (!mounted) return;

    while (mounted) {
      final result = await Navigator.of(context).push<Object?>(
        MaterialPageRoute<Object?>(
          builder:
              (_) => ImmediateTripResultPage(
                matches: ranked,
                nearMisses: nearMisses,
                suggestions: suggestions,
                condition: condition,
                searchType: searchType,
                iwateScore:
                    searchType == ImmediateTripSearchType.iwateQuiz
                        ? _iwateScore
                        : null,
              ),
        ),
      );

      if (!mounted) return;

      if (result is ImmediateTripLaunchResult) {
        Navigator.of(context).pop(result);
        return;
      }

      if (result is ImmediateTripConditionUpdate) {
        _applyCondition(result.condition);
        await _runSearch(searchType: searchType);
        return;
      }

      return;
    }
  }

  void _startQuizSearch() {
    setState(() {
      _step = _SearchStep.quiz;
      _quizIndex = 0;
      _quizAnswers.clear();
      _shuffledQuestions = shuffleIwateQuizQuestions(iwateQuizQuestions);
    });
  }

  Future<void> _saveIwateScore() async {
    final score = _iwateScore;
    final targetNicheLevel = _targetNicheLevel;
    if (score == null || targetNicheLevel == null) return;
    await _iwateScoreStore.save(
      SavedIwateScore(
        score: score,
        targetNicheLevel: targetNicheLevel,
        measuredAt: DateTime.now(),
      ),
    );
  }

  Future<void> _answerQuiz(int choiceIndex) async {
    final shuffled = _shuffledQuestions[_quizIndex];
    final question = shuffled.question;
    var finished = false;
    setState(() {
      _quizAnswers[question.id] = choiceIndex;
      if (_quizIndex < _shuffledQuestions.length - 1) {
        _quizIndex += 1;
      } else {
        var correct = 0;
        for (final item in _shuffledQuestions) {
          if (_quizAnswers[item.question.id] == item.shuffledCorrectIndex) {
            correct += 1;
          }
        }
        _iwateScore = calculateIwateScore(
          correctAnswers: correct,
          totalQuestions: _shuffledQuestions.length,
        );
        _targetNicheLevel = targetNicheLevelFromIwateScore(_iwateScore!);
        _step = _SearchStep.quizResult;
        finished = true;
      }
    });

    if (finished) {
      await _saveIwateScore();
    }
  }

  void _goBackInQuiz() {
    if (_quizIndex == 0) {
      setState(() => _step = _SearchStep.conditions);
      return;
    }
    setState(() => _quizIndex -= 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_appBarTitle),
        leading:
            _step == _SearchStep.quiz
                ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _goBackInQuiz,
                )
                : null,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
              ? _buildLoadError(context)
              : SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_step == _SearchStep.conditions) ..._buildConditions(),
                    if (_step == _SearchStep.quiz) ..._buildQuiz(),
                    if (_step == _SearchStep.quizResult) ..._buildQuizResult(),
                  ],
                ),
              ),
    );
  }

  String get _appBarTitle {
    switch (_step) {
      case _SearchStep.conditions:
        return '条件を探す';
      case _SearchStep.quiz:
        return '岩手度クイズ';
      case _SearchStep.quizResult:
        return '岩手度の結果';
    }
  }

  Widget _buildLoadError(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _loadError!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _loadPlaces, child: const Text('再試行')),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildConditions() => [
    Text(
      '旅に使える時間',
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 4),
    Text(
      formatMinutes(_availableMinutes),
      style: Theme.of(
        context,
      ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
    ),
    Text(
      '往復と現地滞在を含む総時間',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
    Slider(
      value: _availableMinutes.toDouble(),
      min: 30,
      max: 480,
      divisions: 15,
      label: formatMinutes(_availableMinutes),
      onChanged: (value) {
        setState(() {
          _availableMinutes = ((value / 30).round() * 30).clamp(30, 480);
        });
      },
    ),
    const SizedBox(height: 12),
    Text(
      '往復移動費の予算',
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          costOptions.map((cost) {
            final selected = cost == _maxRoundTripCostYen;
            return ChoiceChip(
              label: Text(cost == 0 ? '0円' : '$cost円'),
              selected: selected,
              onSelected: (_) {
                setState(() => _maxRoundTripCostYen = cost);
              },
            );
          }).toList(),
    ),
    const SizedBox(height: 8),
    Text(
      '入場料、飲食代、ガソリン代、駐車料金、自転車レンタル料金などは含まれない場合があります。',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
    const SizedBox(height: 20),
    Text(
      '移動手段',
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 8),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          TravelMode.values.map((mode) {
            final selected = _availableModes.contains(mode);
            return FilterChip(
              label: Text(travelModeLabel(mode)),
              selected: selected,
              onSelected: (value) {
                setState(() {
                  if (value) {
                    _availableModes = {..._availableModes, mode};
                  } else {
                    _availableModes = {..._availableModes}..remove(mode);
                  }
                });
              },
            );
          }).toList(),
    ),
    if (_availableModes.isEmpty) ...[
      const SizedBox(height: 8),
      Text(
        '移動手段を1つ以上選んでください',
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    ],
    const SizedBox(height: 24),
    FilledButton(
      onPressed: _canSearch ? () => _runSearch() : null,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      child: const Text('旅を探す'),
    ),
    const SizedBox(height: 10),
    if (_hasSavedIwateScore) ...[
      Text(
        '岩手度 ${_iwateScore!.round()}点（前回の測定）',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 8),
    ],
    GestureDetector(
      onLongPress:
          _hasSavedIwateScore && _canSearch ? _startQuizSearch : null,
      child: OutlinedButton(
        onPressed:
            _canSearch
                ? () {
                  if (_hasSavedIwateScore) {
                    _runSearch(searchType: ImmediateTripSearchType.iwateQuiz);
                  } else {
                    _startQuizSearch();
                  }
                }
                : null,
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: Text(
          _hasSavedIwateScore ? '🐻 岩手度を利用して探す' : '🐻 岩手度を測定して探す',
        ),
      ),
    ),
    if (_hasSavedIwateScore) ...[
      const SizedBox(height: 6),
      Text(
        '長押しで岩手度を再測定',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  ];

  List<Widget> _buildQuiz() {
    final shuffled = _shuffledQuestions[_quizIndex];
    final question = shuffled.question;
    final selected = _quizAnswers[question.id];
    return [
      Text(
        '${_quizIndex + 1} / ${_shuffledQuestions.length}',
        style: Theme.of(context).textTheme.labelLarge,
      ),
      const SizedBox(height: 12),
      Text(
        question.question,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 20),
      ...List.generate(shuffled.shuffledChoices.length, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: OutlinedButton(
            onPressed: () => _answerQuiz(index),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              alignment: Alignment.centerLeft,
              backgroundColor:
                  selected == index
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
            ),
            child: Text(shuffled.shuffledChoices[index]),
          ),
        );
      }),
    ];
  }

  List<Widget> _buildQuizResult() {
    final score = _iwateScore ?? 0;
    final correct =
        _shuffledQuestions
            .where(
              (item) =>
                  _quizAnswers[item.question.id] == item.shuffledCorrectIndex,
            )
            .length;
    return [
      Text('あなたの岩手度', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Text(
        '${score.round()}点',
        style: Theme.of(
          context,
        ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text('$correct / ${_shuffledQuestions.length} 問正解'),
      const SizedBox(height: 8),
      Text(
        '目標マニアック度: ${_targetNicheLevel?.toStringAsFixed(1)}',
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      const SizedBox(height: 12),
      Text(
        'マニアック度は絞り込みではなく、おすすめ順の参考に使います。',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 20),
      ..._shuffledQuestions.map((item) {
        final question = item.question;
        final answer = _quizAnswers[question.id];
        final isCorrect = answer == item.shuffledCorrectIndex;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            color:
                isCorrect ? Colors.green : Theme.of(context).colorScheme.error,
          ),
          title: Text(question.question),
          subtitle: Text(
            '正解: ${item.shuffledChoices[item.shuffledCorrectIndex]}'
            '${answer != null && !isCorrect ? '\nあなたの回答: ${item.shuffledChoices[answer]}' : ''}',
          ),
        );
      }),
      const SizedBox(height: 16),
      FilledButton(
        onPressed:
            _canSearch
                ? () => _runSearch(searchType: ImmediateTripSearchType.iwateQuiz)
                : null,
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        child: const Text('この岩手度で旅を探す'),
      ),
    ];
  }
}
