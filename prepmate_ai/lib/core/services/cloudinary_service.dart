import 'dart:io';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';

/// Result of a successful Cloudinary upload.
class CloudinaryUploadResult {
  final String publicId;
  final String secureUrl;
  final int bytes;
  final String format;
  final String resourceType;

  const CloudinaryUploadResult({
    required this.publicId,
    required this.secureUrl,
    required this.bytes,
    required this.format,
    required this.resourceType,
  });

  factory CloudinaryUploadResult.fromJson(Map<String, dynamic> json) =>
      CloudinaryUploadResult(
        publicId: json['public_id'] as String,
        secureUrl: json['secure_url'] as String,
        bytes: json['bytes'] as int,
        format: json['format'] as String? ?? 'pdf',
        resourceType: json['resource_type'] as String? ?? 'raw',
      );
}

/// Thrown when Cloudinary returns an error response.
class CloudinaryException implements Exception {
  final String message;
  final int? statusCode;
  const CloudinaryException(this.message, {this.statusCode});

  @override
  String toString() => 'CloudinaryException($statusCode): $message';
}

/// Lightweight Cloudinary upload client.
///
/// Uses the **unsigned** upload preset flow:
///   1. Create an *unsigned* upload preset in your Cloudinary dashboard.
///   2. Set [uploadPreset] to that preset name.
///   3. For PDFs set resource_type = "raw".
///
/// For **signed** uploads (more secure, recommended for production) you would
/// generate a signature on a server/Cloud Function and pass it here.
class CloudinaryService {
  final String cloudName;
  final String uploadPreset;
  final Dio _dio;

  CloudinaryService({
    required this.cloudName,
    required this.uploadPreset,
    Dio? dio,
  }) : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 120),
            ));

  /// Base upload URL for a given [resourceType].
  /// PDFs must use resourceType = 'raw'.
  /// Images use resourceType = 'image'.
  String _uploadUrl(String resourceType) =>
      'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload';

  /// Upload a PDF [file] to Cloudinary.
  ///
  /// [folder] organises uploads inside your Cloudinary media library,
  /// e.g. "prepmate/pdfs/uid123".
  ///
  /// [onProgress] receives bytes sent / total bytes (both > 0 when known).
  Future<CloudinaryUploadResult> uploadPdf({
    required File file,
    required String folder,
    String? publicId,
    void Function(int sent, int total)? onProgress,
  }) async {
    return _upload(
      file: file,
      resourceType: 'raw',
      folder: folder,
      publicId: publicId,
      contentType: MediaType('application', 'pdf'),
      onProgress: onProgress,
    );
  }

  /// Upload an image [file] (avatar, thumbnail, etc.) to Cloudinary.
  Future<CloudinaryUploadResult> uploadImage({
    required File file,
    required String folder,
    String? publicId,
    void Function(int sent, int total)? onProgress,
  }) async {
    final ext = file.path.split('.').last.toLowerCase();
    final mime = ext == 'png' ? 'png' : 'jpeg';
    return _upload(
      file: file,
      resourceType: 'image',
      folder: folder,
      publicId: publicId,
      contentType: MediaType('image', mime),
      onProgress: onProgress,
    );
  }

  /// Delete an asset by [publicId].
  ///
  /// NOTE: Deletion from the client side requires a *signed* request.
  /// For unsigned presets, call a Cloud Function / backend endpoint instead.
  /// This method is a no-op stub — implement server-side deletion as needed.
  Future<void> deleteAsset(String publicId, {String resourceType = 'raw'}) async {
    // Deletion requires an API secret (never expose on client).
    // Implement via Firebase Cloud Function:
    //   functions.https.onCall((data) => cloudinary.uploader.destroy(data.publicId))
    throw UnsupportedError(
      'Client-side Cloudinary deletion requires a signed request. '
      'Call a backend endpoint or Firebase Cloud Function to delete "$publicId".',
    );
  }

  // ─── Private ─────────────────────────────────────────────────────────────

  Future<CloudinaryUploadResult> _upload({
    required File file,
    required String resourceType,
    required String folder,
    required MediaType contentType,
    String? publicId,
    void Function(int sent, int total)? onProgress,
  }) async {
    final fileName = file.path.split('/').last;

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
        contentType: contentType,
      ),
      'upload_preset': uploadPreset,
      'folder': folder,
      if (publicId != null) 'public_id': publicId,
    });

    try {
      final response = await _dio.post(
        _uploadUrl(resourceType),
        data: formData,
        onSendProgress: onProgress,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return CloudinaryUploadResult.fromJson(
            response.data as Map<String, dynamic>);
      }

      throw CloudinaryException(
        response.data?['error']?['message'] as String? ?? 'Upload failed',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      final msg = (e.response?.data as Map?)?['error']?['message'] as String?;
      throw CloudinaryException(
        msg ?? e.message ?? 'Network error during upload',
        statusCode: e.response?.statusCode,
      );
    }
  }
}
