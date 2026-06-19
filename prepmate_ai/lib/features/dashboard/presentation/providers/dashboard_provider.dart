import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/dashboard_entities.dart';
import '../../../../core/constants/app_constants.dart';

// ─── Streak Provider ──────────────────────────────────────────────────────────

final streakProvider = StreamProvider<StreakEntity>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(_defaultStreak());
      return FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .collection(AppConstants.streaksCollection)
          .doc('current')
          .snapshots()
          .map((snap) => snap.exists
              ? StreakEntity.fromMap(snap.data()!)
              : _defaultStreak());
    },
    loading: () => Stream.value(_defaultStreak()),
    error: (_, __) => Stream.value(_defaultStreak()),
  );
});

StreakEntity _defaultStreak() => StreakEntity(
      currentStreak: 0,
      longestStreak: 0,
      activeDays: [],
      lastStudyDate: DateTime.now(),
    );

// ─── Today's Task Count Provider ──────────────────────────────────────────────

final todayTaskCountProvider = StreamProvider<Map<String, int>>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value({'total': 0, 'completed': 0});
      final today = DateTime.now();
      final startOfDay =
          DateTime(today.year, today.month, today.day).millisecondsSinceEpoch;
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59)
          .millisecondsSinceEpoch;

      return FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .collection(AppConstants.tasksCollection)
          .where('dueDate', isGreaterThanOrEqualTo: startOfDay)
          .where('dueDate', isLessThanOrEqualTo: endOfDay)
          .snapshots()
          .map((snap) {
        final total = snap.docs.length;
        final completed =
            snap.docs.where((d) => d.data()['isCompleted'] == true).length;
        return {'total': total, 'completed': completed};
      });
    },
    loading: () => Stream.value({'total': 0, 'completed': 0}),
    error: (_, __) => Stream.value({'total': 0, 'completed': 0}),
  );
});

// ─── PDF Count Provider ───────────────────────────────────────────────────────

final pdfCountProvider = StreamProvider<int>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(0);
      return FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .collection(AppConstants.pdfsCollection)
          .snapshots()
          .map((snap) => snap.docs.length);
    },
    loading: () => Stream.value(0),
    error: (_, __) => Stream.value(0),
  );
});

// ─── MCQ Stats Provider ───────────────────────────────────────────────────────

final mcqStatsProvider = StreamProvider<Map<String, dynamic>>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) {
        return Stream.value({'attempts': 0, 'correct': 0, 'accuracy': 0.0});
      }
      return FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .collection(AppConstants.mcqSessionsCollection)
          .snapshots()
          .map((snap) {
        if (snap.docs.isEmpty) {
          return {'attempts': 0, 'correct': 0, 'accuracy': 0.0};
        }
        int totalAttempts = 0;
        int totalCorrect = 0;
        for (final doc in snap.docs) {
          totalAttempts += (doc.data()['total'] as int? ?? 0);
          totalCorrect += (doc.data()['score'] as int? ?? 0);
        }
        final accuracy =
            totalAttempts > 0 ? (totalCorrect / totalAttempts) * 100 : 0.0;
        return {
          'attempts': snap.docs.length,
          'correct': totalCorrect,
          'accuracy': accuracy,
        };
      });
    },
    loading: () =>
        Stream.value({'attempts': 0, 'correct': 0, 'accuracy': 0.0}),
    error: (_, __) =>
        Stream.value({'attempts': 0, 'correct': 0, 'accuracy': 0.0}),
  );
});

// ─── Recent Activity Provider ─────────────────────────────────────────────────

final recentMcqSessionsProvider =
    StreamProvider<List<Map<String, dynamic>>>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      return FirebaseFirestore.instance
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .collection(AppConstants.mcqSessionsCollection)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .snapshots()
          .map((snap) => snap.docs.map((d) => d.data()).toList());
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});
