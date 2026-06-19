import 'package:equatable/equatable.dart';

enum TaskPriority { low, medium, high }

class TaskEntity extends Equatable {
  final String id;
  final String title;
  final String? description;
  final bool isCompleted;
  final DateTime dueDate;
  final TaskPriority priority;
  final String userId;
  final DateTime createdAt;

  const TaskEntity({
    required this.id,
    required this.title,
    this.description,
    required this.isCompleted,
    required this.dueDate,
    required this.priority,
    required this.userId,
    required this.createdAt,
  });

  TaskEntity copyWith({
    String? title,
    String? description,
    bool? isCompleted,
    DateTime? dueDate,
    TaskPriority? priority,
  }) =>
      TaskEntity(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        isCompleted: isCompleted ?? this.isCompleted,
        dueDate: dueDate ?? this.dueDate,
        priority: priority ?? this.priority,
        userId: userId,
        createdAt: createdAt,
      );

  factory TaskEntity.fromMap(Map<String, dynamic> map, String id) => TaskEntity(
        id: id,
        title: map['title'] as String? ?? '',
        description: map['description'] as String?,
        isCompleted: map['isCompleted'] as bool? ?? false,
        dueDate: map['dueDate'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['dueDate'] as int)
            : DateTime.now(),
        priority: TaskPriority.values.firstWhere(
          (p) => p.name == (map['priority'] as String? ?? 'medium'),
          orElse: () => TaskPriority.medium,
        ),
        userId: map['userId'] as String? ?? '',
        createdAt: map['createdAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'isCompleted': isCompleted,
        'dueDate': dueDate.millisecondsSinceEpoch,
        'priority': priority.name,
        'userId': userId,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  @override
  List<Object?> get props => [id, title, isCompleted, dueDate, priority];
}
