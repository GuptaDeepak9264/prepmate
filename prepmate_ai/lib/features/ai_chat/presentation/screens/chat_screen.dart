import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../domain/entities/chat_entity.dart';
import '../providers/chat_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    await ref.read(activeChatProvider.notifier).sendMessage(text);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(activeChatProvider);
    final messages = chatState.messages;

    // Auto-scroll when messages change
    if (messages.isNotEmpty) _scrollToBottom();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                ),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.aiChat,
                    style: AppTextStyles.titleLarge),
                Text('Always here to help',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Chat history',
            onPressed: () => context.push(AppRoutes.chatHistory),
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_rounded),
            tooltip: 'New chat',
            onPressed: () {
              ref.read(activeChatProvider.notifier).startNewChat();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: messages.isEmpty
                ? _WelcomeState(
                    onSuggestionTap: (s) {
                      _msgCtrl.text = s;
                      _sendMessage();
                    },
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    itemCount: messages.length +
                        (chatState.error != null ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i < messages.length) {
                        return _MessageBubble(
                            message: messages[i], index: i);
                      }
                      return _ErrorBanner(
                          message: chatState.error!);
                    },
                  ),
          ),

          // Input area
          _ChatInput(
            controller: _msgCtrl,
            focusNode: _focusNode,
            isSending: chatState.isSending,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

// ─── Welcome State ────────────────────────────────────────────────────────────

class _WelcomeState extends StatelessWidget {
  final ValueChanged<String> onSuggestionTap;

  const _WelcomeState({required this.onSuggestionTap});

  static const _suggestions = [
    'Explain photosynthesis',
    'What is Newton\'s 2nd law?',
    'Summarize World War II',
    'Help me with quadratic equations',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.gradientStart, AppColors.gradientEnd],
              ),
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: AppShadows.primary,
            ),
            child: const Icon(Icons.smart_toy_rounded,
                color: Colors.white, size: 36),
          )
              .animate()
              .scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: 20),
          Text('Hi! I\'m your AI Tutor',
              style: AppTextStyles.headlineMedium)
              .animate()
              .fadeIn(delay: 100.ms),
          const SizedBox(height: 8),
          Text(
            'Ask me anything about your studies.\nI\'m here to help!',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 150.ms),
          const SizedBox(height: 32),
          Text('Try asking:', style: AppTextStyles.titleMedium)
              .animate()
              .fadeIn(delay: 200.ms),
          const SizedBox(height: 12),
          ..._suggestions.asMap().entries.map(
                (e) => _SuggestionChip(
                  label: e.value,
                  delay: 250 + e.key * 50,
                  onTap: () => onSuggestionTap(e.value),
                ),
              ),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final int delay;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.label,
    required this.delay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.lightbulb_outline_rounded,
                color: AppColors.primary, size: 16),
            const SizedBox(width: 10),
            Expanded(
                child: Text(label, style: AppTextStyles.bodyMedium)),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.textTertiary, size: 12),
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: delay)).slideX(
        begin: 0.05,
        end: 0,
        duration: 300.ms,
        curve: Curves.easeOut);
  }
}

// ─── Message Bubble ───────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final int index;

  const _MessageBubble({required this.message, required this.index});

  bool get _isUser => message.role == MessageRole.user;

  @override
  Widget build(BuildContext context) {
    if (message.isLoading) return _LoadingBubble();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!_isUser) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.gradientStart, AppColors.gradientEnd],
                ),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  color: Colors.white, size: 14),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: message.content));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _isUser
                      ? AppColors.primary
                      : AppColors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(AppRadius.lg),
                    topRight: const Radius.circular(AppRadius.lg),
                    bottomLeft: Radius.circular(
                        _isUser ? AppRadius.lg : AppRadius.xs),
                    bottomRight: Radius.circular(
                        _isUser ? AppRadius.xs : AppRadius.lg),
                  ),
                  border: _isUser
                      ? null
                      : Border.all(color: AppColors.border),
                  boxShadow: AppShadows.sm,
                ),
                child: Text(
                  message.content,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: _isUser
                        ? Colors.white
                        : AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ),
          if (_isUser) const SizedBox(width: 8),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }
}

class _LoadingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.gradientStart, AppColors.gradientEnd],
              ),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.smart_toy_rounded,
                color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
                bottomRight: Radius.circular(AppRadius.lg),
                bottomLeft: Radius.circular(AppRadius.xs),
              ),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Dot(delay: 0),
                const SizedBox(width: 4),
                _Dot(delay: 150),
                const SizedBox(width: 4),
                _Dot(delay: 300),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final int delay;

  const _Dot({required this.delay});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(
          begin: 0.5,
          end: 1.0,
          delay: Duration(milliseconds: delay),
          duration: const Duration(milliseconds: 500),
        );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

// ─── Chat Input ───────────────────────────────────────────────────────────────

class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final VoidCallback onSend;

  const _ChatInput({
    required this.controller,
    required this.focusNode,
    required this.isSending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              maxLines: 5,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              keyboardType: TextInputType.multiline,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: AppStrings.messageHint,
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  borderSide:
                      const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  borderSide:
                      const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isSending
                  ? AppColors.primary.withOpacity(0.5)
                  : AppColors.primary,
              shape: BoxShape.circle,
              boxShadow: isSending ? [] : AppShadows.primary,
            ),
            child: isSending
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.send_rounded,
                        color: Colors.white, size: 18),
                    onPressed: onSend,
                  ),
          ),
        ],
      ),
    );
  }
}
