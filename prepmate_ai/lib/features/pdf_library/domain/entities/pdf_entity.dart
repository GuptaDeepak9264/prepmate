import 'package:equatable/equatable.dart';

class PdfEntity extends Equatable {
  final String id;
  final String name;
  final String url;             // Cloudinary secure_url
  final String cloudinaryPublicId; // Cloudinary public_id (for deletion via backend)
  final String category;
  final int sizeBytes;
  final int pageCount;
  final int lastReadPage;
  final DateTime uploadedAt;
  final String userId;

  const PdfEntity({
    required this.id,
    required this.name,
    required this.url,
    required this.cloudinaryPublicId,
    required this.category,
    required this.sizeBytes,
    required this.pageCount,
    required this.lastReadPage,
    required this.uploadedAt,
    required this.userId,
  });

  String get sizeLabel {
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  double get readProgress =>
      pageCount > 0 ? lastReadPage / pageCount : 0.0;

  PdfEntity copyWith({
    int? lastReadPage,
    int? pageCount,
    String? url,
    String? cloudinaryPublicId,
  }) =>
      PdfEntity(
        id: id,
        name: name,
        url: url ?? this.url,
        cloudinaryPublicId: cloudinaryPublicId ?? this.cloudinaryPublicId,
        category: category,
        sizeBytes: sizeBytes,
        pageCount: pageCount ?? this.pageCount,
        lastReadPage: lastReadPage ?? this.lastReadPage,
        uploadedAt: uploadedAt,
        userId: userId,
      );

  factory PdfEntity.fromMap(Map<String, dynamic> map, String id) => PdfEntity(
        id: id,
        name: map['name'] as String? ?? '',
        url: map['url'] as String? ?? '',
        cloudinaryPublicId: map['cloudinaryPublicId'] as String? ?? '',
        category: map['category'] as String? ?? 'General',
        sizeBytes: map['sizeBytes'] as int? ?? 0,
        pageCount: map['pageCount'] as int? ?? 0,
        lastReadPage: map['lastReadPage'] as int? ?? 0,
        uploadedAt: map['uploadedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['uploadedAt'] as int)
            : DateTime.now(),
        userId: map['userId'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'url': url,
        'cloudinaryPublicId': cloudinaryPublicId,
        'category': category,
        'sizeBytes': sizeBytes,
        'pageCount': pageCount,
        'lastReadPage': lastReadPage,
        'uploadedAt': uploadedAt.millisecondsSinceEpoch,
        'userId': userId,
      };

  @override
  List<Object?> get props =>
      [id, name, url, cloudinaryPublicId, category, lastReadPage];
}
