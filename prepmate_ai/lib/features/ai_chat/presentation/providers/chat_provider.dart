import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/chat_repository.dart';
import '../../domain/entities/chat_entity.dart';

// ─── Repository & Service ─────────────────────────────────────────────────────

final chatRepositoryProvider =
    Provider<ChatRepository>((ref) => ChatRepository());

// NOTE: Inject your real API key here or load from secure storage / env
final aiServiceProvider = Provider<AiService>((ref) {
  return OpenAiService(
    apiKey: const String.fromEnvironment('OPENAI_API_KEY',
        defaultValue: 'YOUR_API_KEY_HERE'),
    model: 'gpt-4o-mini',
  );
});

// ─── Sessions List ────────────────────────────────────────────────────────────

final chatSessionsProvider = StreamProvider<List<ChatSession>>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      return ref.read(chatRepositoryProvider).watchSessions(user.uid);
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

// ─── Active Chat Notifier ─────────────────────────────────────────────────────

class ActiveChatState {
  final String? sessionId;
  final List<ChatMessage> messages;
  final bool isSending;
  final String? error;

  const ActiveChatState({
    this.sessionId,
    this.messages = const [],
    this.isSending = false,
    this.error,
  });

  ActiveChatState copyWith({
    String? sessionId,
    List<ChatMessage>? messages,
    bool? isSending,
    String? error,
  }) =>
      ActiveChatState(
        sessionId: sessionId ?? this.sessionId,
        messages: messages ?? this.messages,
        isSending: isSending ?? this.isSending,
        error: error,
      );
}

class ActiveChatNotifier extends StateNotifier<ActiveChatState> {
  final ChatRepository _repo;
  final AiService _ai;
  final Ref _ref;
  final _uuid = const Uuid();

  ActiveChatNotifier(this._repo, this._ai, this._ref)
      : super(const ActiveChatState());

  void startNewChat() {
    state = const ActiveChatState();
  }

  Future<void> loadSession(String sessionId) async {
    final user = await _ref.read(authStateProvider.future);
    if (user == null) return;
    final session = await _repo.getSession(user.uid, sessionId);
    if (session != null) {
      state = state.copyWith(
        sessionId: sessionId,
        messages: session.messages,
      );
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    final user = await _ref.read(authStateProvider.future);
    if (user == null) return;

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      content: text.trim(),
      role: MessageRole.user,
      timestamp: DateTime.now(),
    );

    // Optimistically add user message + loading placeholder
    final loadingMsg = ChatMessage(
      id: 'loading',
      content: '',
      role: MessageRole.assistant,
      timestamp: DateTime.now(),
      isLoading: true,
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg, loadingMsg],
      isSending: true,
      error: null,
    );

    // Create session if needed
    String sessionId = state.sessionId ?? '';
    if (sessionId.isEmpty) {
      sessionId = await _repo.createSession(user.uid, text);
      state = state.copyWith(sessionId: sessionId);
    }

    // Persist user message
    await _repo.appendMessage(user.uid, sessionId, userMsg);

    // Call AI
    try {
      final history = state.messages
          .where((m) => !m.isLoading)
          .take(20)
          .toList();

      final response = await _ai.sendMessage(
        history: history,
        newMessage: text,
      );

      final aiMsg = ChatMessage(
        id: _uuid.v4(),
        content: response,
        role: MessageRole.assistant,
        timestamp: DateTime.now(),
      );

      // Remove loading, add real response
      final updatedMessages = state.messages
          .where((m) => m.id != 'loading')
          .toList()
        ..add(aiMsg);

      state = state.copyWith(
        messages: updatedMessages,
        isSending: false,
      );

      await _repo.appendMessage(user.uid, sessionId, aiMsg);
    } catch (e) {
      final errMessages =
          state.messages.where((m) => m.id != 'loading').toList();
      state = state.copyWith(
        messages: errMessages,
        isSending: false,
        error: 'Failed to get response. Check your connection.',
      );
    }
  }

  Future<void> deleteSession(String sessionId) async {
    final user = await _ref.read(authStateProvider.future);
    if (user == null) return;
    await _repo.deleteSession(user.uid, sessionId);
    if (state.sessionId == sessionId) {
      state = const ActiveChatState();
    }
  }
}

final activeChatProvider =
    StateNotifierProvider<ActiveChatNotifier, ActiveChatState>((ref) {
  return ActiveChatNotifier(
    ref.read(chatRepositoryProvider),
    ref.read(aiServiceProvider),
    ref,
  );
});
