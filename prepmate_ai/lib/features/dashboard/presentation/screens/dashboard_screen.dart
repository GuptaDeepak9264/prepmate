import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/navigation/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return AppStrings.goodMorning;
    if (hour < 17) return AppStrings.goodAfternoon;
    return AppStrings.goodEvening;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final streakAsync = ref.watch(streakProvider);
    final taskCountAsync = ref.watch(todayTaskCountProvider);
    final pdfCountAsync = ref.watch(pdfCountProvider);
    final mcqStatsAsync = ref.watch(mcqStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: userAsync.when(
                            data: (user) => Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${_greeting()} 👋',
                                  style: AppTextStyles.bodyMedium
                                      .copyWith(color: Colors.white70),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user?.name.split(' ').first ?? 'Learner',
                                  style: AppTextStyles.headlineLarge
                                      .copyWith(color: Colors.white),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Keep up the great work!',
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: Colors.white60),
                                ),
                              ],
                            ),
                            loading: () => const ShimmerBox(
                                width: 160, height: 60, borderRadius: 8),
                            error: (_, __) => const SizedBox(),
                          ),
                        ),
                        userAsync.when(
                          data: (user) => AppAvatar(
                            imageUrl: user?.photoUrl,
                            name: user?.name ?? '',
                            size: 48,
                          ),
                          loading: () => const ShimmerBox(
                              width: 48, height: 48, borderRadius: 24),
                          error: (_, __) => const SizedBox(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            title: Text(AppConstants.appName,
                style: AppTextStyles.headlineSmall
                    .copyWith(color: Colors.white)),
            titleSpacing: 20,
          ),

          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Streak Card ──────────────────────────────────────────────
                streakAsync.when(
                  data: (streak) => _StreakCard(streak: streak),
                  loading: () =>
                      const ShimmerBox(width: double.infinity, height: 100),
                  error: (_, __) => const SizedBox(),
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
                const SizedBox(height: 24),

                // ── Quick Stats ──────────────────────────────────────────────
                SectionHeader(
                  title: 'Your Progress',
                  actionLabel: 'See all',
                  onAction: () => context.go(AppRoutes.mcqTopic),
                ).animate().fadeIn(delay: 100.ms),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: pdfCountAsync.when(
                        data: (count) => _StatCard(
                          icon: Icons.picture_as_pdf_rounded,
                          label: 'PDFs',
                          value: count.toString(),
                          color: AppColors.catScience,
                          onTap: () => context.go(AppRoutes.pdfLibrary),
                        ),
                        loading: () => const ShimmerBox(
                            width: double.infinity, height: 90),
                        error: (_, __) => const SizedBox(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: mcqStatsAsync.when(
                        data: (stats) => _StatCard(
                          icon: Icons.quiz_rounded,
                          label: 'MCQ Sessions',
                          value: stats['attempts'].toString(),
                          color: AppColors.catMath,
                          onTap: () => context.go(AppRoutes.mcqTopic),
                        ),
                        loading: () => const ShimmerBox(
                            width: double.infinity, height: 90),
                        error: (_, __) => const SizedBox(),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 150.ms),
                const SizedBox(height: 12),

                mcqStatsAsync.when(
                  data: (stats) => _AccuracyCard(
                    accuracy: (stats['accuracy'] as double).toDouble(),
                  ),
                  loading: () =>
                      const ShimmerBox(width: double.infinity, height: 90),
                  error: (_, __) => const SizedBox(),
                ).animate().fadeIn(delay: 200.ms),
                const SizedBox(height: 24),

                // ── Today's Tasks ────────────────────────────────────────────
                taskCountAsync.when(
                  data: (counts) => _TodaysTasksCard(
                    total: counts['total']!,
                    completed: counts['completed']!,
                    onTap: () => context.go(AppRoutes.planner),
                  ),
                  loading: () =>
                      const ShimmerBox(width: double.infinity, height: 120),
                  error: (_, __) => const SizedBox(),
                ).animate().fadeIn(delay: 250.ms),
                const SizedBox(height: 24),

                // ── Quick Actions ────────────────────────────────────────────
                SectionHeader(title: AppStrings.quickActions)
                    .animate()
                    .fadeIn(delay: 300.ms),
                const SizedBox(height: 12),
                _QuickActionsGrid().animate().fadeIn(delay: 350.ms),
                const SizedBox(height: 32),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Streak Card ──────────────────────────────────────────────────────────────

class _StreakCard extends StatelessWidget {
  final dynamic streak;

  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      colors: const [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 40)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${streak.currentStreak} Day Streak',
                  style: AppTextStyles.headlineMedium
                      .copyWith(color: Colors.white),
                ),
                Text(
                  'Best: ${streak.longestStreak} days  •  Keep it going!',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: Colors.white70),
                ),
              ],
            ),
          ),
          _WeekDots(activeDays: streak.activeDays ?? []),
        ],
      ),
    );
  }
}

class _WeekDots extends StatelessWidget {
  final List<dynamic> activeDays;

  const _WeekDots({required this.activeDays});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Row(
      children: List.generate(7, (i) {
        final day = now.subtract(Duration(days: 6 - i));
        final isActive = activeDays.any((d) {
          final dt = d is DateTime ? d : DateTime.fromMillisecondsSinceEpoch(d);
          return dt.year == day.year &&
              dt.month == day.month &&
              dt.day == day.day;
        });
        return Container(
          width: 10,
          height: 10,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.white : Colors.white30,
          ),
        );
      }),
    );
  }
}

// ─── Stat Card ────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: AppTextStyles.headlineLarge.copyWith(fontWeight: FontWeight.w700)),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

// ─── Accuracy Card ────────────────────────────────────────────────────────────

class _AccuracyCard extends StatelessWidget {
  final double accuracy;

  const _AccuracyCard({required this.accuracy});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          CircularPercentIndicator(
            radius: 36,
            lineWidth: 6,
            percent: (accuracy / 100).clamp(0.0, 1.0),
            center: Text(
              '${accuracy.toStringAsFixed(0)}%',
              style: AppTextStyles.titleMedium
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            progressColor: AppColors.accent,
            backgroundColor: AppColors.accent.withOpacity(0.12),
            circularStrokeCap: CircularStrokeCap.round,
            animation: true,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MCQ Accuracy', style: AppTextStyles.titleMedium),
                const SizedBox(height: 4),
                Text(
                  accuracy >= 80
                      ? 'Excellent! Keep it up 🎉'
                      : accuracy >= 50
                          ? 'Good progress, keep practicing!'
                          : 'More practice needed, you\'ve got this!',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Today's Tasks Card ───────────────────────────────────────────────────────

class _TodaysTasksCard extends StatelessWidget {
  final int total;
  final int completed;
  final VoidCallback onTap;

  const _TodaysTasksCard({
    required this.total,
    required this.completed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? completed / total : 0.0;
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppStrings.todaysTasks, style: AppTextStyles.titleLarge),
              StatusBadge(
                label: '$completed/$total done',
                color: AppColors.accent,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.accent.withOpacity(0.12),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            total == 0
                ? 'No tasks yet — add some!'
                : completed == total
                    ? '🎉 All tasks complete!'
                    : '${total - completed} task${total - completed == 1 ? '' : 's'} remaining',
            style: AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ─── Quick Actions Grid ───────────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.upload_file_rounded, 'Upload PDF', AppColors.catGeneral,
          AppRoutes.pdfUpload),
      (Icons.smart_toy_rounded, 'Ask AI', AppColors.catMath, AppRoutes.aiChat),
      (Icons.quiz_rounded, 'Take MCQ', AppColors.catScience, AppRoutes.mcqTopic),
      (Icons.add_task_rounded, 'Add Task', AppColors.catHistory, AppRoutes.planner),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: actions
          .map((a) => _QuickActionTile(
                icon: a.$1,
                label: a.$2,
                color: a.$3,
                route: a.$4,
              ))
          .toList(),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String route;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Text(
              label,
              style: AppTextStyles.labelLarge.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
