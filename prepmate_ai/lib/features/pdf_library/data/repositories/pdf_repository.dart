import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/pdf_entity.dart';
import '../../../../core/constants/app_constants.dart';

class PdfRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final _uuid = const Uuid();

  PdfRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _userPdfs(String uid) =>
      _firestore
          .collection(AppConstants.usersCollection)
          .doc(uid)
          .collection(AppConstants.pdfsCollection);

  Stream<List<PdfEntity>> watchPdfs(String uid) {
    return _userPdfs(uid)
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => PdfEntity.fromMap(d.data(), d.id)).toList());
  }

  Future<PdfEntity> uploadPdf({
    required String uid,
    required File file,
    required String name,
    required String category,
  }) async {
    final id = _uuid.v4();
    final size = await file.length();

    // Upload to Firebase Storage
    final storageRef = _storage
        .ref()
        .child('${AppConstants.pdfStoragePath}/$uid/$id.pdf');
    final uploadTask = await storageRef.putFile(
      file,
      SettableMetadata(contentType: 'application/pdf'),
    );
    final url = await uploadTask.ref.getDownloadURL();

    final entity = PdfEntity(
      id: id,
      name: name,
      url: url,
      category: category,
      sizeBytes: size,
      pageCount: 0,
      lastReadPage: 0,
      uploadedAt: DateTime.now(),
      userId: uid,
    );

    await _userPdfs(uid).doc(id).set(entity.toMap());
    return entity;
  }

  Future<void> deletePdf(String uid, String pdfId, String url) async {
    await _userPdfs(uid).doc(pdfId).delete();
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }

  Future<void> updateLastReadPage(String uid, String pdfId, int page) async {
    await _userPdfs(uid).doc(pdfId).update({'lastReadPage': page});
  }

  Future<void> updatePageCount(String uid, String pdfId, int count) async {
    await _userPdfs(uid).doc(pdfId).update({'pageCount': count});
  }

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

  UploadTask uploadPdfTask({
    required String uid,
    required File file,
    required String pdfId,
  }) {
    final storageRef = _storage
        .ref()
        .child('${AppConstants.pdfStoragePath}/$uid/$pdfId.pdf');
    return storageRef.putFile(
      file,
      SettableMetadata(contentType: 'application/pdf'),
    );
  }
}
