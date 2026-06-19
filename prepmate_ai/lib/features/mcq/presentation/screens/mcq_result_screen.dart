import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import '../../../../core/navigation/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../providers/mcq_provider.dart';
import '../../domain/entities/mcq_entity.dart';
import 'package:uuid/uuid.dart';

class McqResultScreen extends ConsumerStatefulWidget {
  final String topic;
  final int score;
  final int total;
  final List<dynamic> questions;

  const McqResultScreen({
    super.key,
    required this.topic,
    required this.score,
    required this.total,
    required this.questions,
  });

  @override
  ConsumerState<McqResultScreen> createState() => _McqResultScreenState();
}

class _McqResultScreenState extends ConsumerState<McqResultScreen> {
  @override
  void initState() {
    super.initState();
    _saveSession();
  }

  void _saveSession() {
    final session = McqSession(
      id: const Uuid().v4(),
      topic: widget.topic,
      difficulty: 'Mixed',
      questions: widget.questions
          .map((q) => McqQuestion.fromMap(Map<String, dynamic>.from(q as Map)))
          .toList(),
      createdAt: DateTime.now(),
    );
    ref.read(saveMcqSessionProvider(session).future);
  }

  String get _gradeLabel {
    final pct = widget.score / widget.total;
    if (pct >= 0.9) return 'Excellent! 🎉';
    if (pct >= 0.7) return 'Great Job! 👏';
    if (pct >= 0.5) return 'Good Effort! 💪';
    return 'Keep Practicing! 📚';
  }

  Color get _gradeColor {
    final pct = widget.score / widget.total;
    if (pct >= 0.7) return AppColors.success;
    if (pct >= 0.5) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final pct = widget.score / widget.total;
    final wrong = widget.total - widget.score;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Results'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () => context.go(AppRoutes.dashboard),
            child: const Text('Home'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Score circle
            CircularPercentIndicator(
              radius: 80,
              lineWidth: 12,
              percent: pct,
              animation: true,
              animationDuration: 1000,
              center: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${widget.score}/${widget.total}',
                    style: AppTextStyles.headlineLarge
                        .copyWith(color: _gradeColor),
                  ),
                  Text('${(pct * 100).toStringAsFixed(0)}%',
                      style: AppTextStyles.bodySmall),
                ],
              ),
              progressColor: _gradeColor,
              backgroundColor: _gradeColor.withOpacity(0.12),
              circularStrokeCap: CircularStrokeCap.round,
            )
                .animate()
                .scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 20),
            Text(_gradeLabel,
                style: AppTextStyles.headlineLarge)
                .animate()
                .fadeIn(delay: 200.ms),
            const SizedBox(height: 8),
            Text(widget.topic,
                style: AppTextStyles.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600))
                .animate()
                .fadeIn(delay: 250.ms),
            const SizedBox(height: 28),

            // Stats row
            Row(
              children: [
                _ResultStat(
                    label: 'Correct',
                    value: widget.score.toString(),
                    color: AppColors.success,
                    icon: Icons.check_circle_rounded),
                const SizedBox(width: 12),
                _ResultStat(
                    label: 'Wrong',
                    value: wrong.toString(),
                    color: AppColors.error,
                    icon: Icons.cancel_rounded),
                const SizedBox(width: 12),
                _ResultStat(
                    label: 'Total',
                    value: widget.total.toString(),
                    color: AppColors.primary,
                    icon: Icons.quiz_rounded),
              ],
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 28),

            // Review answers
            SectionHeader(title: 'Review Answers'),
            const SizedBox(height: 12),
            ...widget.questions.asMap().entries.map((e) {
              final q = McqQuestion.fromMap(
                  Map<String, dynamic>.from(e.value as Map));
              final selectedIdx = (e.value as Map)['selectedIndex'] as int?;
              final isCorrect = selectedIdx == q.correctIndex;
              return _ReviewItem(
                index: e.key,
                question: q,
                selectedIndex: selectedIdx,
                isCorrect: isCorrect,
              );
            }),
            const SizedBox(height: 28),

            // Action buttons
            AppButton(
              label: 'Try Again',
              onPressed: () => context.go(AppRoutes.mcqTopic),
              icon: Icons.refresh_rounded,
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.dashboard),
              icon: const Icon(Icons.home_rounded),
              label: const Text('Back to Home'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ).animate().fadeIn(delay: 450.ms),
          ],
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _ResultStat({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(value,
                style: AppTextStyles.headlineMedium
                    .copyWith(color: color)),
            Text(label, style: AppTextStyles.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ReviewItem extends StatefulWidget {
  final int index;
  final McqQuestion question;
  final int? selectedIndex;
  final bool isCorrect;

  const _ReviewItem({
    required this.index,
    required this.question,
    required this.selectedIndex,
    required this.isCorrect,
  });

  @override
  State<_ReviewItem> createState() => _ReviewItemState();
}

class _ReviewItemState extends State<_ReviewItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      color: widget.isCorrect
          ? AppColors.success.withOpacity(0.04)
          : AppColors.error.withOpacity(0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                widget.isCorrect
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: widget.isCorrect
                    ? AppColors.success
                    : AppColors.error,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Q${widget.index + 1}. ${widget.question.question}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: _expanded ? null : 2,
                  overflow: _expanded ? null : TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(
                  _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 18,
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          if (_expanded) ...[
            const Divider(height: 16),
            Text('Correct: ${widget.question.options[widget.question.correctIndex]}',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
            if (widget.selectedIndex != null &&
                widget.selectedIndex != widget.question.correctIndex)
              Text(
                  'Your answer: ${widget.question.options[widget.selectedIndex!]}',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.error)),
            if (widget.question.explanation.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(widget.question.explanation,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  )),
            ],
          ],
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: widget.index * 40))
        .fadeIn()
        .slideY(begin: 0.05, end: 0);
  }
}
