import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/pdf_entity.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/cloudinary_service.dart';

class PdfRepository {
  final FirebaseFirestore _firestore;
  final CloudinaryService _cloudinary;
  final _uuid = const Uuid();

  PdfRepository({
    FirebaseFirestore? firestore,
    CloudinaryService? cloudinary,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _cloudinary = cloudinary ??
            CloudinaryService(
              cloudName: AppConstants.cloudinaryCloudName,
              uploadPreset: AppConstants.cloudinaryUploadPreset,
            );

  // ─── Firestore ref ────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _userPdfs(String uid) =>
      _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .collection(AppConstants.pdfsCollection);

  // ─── Real-time list ───────────────────────────────────────────────────────

  Stream<List<PdfEntity>> watchPdfs(String uid) {
    return _userPdfs(uid)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => PdfEntity.fromMap(d.data(), d.id)).toList());
  }

  // ─── Upload ───────────────────────────────────────────────────────────────

  /// Uploads [file] to Cloudinary, then stores the returned URL + metadata
  /// in Firestore. Returns the persisted [PdfEntity].
  ///
  /// [onProgress] streams upload progress as a 0.0–1.0 fraction.
  Future<PdfEntity> uploadPdf({
    required String uid,
    required File file,
    required String name,
    required String category,
    void Function(double progress)? onProgress,
  }) async {
    final id = _uuid.v4();
    final sizeBytes = await file.length();

    // ── 1. Upload to Cloudinary ────────────────────────────────────────────
    final result = await _cloudinary.uploadPdf(
      file: file,
      folder: '${AppConstants.cloudinaryPdfFolder}/$uid',
      publicId: id, // use our own UUID as the Cloudinary public_id
      onProgress: (sent, total) {
        if (total > 0 && onProgress != null) {
          onProgress(sent / total);
        }
      },
    );

    // ── 2. Persist metadata in Firestore ──────────────────────────────────
    final entity = PdfEntity(
      id: id,
      name: name,
      url: result.secureUrl,                 // https://res.cloudinary.com/…
      cloudinaryPublicId: result.publicId,   // prepmate/pdfs/uid/uuid
      category: category,
      sizeBytes: sizeBytes,
      pageCount: 0,
      lastReadPage: 0,
      uploadedAt: DateTime.now(),
      userId: uid,
    );

    await _userPdfs(uid).doc(id).set(entity.toMap());
    return entity;
  }

  // ─── Delete ───────────────────────────────────────────────────────────────

  /// Removes the Firestore document.
  ///
  /// The Cloudinary asset is NOT deleted here because client-side deletion
  /// requires an API secret (which must never be shipped in the app).
  /// To delete Cloudinary assets, call a Firebase Cloud Function:
  ///
  ///   exports.deleteCloudinaryAsset = functions.https.onCall(async (data) => {
  ///     await cloudinary.uploader.destroy(data.publicId, {resource_type:'raw'});
  ///   });
  Future<void> deletePdf(String uid, String pdfId,
      {String? cloudinaryPublicId}) async {
    // 1. Delete Firestore document
    await _userPdfs(uid).doc(pdfId).delete();

    // 2. Cloudinary deletion → must be done server-side (see docstring above).
    //    Uncomment once you have a backend endpoint:
    //
    // if (cloudinaryPublicId != null && cloudinaryPublicId.isNotEmpty) {
    //   await yourCloudFunctionClient.deleteAsset(cloudinaryPublicId);
    // }
  }

  // ─── Page tracking ────────────────────────────────────────────────────────

  Future<void> updateLastReadPage(String uid, String pdfId, int page) async {
    await _userPdfs(uid).doc(pdfId).update({'lastReadPage': page});
  }

  Future<void> updatePageCount(String uid, String pdfId, int count) async {
    await _userPdfs(uid).doc(pdfId).update({'pageCount': count});
  }

  // ─── Local search (client-side filter on Firestore snapshot) ─────────────

  Future<List<PdfEntity>> searchPdfs(String uid, String query) async {
    final snap = await _userPdfs(uid).get();
    final q = query.toLowerCase();
    return snap.docs
        .map((d) => PdfEntity.fromMap(d.data(), d.id))
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.category.toLowerCase().contains(q))
        .toList();
  }
}
