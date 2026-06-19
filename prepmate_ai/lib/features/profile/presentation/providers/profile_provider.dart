import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/cloudinary_service.dart';

// ─── Profile State ────────────────────────────────────────────────────────────

class ProfileState {
  final bool isUpdating;
  final double avatarUploadProgress; // 0.0–1.0
  final String? error;
  final bool isSuccess;

  const ProfileState({
    this.isUpdating = false,
    this.avatarUploadProgress = 0,
    this.error,
    this.isSuccess = false,
  });

  ProfileState copyWith({
    bool? isUpdating,
    double? avatarUploadProgress,
    String? error,
    bool? isSuccess,
  }) =>
      ProfileState(
        isUpdating: isUpdating ?? this.isUpdating,
        avatarUploadProgress:
            avatarUploadProgress ?? this.avatarUploadProgress,
        error: error,
        isSuccess: isSuccess ?? this.isSuccess,
      );
}

// ─── Profile Notifier ─────────────────────────────────────────────────────────

class ProfileNotifier extends StateNotifier<ProfileState> {
  final Ref _ref;
  final CloudinaryService _cloudinary;

  ProfileNotifier(this._ref)
      : _cloudinary = CloudinaryService(
          cloudName: AppConstants.cloudinaryCloudName,
          uploadPreset: AppConstants.cloudinaryUploadPreset,
        ),
        super(const ProfileState());

  // ── Update display name in Firestore ──────────────────────────────────────

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
        isUpdating: false,
        error: 'Failed to update name. Please try again.',
      );
    }
  }

  // ── Upload avatar to Cloudinary, save URL to Firestore ───────────────────

  Future<void> uploadAvatar(File imageFile, String uid) async {
    state = state.copyWith(
      isUpdating: true,
      avatarUploadProgress: 0,
      error: null,
    );
    try {
      // Upload image to Cloudinary
      final result = await _cloudinary.uploadImage(
        file: imageFile,
        folder: AppConstants.cloudinaryAvatarFolder,
        publicId: uid, // one avatar per user, overwrite on re-upload
        onProgress: (sent, total) {
          if (total > 0 && mounted) {
            state = state.copyWith(
              avatarUploadProgress: sent / total,
            );
          }
        },
      );

      // Persist the Cloudinary URL to Firestore
      await _ref.read(authRepositoryProvider).updateUserProfile(
        uid,
        {'photoUrl': result.secureUrl},
      );

      state = state.copyWith(
        isUpdating: false,
        avatarUploadProgress: 1.0,
        isSuccess: true,
      );
    } on CloudinaryException catch (e) {
      state = state.copyWith(
        isUpdating: false,
        error: 'Cloudinary upload failed: ${e.message}',
      );
    } catch (e) {
      state = state.copyWith(
        isUpdating: false,
        error: 'Failed to upload avatar. Please try again.',
      );
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _ref.read(authNotifierProvider.notifier).signOut();
  }

  void reset() => state = const ProfileState();
}

final profileNotifierProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>(
  (ref) => ProfileNotifier(ref),
);

// ─── MCQ stats re-export (for profile screen) ─────────────────────────────────

final profileMcqStatsProvider =
    StreamProvider<Map<String, dynamic>>((ref) async* {
  yield {'attempts': 0, 'correct': 0, 'accuracy': 0.0};
});
