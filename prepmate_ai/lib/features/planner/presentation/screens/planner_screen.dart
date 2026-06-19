import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/common_widgets.dart';
import '../../domain/entities/task_entity.dart';
import '../providers/planner_provider.dart';

class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final tasksAsync = ref.watch(tasksForDateProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(AppStrings.dailyPlanner),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDate,
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate:
                    DateTime.now().add(const Duration(days: 365)),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: const ColorScheme.light(
                      primary: AppColors.primary,
                    ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) {
                ref.read(selectedDateProvider.notifier).state =
                    DateTime(picked.year, picked.month, picked.day);
              }
            },
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Horizontal date scroller
          _DateScroller(selectedDate: selectedDate),

          // Date header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _isToday(selectedDate)
                        ? 'Today'
                        : DateFormat('EEEE, MMMM d').format(selectedDate),
                    style: AppTextStyles.headlineSmall,
                  ),
                ),
                tasksAsync.when(
                  data: (tasks) {
                    final done =
                        tasks.where((t) => t.isCompleted).length;
                    return StatusBadge(
                      label: '$done/${tasks.length} done',
                      color: AppColors.accent,
                    );
                  },
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
              ],
            ),
          ),

          // Task list
          Expanded(
            child: tasksAsync.when(
              data: (tasks) {
                if (tasks.isEmpty) {
                  return EmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    title: AppStrings.noTasks,
                    subtitle: AppStrings.noTasksSubtitle,
                    actionLabel: AppStrings.addTask,
                    onAction: () =>
                        _showAddTaskSheet(context, ref, selectedDate),
                  );
                }

                // Sort: incomplete first, then by priority
                final sorted = [...tasks]..sort((a, b) {
                    if (a.isCompleted != b.isCompleted) {
                      return a.isCompleted ? 1 : -1;
                    }
                    return b.priority.index.compareTo(a.priority.index);
                  });

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, i) => _TaskTile(
                    task: sorted[i],
                    index: i,
                  ),
                );
              },
              loading: () => ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: 4,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, __) => const ShimmerBox(
                    width: double.infinity, height: 72),
              ),
              error: (e, _) => AppErrorWidget(message: e.toString()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            _showAddTaskSheet(context, ref, selectedDate),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          AppStrings.addTask,
          style:
              AppTextStyles.labelLarge.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  void _showAddTaskSheet(
      BuildContext context, WidgetRef ref, DateTime selectedDate) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddTaskSheet(
        initialDate: selectedDate,
        onAdd: (title, desc, date, priority) async {
          await ref.read(taskNotifierProvider.notifier).addTask(
                title: title,
                description: desc,
                dueDate: date,
                priority: priority,
              );
        },
      ),
    );
  }
}

// ─── Date Scroller ────────────────────────────────────────────────────────────

class _DateScroller extends ConsumerWidget {
  final DateTime selectedDate;

  const _DateScroller({required this.selectedDate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final dates = List.generate(
      14,
      (i) => DateTime(now.year, now.month, now.day - 3 + i),
    );

    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: dates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final date = dates[i];
          final isSelected = date.year == selectedDate.year &&
              date.month == selectedDate.month &&
              date.day == selectedDate.day;
          final isToday = date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;

          return GestureDetector(
            onTap: () {
              ref.read(selectedDateProvider.notifier).state =
                  DateTime(date.year, date.month, date.day);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : isToday
                          ? AppColors.primaryLight
                          : AppColors.border,
                  width: isToday && !isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('MMM').format(date).toUpperCase(),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isSelected
                          ? Colors.white70
                          : AppColors.textTertiary,
                      fontSize: 9,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    date.day.toString(),
                    style: AppTextStyles.titleLarge.copyWith(
                      color: isSelected
                          ? Colors.white
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    DateFormat('EEE').format(date),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isSelected
                          ? Colors.white70
                          : AppColors.textTertiary,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Task Tile ────────────────────────────────────────────────────────────────

class _TaskTile extends ConsumerWidget {
  final TaskEntity task;
  final int index;

  const _TaskTile({required this.task, required this.index});

  Color get _priorityColor {
    switch (task.priority) {
      case TaskPriority.high:
        return AppColors.error;
      case TaskPriority.medium:
        return AppColors.warning;
      case TaskPriority.low:
        return AppColors.success;
    }
  }

  String get _priorityLabel {
    switch (task.priority) {
      case TaskPriority.high:
        return 'High';
      case TaskPriority.medium:
        return 'Med';
      case TaskPriority.low:
        return 'Low';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.error),
      ),
      onDismissed: (_) {
        ref.read(taskNotifierProvider.notifier).deleteTask(task.id);
      },
      child: AppCard(
        child: Row(
          children: [
            // Priority indicator
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: _priorityColor,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            const SizedBox(width: 12),

            // Checkbox
            GestureDetector(
              onTap: () => ref
                  .read(taskNotifierProvider.notifier)
                  .toggleComplete(task.id, !task.isCompleted),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: task.isCompleted
                      ? AppColors.accent
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: task.isCompleted
                        ? AppColors.accent
                        : AppColors.border,
                    width: 2,
                  ),
                ),
                child: task.isCompleted
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 14)
                    : null,
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: AppTextStyles.titleMedium.copyWith(
                      decoration: task.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      color: task.isCompleted
                          ? AppColors.textTertiary
                          : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (task.description != null &&
                      task.description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      task.description!,
                      style: AppTextStyles.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // Priority badge
            StatusBadge(
              label: _priorityLabel,
              color: _priorityColor,
            ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: index * 50))
        .fadeIn(duration: 300.ms)
        .slideX(begin: 0.05, end: 0);
  }
}

// ─── Add Task Bottom Sheet ────────────────────────────────────────────────────

class _AddTaskSheet extends StatefulWidget {
  final DateTime initialDate;
  final Future<void> Function(
      String title, String? desc, DateTime date, TaskPriority priority) onAdd;

  const _AddTaskSheet({required this.initialDate, required this.onAdd});

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  TaskPriority _priority = TaskPriority.medium;
  late DateTime _dueDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _dueDate = widget.initialDate;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _isLoading = true);
    await widget.onAdd(
      _titleCtrl.text.trim(),
      _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      _dueDate,
      _priority,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 24 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(AppStrings.addTask, style: AppTextStyles.headlineSmall),
          const SizedBox(height: 16),

          // Title
          AppTextField(
            controller: _titleCtrl,
            label: 'Task title',
            hint: 'e.g. Read Chapter 5',
            prefixIcon: Icons.task_alt_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),

          // Description
          AppTextField(
            controller: _descCtrl,
            label: 'Description (optional)',
            hint: 'Add more details...',
            prefixIcon: Icons.notes_rounded,
            maxLines: 2,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 16),

          // Priority selector
          Text('Priority', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: TaskPriority.values.map((p) {
              final isSelected = _priority == p;
              final color = p == TaskPriority.high
                  ? AppColors.error
                  : p == TaskPriority.medium
                      ? AppColors.warning
                      : AppColors.success;
              final label =
                  p.name[0].toUpperCase() + p.name.substring(1);
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _priority = p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: EdgeInsets.only(
                        right: p != TaskPriority.low ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withOpacity(0.12)
                          : AppColors.background,
                      borderRadius:
                          BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: isSelected ? color : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isSelected
                              ? color
                              : AppColors.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Submit
          AppButton(
            label: 'Add Task',
            onPressed: _isLoading ? null : _submit,
            isLoading: _isLoading,
            icon: Icons.add_rounded,
          ),
        ],
      ),
    );
  }
}
