class IwateQuizQuestion {
  final String id;
  final String question;
  final List<String> choices;
  final int correctIndex;

  const IwateQuizQuestion({
    required this.id,
    required this.question,
    required this.choices,
    required this.correctIndex,
  });
}
