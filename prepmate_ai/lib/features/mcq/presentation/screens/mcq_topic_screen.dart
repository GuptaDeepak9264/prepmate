import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../providers/mcq_provider.dart';

class McqTopicScreen extends ConsumerStatefulWidget {
  const McqTopicScreen({super.key});

  @override
  ConsumerState<McqTopicScreen> createState() => _McqTopicScreenState();
}

class _McqTopicScreenState extends ConsumerState<McqTopicScreen> {
  final _topicCtrl = TextEditingController();
  String _selectedDifficulty = 'Medium';
  int _questionCount = 10;

  static const _quickTopics = [
    'Mathematics', 'Physics', 'Chemistry', 'Biology',
    'History', 'Geography', 'English Grammar', 'Computer Science',
  ];

  @override
  void dispose() {
    _topicCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final topic = _topicCtrl.text.trim();
    if (topic.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a topic first.')),
      );
      return;
    }

    final questions = await ref.read(mcqGeneratorProvider.notifier).generateQuestions(
      topic: topic,
      difficulty: _selectedDifficulty,
      count: _questionCount,
    );

    if (!mounted) return;
    if (questions != null && questions.isNotEmpty) {
      ref.read(activeMcqProvider.notifier).startSession(questions);
      context.push(
        AppRoutes.mcqQuestion,
        extra: {
          'topic': topic,
          'difficulty': _selectedDifficulty,
          'questionCount': _questionCount,
        },
      );
    } else {
      final error = ref.read(mcqGeneratorProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Generation failed. Try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final genState = ref.watch(mcqGeneratorProvider);
    final isLoading = genState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text(AppStrings.mcqModule)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero card
            GradientCard(
              colors: const [Color(0xFF4F46E5), Color(0xFF7C3AED)],
              child: Row(
                children: [
                  const Text('🧠', style: TextStyle(fontSize: 40)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI-Powered MCQs',
                            style: AppTextStyles.headlineSmall
                                .copyWith(color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(
                          'Generate customized questions on any topic',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().scale(begin: const Offset(0.97, 0.97)),
            const SizedBox(height: 28),

            Text('Enter Topic', style: AppTextStyles.titleLarge)
                .animate().fadeIn(delay: 50.ms),
            const SizedBox(height: 10),
            AppTextField(
              controller: _topicCtrl,
              label: AppStrings.enterTopic,
              hint: 'e.g. Photosynthesis, World War II, Algebra...',
              prefixIcon: Icons.school_outlined,
              textInputAction: TextInputAction.done,
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 16),

            // Quick topic chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _quickTopics
                  .map((t) => GestureDetector(
                        onTap: () => _topicCtrl.text = t,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(t,
                              style: AppTextStyles.bodySmall
                                  .copyWith(fontWeight: FontWeight.w500)),
                        ),
                      ))
                  .toList(),
            ).animate().fadeIn(delay: 150.ms),
            const SizedBox(height: 24),

            Text('Difficulty', style: AppTextStyles.titleLarge)
                .animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 10),
            Row(
              children: AppConstants.mcqDifficulties.map((d) {
                final isSelected = _selectedDifficulty == d;
                final color = d == 'Easy'
                    ? AppColors.success
                    : d == 'Medium'
                        ? AppColors.warning
                        : AppColors.error;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDifficulty = d),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(
                          right: d != 'Hard' ? 8 : 0),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? color.withOpacity(0.12)
                            : AppColors.surface,
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: isSelected ? color : AppColors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            d == 'Easy'
                                ? '😊'
                                : d == 'Medium'
                                    ? '🤔'
                                    : '🔥',
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            d,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isSelected
                                  ? color
                                  : AppColors.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ).animate().fadeIn(delay: 250.ms),
            const SizedBox(height: 24),

            // Question count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Questions: $_questionCount',
                    style: AppTextStyles.titleLarge),
                Row(
                  children: [5, 10, 15, 20].map((n) {
                    final isSel = _questionCount == n;
                    return GestureDetector(
                      onTap: () => setState(() => _questionCount = n),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 44,
                        height: 36,
                        margin: const EdgeInsets.only(left: 6),
                        decoration: BoxDecoration(
                          color: isSel
                              ? AppColors.primary
                              : AppColors.surface,
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                            color: isSel
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$n',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: isSel
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ).animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 32),

            AppButton(
              label: AppStrings.generateMCQ,
              onPressed: isLoading ? null : _generate,
              isLoading: isLoading,
              icon: Icons.auto_awesome_rounded,
            ).animate().fadeIn(delay: 350.ms),

            if (isLoading) ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Generating questions with AI...',
                  style: AppTextStyles.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
