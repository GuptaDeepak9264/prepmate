import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/pdf_repository.dart';
import '../../domain/entities/pdf_entity.dart';

// ─── Repository ───────────────────────────────────────────────────────────────

final pdfRepositoryProvider =
    Provider<PdfRepository>((ref) => PdfRepository());

// ─── PDF List (real-time Firestore stream) ────────────────────────────────────

final pdfListProvider = StreamProvider<List<PdfEntity>>((ref) {
  final auth = ref.watch(authStateProvider);
  return auth.when(
    data: (user) {
      if (user == null) return Stream.value([]);
      return ref.read(pdfRepositoryProvider).watchPdfs(user.uid);
    },
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
  );
});

// ─── Search / filter state ────────────────────────────────────────────────────

final pdfSearchQueryProvider = StateProvider<String>((ref) => '');
final pdfCategoryFilterProvider = StateProvider<String>((ref) => 'All');

final filteredPdfListProvider =
    Provider<AsyncValue<List<PdfEntity>>>((ref) {
  final query = ref.watch(pdfSearchQueryProvider).toLowerCase();
  final category = ref.watch(pdfCategoryFilterProvider);
  return ref.watch(pdfListProvider).whenData((pdfs) {
    return pdfs.where((p) {
      final matchesSearch = query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          p.category.toLowerCase().contains(query);
      final matchesCategory =
          category == 'All' || p.category == category;
      return matchesSearch && matchesCategory;
    }).toList();
  });
});

// ─── Upload state ─────────────────────────────────────────────────────────────

class UploadState {
  final bool isUploading;
  /// 0.0 – 1.0 fraction; -1 means indeterminate
  final double progress;
  final String? error;
  final bool isSuccess;

  const UploadState({
    this.isUploading = false,
    this.progress = 0,
    this.error,
    this.isSuccess = false,
  });

  UploadState copyWith({
    bool? isUploading,
    double? progress,
    String? error,
    bool? isSuccess,
  }) =>
      UploadState(
        isUploading: isUploading ?? this.isUploading,
        progress: progress ?? this.progress,
        error: error,
        isSuccess: isSuccess ?? this.isSuccess,
      );
}

// ─── Upload notifier ──────────────────────────────────────────────────────────

class PdfUploadNotifier extends StateNotifier<UploadState> {
  final PdfRepository _repo;
  final Ref _ref;

  PdfUploadNotifier(this._repo, this._ref) : super(const UploadState());

  /// Upload [file] to Cloudinary and save the URL to Firestore.
  Future<PdfEntity?> uploadPdf({
    required File file,
    required String name,
    required String category,
  }) async {
    final user = await _ref.read(authStateProvider.future);
    if (user == null) return null;

    state = state.copyWith(isUploading: true, progress: 0, error: null);

    try {
      final entity = await _repo.uploadPdf(
        uid: user.uid,
        file: file,
        name: name,
        category: category,
        onProgress: (p) {
          // Update progress on the Riverpod state so UI can show a bar
          if (mounted) state = state.copyWith(progress: p);
        },
      );
      state = state.copyWith(isUploading: false, isSuccess: true);
      return entity;
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        error: _friendlyError(e),
      );
      return null;
    }
  }

  /// Deletes the Firestore doc. Cloudinary deletion is server-side — see
  /// PdfRepository.deletePdf() docstring for details.
  Future<void> deletePdf(String pdfId,
      {String? cloudinaryPublicId}) async {
    final user = await _ref.read(authStateProvider.future);
    if (user == null) return;
    await _repo.deletePdf(
      user.uid,
      pdfId,
      cloudinaryPublicId: cloudinaryPublicId,
    );
  }

  Future<void> updateLastPage(String pdfId, int page) async {
    final user = await _ref.read(authStateProvider.future);
    if (user == null) return;
    await _repo.updateLastReadPage(user.uid, pdfId, page);
  }

  Future<void> updatePageCount(String pdfId, int count) async {
    final user = await _ref.read(authStateProvider.future);
    if (user == null) return;
    await _repo.updatePageCount(user.uid, pdfId, count);
  }

  void reset() => state = const UploadState();

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('CloudinaryException')) {
      if (msg.contains('401') || msg.contains('403')) {
        return 'Invalid Cloudinary credentials. Check cloud name & upload preset.';
      }
      if (msg.contains('Network')) return 'Network error. Check your connection.';
      return 'Cloudinary upload failed: $msg';
    }
    return 'Upload failed. Please try again.';
  }
}

final pdfUploadProvider =
    StateNotifierProvider<PdfUploadNotifier, UploadState>(
  (ref) => PdfUploadNotifier(ref.read(pdfRepositoryProvider), ref),
);
