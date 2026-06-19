import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/navigation/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../providers/chat_provider.dart';

class ChatHistoryScreen extends ConsumerWidget {
  const ChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(chatSessionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chat History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              ref.read(activeChatProvider.notifier).startNewChat();
              context.pop();
            },
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('New'),
          ),
        ],
      ),
      body: sessionsAsync.when(
        data: (sessions) => sessions.isEmpty
            ? const EmptyState(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'No chats yet',
                subtitle: 'Start a conversation with your AI tutor',
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: sessions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final session = sessions[i];
                  return Dismissible(
                    key: Key(session.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.error),
                    ),
                    onDismissed: (_) {
                      ref
                          .read(activeChatProvider.notifier)
                          .deleteSession(session.id);
                    },
                    child: AppCard(
                      onTap: () {
                        ref
                            .read(activeChatProvider.notifier)
                            .loadSession(session.id);
                        context.pop();
                      },
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                            ),
                            child: const Icon(Icons.chat_rounded,
                                color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session.title,
                                  style: AppTextStyles.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '${session.messages.length} messages',
                                      style: AppTextStyles.bodySmall,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '•',
                                      style: AppTextStyles.bodySmall,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      timeago.format(session.updatedAt),
                                      style: AppTextStyles.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              color: AppColors.textTertiary, size: 14),
                        ],
                      ),
                    ).animate(
                        delay: Duration(milliseconds: i * 40)),
                  );
                },
              ),
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppErrorWidget(message: e.toString()),
      ),
    );
  }
}
