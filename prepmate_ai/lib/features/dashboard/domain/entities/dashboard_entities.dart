import 'package:equatable/equatable.dart';

class StreakEntity extends Equatable {
  final int currentStreak;
  final int longestStreak;
  final List<DateTime> activeDays;
  final DateTime lastStudyDate;

  const StreakEntity({
    required this.currentStreak,
    required this.longestStreak,
    required this.activeDays,
    required this.lastStudyDate,
  });

  factory StreakEntity.fromMap(Map<String, dynamic> map) {
    return StreakEntity(
      currentStreak: map['currentStreak'] as int? ?? 0,
      longestStreak: map['longestStreak'] as int? ?? 0,
      activeDays: (map['activeDays'] as List<dynamic>? ?? [])
          .map((e) => DateTime.fromMillisecondsSinceEpoch(e as int))
          .toList(),
      lastStudyDate: map['lastStudyDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastStudyDate'] as int)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'activeDays': activeDays.map((d) => d.millisecondsSinceEpoch).toList(),
        'lastStudyDate': lastStudyDate.millisecondsSinceEpoch,
      };

  @override
  List<Object?> get props =>
      [currentStreak, longestStreak, activeDays, lastStudyDate];
}

class ProgressCardEntity extends Equatable {
  final String title;
  final String subtitle;
  final double progress;
  final String iconAsset;
  final int color;

  const ProgressCardEntity({
    required this.title,
    required this.subtitle,
    required this.progress,
    required this.iconAsset,
    required this.color,
  });

  @override
  List<Object?> get props => [title, progress];
}
