import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/planner_repository.dart';
import '../../domain/entities/task_entity.dart';

// ─── Repository ───────────────────────────────────────────────────────────────

final plannerRepositoryProvider =
    Provider<PlannerRepository>((ref) => PlannerRepository());

// ─── Selected Date ────────────────────────────────────────────────────────────

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

// ─── Tasks for selected date ──────────────────────────────────────────────────

final tasksForDateProvider = StreamProvider<List<TaskEntity>>((ref) {
  final auth = ref.watch(authStateProvider);
  final selectedDate = ref.watch(selectedDateProvider);

  return auth.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      return ref
          .read(plannerRepositoryProvider)
          .watchTasksForDate(user.uid, selectedDate);
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

// ─── All tasks ────────────────────────────────────────────────────────────────

final allTasksProvider = StreamProvider<List<TaskEntity>>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      return ref.read(plannerRepositoryProvider).watchAllTasks(user.uid);
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

// ─── Task Actions Notifier ────────────────────────────────────────────────────

class TaskNotifier extends StateNotifier<AsyncValue<void>> {
  final PlannerRepository _repo;
  final Ref _ref;

  TaskNotifier(this._repo, this._ref) : super(const AsyncValue.data(null));

  Future<void> addTask({
    required String title,
    String? description,
    required DateTime dueDate,
    required TaskPriority priority,
  }) async {
    final user = await _ref.read(authStateProvider.future);
    if (user == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.addTask(
          uid: user.uid,
          title: title,
          description: description,
          dueDate: dueDate,
          priority: priority,
        ));
  }

  Future<void> toggleComplete(String taskId, bool value) async {
    final user = await _ref.read(authStateProvider.future);
    if (user == null) return;
    await _repo.toggleComplete(user.uid, taskId, value);
  }

  Future<void> deleteTask(String taskId) async {
    final user = await _ref.read(authStateProvider.future);
    if (user == null) return;
    await _repo.deleteTask(user.uid, taskId);
  }
}

final taskNotifierProvider =
    StateNotifierProvider<TaskNotifier, AsyncValue<void>>(
  (ref) => TaskNotifier(ref.read(plannerRepositoryProvider), ref),
);
