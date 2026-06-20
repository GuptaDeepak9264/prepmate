import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../providers/mcq_provider.dart';

class McqQuestionScreen extends ConsumerWidget {
  final String topic;
  final String difficulty;
  final int questionCount;

  const McqQuestionScreen({
    super.key,
    required this.topic,
    required this.difficulty,
    required this.questionCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mcqState = ref.watch(activeMcqProvider);

    if (mcqState.questions.isEmpty) {
      return const Scaffold(
        body: Center(child: AppLoadingIndicator()),
      );
    }

    final current = mcqState.current!;
    final progress =
        (mcqState.currentIndex + 1) / mcqState.questions.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _confirmExit(context);
        if (shouldPop && context.mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('$topic — $difficulty'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () async {
              if (await _confirmExit(context)) context.pop();
            },
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.border,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 4,
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Question counter
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Question ${mcqState.currentIndex + 1} of ${mcqState.questions.length}',
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  StatusBadge(
                    label: '${mcqState.score} correct',
                    color: AppColors.success,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Question card
              AppCard(
                child: Text(
                  current.question,
                  style: AppTextStyles.headlineSmall,
                ),
              )
                  .animate(key: ValueKey(mcqState.currentIndex))
                  .fadeIn()
                  .slideX(begin: 0.05, end: 0),
              const SizedBox(height: 20),

              // Options
              Expanded(
                child: ListView.separated(
                  itemCount: current.options.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _OptionTile(
                    label: current.options[i],
                    index: i,
                    selectedIndex: current.selectedIndex,
                    correctIndex: current.correctIndex,
                    isAnswered: current.isAnswered,
                    animDelay: i * 60,
                    onTap: () {
                      if (!current.isAnswered) {
                        ref
                            .read(activeMcqProvider.notifier)
                            .selectAnswer(i);
                      }
                    },
                  ),
                ),
              ),

              // Explanation
              if (current.isAnswered && current.explanation.isNotEmpty)
                AppCard(
                  color: AppColors.info.withOpacity(0.06),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.info, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          current.explanation,
                          style: AppTextStyles.bodySmall
                              .copyWith(height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(),
              const SizedBox(height: 16),

              // Next / Finish button
              if (current.isAnswered)
                AppButton(
                  label: mcqState.isLast ? 'View Results' : 'Next Question',
                  onPressed: () {
                    if (mcqState.isLast) {
                      context.pushReplacement(
                        AppRoutes.mcqResult,
                        extra: {
                          'topic': topic,
                          'score': mcqState.score,
                          'total': mcqState.questions.length,
                          'questions': mcqState.questions
                              .map((q) => q.toMap()
                                ..addAll({
                                  'selectedIndex': q.selectedIndex
                                }))
                              .toList(),
                        },
                      );
                    } else {
                      ref
                          .read(activeMcqProvider.notifier)
                          .nextQuestion();
                    }
                  },
                  icon: mcqState.isLast
                      ? Icons.bar_chart_rounded
                      : Icons.arrow_forward_rounded,
                ).animate().fadeIn().slideY(begin: 0.1),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmExit(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Exit MCQ?'),
            content:
                const Text('Your progress will be lost if you leave now.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Exit',
                    style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final int index;
  final int? selectedIndex;
  final int correctIndex;
  final bool isAnswered;
  final int animDelay;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.index,
    required this.selectedIndex,
    required this.correctIndex,
    required this.isAnswered,
    required this.animDelay,
    required this.onTap,
  });

  static const _labels = ['A', 'B', 'C', 'D'];

  Color _getBorderColor() {
    if (!isAnswered) return AppColors.border;
    if (index == correctIndex) return AppColors.success;
    if (index == selectedIndex) return AppColors.error;
    return AppColors.border;
  }

  Color _getBgColor() {
    if (!isAnswered) return AppColors.surface;
    if (index == correctIndex) return AppColors.success.withOpacity(0.08);
    if (index == selectedIndex) return AppColors.error.withOpacity(0.08);
    return AppColors.surface;
  }

  Color _getLabelColor() {
    if (!isAnswered) return AppColors.textSecondary;
    if (index == correctIndex) return AppColors.success;
    if (index == selectedIndex) return AppColors.error;
    return AppColors.textTertiary;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isAnswered ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _getBgColor(),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: _getBorderColor(),
            width: isAnswered && (index == correctIndex || index == selectedIndex)
                ? 2
                : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _getLabelColor().withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _labels[index],
                  style: AppTextStyles.labelLarge
                      .copyWith(color: _getLabelColor()),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: isAnswered && index == correctIndex
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
            if (isAnswered) ...[
              const SizedBox(width: 8),
              Icon(
                index == correctIndex
                    ? Icons.check_circle_rounded
                    : index == selectedIndex
                        ? Icons.cancel_rounded
                        : null,
                color: index == correctIndex
                    ? AppColors.success
                    : AppColors.error,
                size: 20,
              ),
            ],
          ],
        ),
      ),
    ).animate(delay: Duration(milliseconds: animDelay)).fadeIn().slideX(
        begin: 0.04, end: 0, duration: 300.ms);
  }
}
