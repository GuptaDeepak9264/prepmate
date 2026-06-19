import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final DateTime createdAt;
  final int studyStreak;
  final int totalStudyMinutes;
  final int mcqAttempts;
  final int mcqCorrect;

  const UserEntity({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    required this.createdAt,
    this.studyStreak = 0,
    this.totalStudyMinutes = 0,
    this.mcqAttempts = 0,
    this.mcqCorrect = 0,
  });

  UserEntity copyWith({
    String? name,
    String? photoUrl,
    int? studyStreak,
    int? totalStudyMinutes,
    int? mcqAttempts,
    int? mcqCorrect,
  }) {
    return UserEntity(
      uid: uid,
      name: name ?? this.name,
      email: email,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
      studyStreak: studyStreak ?? this.studyStreak,
      totalStudyMinutes: totalStudyMinutes ?? this.totalStudyMinutes,
      mcqAttempts: mcqAttempts ?? this.mcqAttempts,
      mcqCorrect: mcqCorrect ?? this.mcqCorrect,
    );
  }

  factory UserEntity.fromMap(Map<String, dynamic> map) {
    return UserEntity(
      uid: map['uid'] as String,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
          : DateTime.now(),
      studyStreak: map['studyStreak'] as int? ?? 0,
      totalStudyMinutes: map['totalStudyMinutes'] as int? ?? 0,
      mcqAttempts: map['mcqAttempts'] as int? ?? 0,
      mcqCorrect: map['mcqCorrect'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'studyStreak': studyStreak,
      'totalStudyMinutes': totalStudyMinutes,
      'mcqAttempts': mcqAttempts,
      'mcqCorrect': mcqCorrect,
    };
  }

  @override
  List<Object?> get props => [uid, name, email, photoUrl, studyStreak];
}
