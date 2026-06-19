import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';

import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/constants/app_constants.dart';

// ─── Profile State ────────────────────────────────────────────────────────────

class ProfileState {
  final bool isUpdating;
  final String? error;
  final bool isSuccess;

  const ProfileState({
    this.isUpdating = false,
    this.error,
    this.isSuccess = false,
  });

  ProfileState copyWith({
    bool? isUpdating,
    String? error,
    bool? isSuccess,
  }) =>
      ProfileState(
        isUpdating: isUpdating ?? this.isUpdating,
        error: error,
        isSuccess: isSuccess ?? this.isSuccess,
      );
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final Ref _ref;

  ProfileNotifier(this._ref) : super(const ProfileState());

  Future<void> updateName(String name) async {
    if (name.trim().isEmpty) return;
    state = state.copyWith(isUpdating: true, error: null);
    try {
      final user = await _ref.read(authStateProvider.future);
      if (user == null) throw Exception('Not authenticated');
      await _ref.read(authRepositoryProvider).updateUserProfile(
        user.uid,
        {'name': name.trim()},
      );
      state = state.copyWith(isUpdating: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(
          isUpdating: false, error: 'Failed to update name.');
    }
  }

  Future<void> uploadAvatar(File imageFile, String uid) async {
    state = state.copyWith(isUpdating: true, error: null);
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('${AppConstants.avatarStoragePath}/$uid.jpg');
      final uploadTask = await storageRef.putFile(
        imageFile,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await uploadTask.ref.getDownloadURL();
      await _ref.read(authRepositoryProvider).updateUserProfile(
        uid,
        {'photoUrl': url},
      );
      state = state.copyWith(isUpdating: false, isSuccess: true);
    } catch (e) {
      state = state.copyWith(
          isUpdating: false, error: 'Failed to upload avatar.');
    }
  }

  Future<void> signOut() async {
    await _ref.read(authNotifierProvider.notifier).signOut();
  }

  void reset() => state = const ProfileState();
}

final profileNotifierProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>(
  (ref) => ProfileNotifier(ref),
);

// ─── MCQ Stats for profile ────────────────────────────────────────────────────

final profileMcqStatsProvider =
    StreamProvider<Map<String, dynamic>>((ref) {
  // Re-use dashboard provider
  return ref
      .watch(
        // ignore: avoid_dynamic_calls
        _mcqStatsStreamProvider,
      );
});

// Inline helper stream builder (delegate to dashboard provider pattern)
final _mcqStatsStreamProvider =
    StreamProvider<Map<String, dynamic>>((ref) async* {
  // Just yields empty — screens pull from dashboardProvider
  yield {'attempts': 0, 'correct': 0, 'accuracy': 0.0};
});
