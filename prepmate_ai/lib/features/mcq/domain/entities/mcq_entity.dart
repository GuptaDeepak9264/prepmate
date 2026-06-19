import 'package:equatable/equatable.dart';

class McqQuestion extends Equatable {
  final String id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final int? selectedIndex;

  const McqQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.selectedIndex,
  });

  bool get isAnswered => selectedIndex != null;
  bool get isCorrect => selectedIndex == correctIndex;

  McqQuestion copyWith({int? selectedIndex}) => McqQuestion(
        id: id,
        question: question,
        options: options,
        correctIndex: correctIndex,
        explanation: explanation,
        selectedIndex: selectedIndex ?? this.selectedIndex,
      );

  factory McqQuestion.fromMap(Map<String, dynamic> map) => McqQuestion(
        id: map['id'] as String? ?? '',
        question: map['question'] as String? ?? '',
        options: (map['options'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        correctIndex: map['correctIndex'] as int? ?? 0,
        explanation: map['explanation'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'question': question,
        'options': options,
        'correctIndex': correctIndex,
        'explanation': explanation,
      };

  @override
  List<Object?> get props => [id, question, selectedIndex];
}

class McqSession extends Equatable {
  final String id;
  final String topic;
  final String difficulty;
  final List<McqQuestion> questions;
  final DateTime createdAt;

  const McqSession({
    required this.id,
    required this.topic,
    required this.difficulty,
    required this.questions,
    required this.createdAt,
  });

  int get score => questions.where((q) => q.isCorrect).length;
  int get total => questions.length;
  double get accuracy => total > 0 ? score / total : 0.0;

  Map<String, dynamic> toMap() => {
        'topic': topic,
        'difficulty': difficulty,
        'score': score,
        'total': total,
        'questions': questions.map((q) => q.toMap()).toList(),
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  @override
  List<Object?> get props => [id, topic, score];
}
