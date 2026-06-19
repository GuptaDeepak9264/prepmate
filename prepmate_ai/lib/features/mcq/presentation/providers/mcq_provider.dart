import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/mcq_entity.dart';
import '../../../ai_chat/data/repositories/chat_repository.dart';
import '../../../ai_chat/presentation/providers/chat_provider.dart';
import '../../../../core/constants/app_constants.dart';

// ─── MCQ Generation ───────────────────────────────────────────────────────────

class McqGenerationState {
  final bool isLoading;
  final List<McqQuestion> questions;
  final String? error;

  const McqGenerationState({
    this.isLoading = false,
    this.questions = const [],
    this.error,
  });

  McqGenerationState copyWith({
    bool? isLoading,
    List<McqQuestion>? questions,
    String? error,
  }) =>
      McqGenerationState(
        isLoading: isLoading ?? this.isLoading,
        questions: questions ?? this.questions,
        error: error,
      );
}

class McqGeneratorNotifier extends StateNotifier<McqGenerationState> {
  final AiService _ai;
  final _uuid = const Uuid();

  McqGeneratorNotifier(this._ai) : super(const McqGenerationState());

  Future<List<McqQuestion>?> generateQuestions({
    required String topic,
    required String difficulty,
    required int count,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final prompt = '''
Generate $count multiple-choice questions about "$topic" at $difficulty difficulty.

Return ONLY a valid JSON array. Each object must have:
- "id": unique string
- "question": the question text
- "options": array of exactly 4 strings (A, B, C, D answers)
- "correctIndex": integer 0-3 (index of correct option)
- "explanation": brief explanation of the correct answer

Example format:
[{"id":"q1","question":"What is...?","options":["A","B","C","D"],"correctIndex":2,"explanation":"Because..."}]

Return ONLY the JSON array, no other text.
''';

      final raw = await _ai.sendMessage(
        history: [],
        newMessage: prompt,
        systemPrompt:
            'You are an expert question generator. Return only valid JSON arrays.',
      );

      // Strip markdown code fences if present
      var clean = raw.trim();
      if (clean.startsWith('```')) {
        clean = clean
            .replaceAll(RegExp(r'^```[a-z]*\n?'), '')
            .replaceAll(RegExp(r'\n?```$'), '');
      }

      final List<dynamic> parsed = jsonDecode(clean) as List<dynamic>;
      final questions = parsed
          .map((m) => McqQuestion.fromMap(m as Map<String, dynamic>))
          .toList();

      state = state.copyWith(isLoading: false, questions: questions);
      return questions;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error:
            'Failed to generate questions. Check AI service configuration.',
      );
      return null;
    }
  }

  void reset() => state = const McqGenerationState();
}

final mcqGeneratorProvider =
    StateNotifierProvider<McqGeneratorNotifier, McqGenerationState>(
  (ref) => McqGeneratorNotifier(ref.read(aiServiceProvider)),
);

// ─── Active MCQ Session ───────────────────────────────────────────────────────

class ActiveMcqState {
  final List<McqQuestion> questions;
  final int currentIndex;
  final bool isFinished;

  const ActiveMcqState({
    this.questions = const [],
    this.currentIndex = 0,
    this.isFinished = false,
  });

  McqQuestion? get current =>
      currentIndex < questions.length ? questions[currentIndex] : null;
  bool get isLast => currentIndex == questions.length - 1;
  int get score => questions.where((q) => q.isCorrect).length;

  ActiveMcqState copyWith({
    List<McqQuestion>? questions,
    int? currentIndex,
    bool? isFinished,
  }) =>
      ActiveMcqState(
        questions: questions ?? this.questions,
        currentIndex: currentIndex ?? this.currentIndex,
        isFinished: isFinished ?? this.isFinished,
      );
}

class ActiveMcqNotifier extends StateNotifier<ActiveMcqState> {
  ActiveMcqNotifier() : super(const ActiveMcqState());

  void startSession(List<McqQuestion> questions) {
    state = ActiveMcqState(questions: questions);
  }

  void selectAnswer(int optionIndex) {
    if (state.current == null || state.current!.isAnswered) return;
    final updated = List<McqQuestion>.from(state.questions);
    updated[state.currentIndex] =
        updated[state.currentIndex].copyWith(selectedIndex: optionIndex);
    state = state.copyWith(questions: updated);
  }

  void nextQuestion() {
    if (state.isLast) {
      state = state.copyWith(isFinished: true);
    } else {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    }
  }

  void reset() => state = const ActiveMcqState();
}

final activeMcqProvider =
    StateNotifierProvider<ActiveMcqNotifier, ActiveMcqState>(
  (ref) => ActiveMcqNotifier(),
);

// ─── MCQ Sessions History ─────────────────────────────────────────────────────

final mcqSessionHistoryProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      return FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .collection(AppConstants.mcqSessionsCollection)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots()
          .map((snap) => snap.docs.map((d) => d.data()).toList());
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

// ─── Save MCQ Session ─────────────────────────────────────────────────────────

final saveMcqSessionProvider =
    FutureProvider.family<void, McqSession>((ref, session) async {
  final user = await ref.read(authStateProvider.future);
  if (user == null) return;
  await FirebaseFirestore.instance
      .collection(AppConstants.usersCollection)
      .doc(user.uid)
      .collection(AppConstants.mcqSessionsCollection)
      .doc(session.id)
      .set(session.toMap());
});
