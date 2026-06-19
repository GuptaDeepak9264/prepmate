import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/task_entity.dart';
import '../../../../core/constants/app_constants.dart';

class PlannerRepository {
  final FirebaseFirestore _firestore;
  final _uuid = const Uuid();

  PlannerRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _tasks(String uid) => _firestore
      .collection(AppConstants.usersCollection)
      .doc(uid)
      .collection(AppConstants.tasksCollection);

  /// Stream tasks for a specific date
  Stream<List<TaskEntity>> watchTasksForDate(String uid, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay =
        DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

    return _tasks(uid)
        .where('dueDate',
            isGreaterThanOrEqualTo: startOfDay.millisecondsSinceEpoch)
        .where('dueDate',
            isLessThanOrEqualTo: endOfDay.millisecondsSinceEpoch)
        .orderBy('dueDate')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => TaskEntity.fromMap(d.data(), d.id)).toList());
  }

  /// Stream all tasks ordered by due date
  Stream<List<TaskEntity>> watchAllTasks(String uid) {
    return _tasks(uid)
        .orderBy('dueDate')
        .limit(100)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => TaskEntity.fromMap(d.data(), d.id)).toList());
  }

  Future<TaskEntity> addTask({
    required String uid,
    required String title,
    String? description,
    required DateTime dueDate,
    required TaskPriority priority,
  }) async {
    final id = _uuid.v4();
    final task = TaskEntity(
      id: id,
      title: title,
      description: description,
      isCompleted: false,
      dueDate: dueDate,
      priority: priority,
      userId: uid,
      createdAt: DateTime.now(),
    );
    await _tasks(uid).doc(id).set(task.toMap());
    return task;
  }

  Future<void> toggleComplete(String uid, String taskId, bool value) async {
    await _tasks(uid).doc(taskId).update({'isCompleted': value});
  }

  Future<void> deleteTask(String uid, String taskId) async {
    await _tasks(uid).doc(taskId).delete();
  }

  Future<void> updateTask(String uid, TaskEntity task) async {
    await _tasks(uid).doc(task.id).update(task.toMap());
  }
}
