import 'dart:typed_data';

import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:http/http.dart' as http;

/// What kind of attachment is being uploaded — maps to the backend's `kind` enum,
/// which decides the allowed content types and the stored file extension.
enum AttachmentKind {
  photo,
  audio;

  String get wire => name; // 'photo' | 'audio'
}

/// Determines the content type to sign a photo upload with. Sniffs the magic bytes
/// first — image_picker re-encodes on web (a resized HEIC can come back as PNG), so
/// the picker's reported [mimeType] can't be trusted. Falls back to [mimeType] then
/// the [fileName] extension, defaulting to JPEG. Always returns a backend-allowed type.
String photoContentType(Uint8List bytes, {String? mimeType, String? fileName}) {
  if (bytes.length >= 12) {
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    // ISO-BMFF 'ftyp' box → HEIF/HEIC family.
    if (bytes[4] == 0x66 &&
        bytes[5] == 0x74 &&
        bytes[6] == 0x79 &&
        bytes[7] == 0x70) {
      return 'image/heic';
    }
  }
  const allowed = {'image/jpeg', 'image/png', 'image/webp', 'image/heic'};
  final mime = mimeType?.split(';').first.trim().toLowerCase();
  if (mime != null && allowed.contains(mime)) return mime;
  final name = fileName?.toLowerCase() ?? '';
  if (name.endsWith('.png')) return 'image/png';
  if (name.endsWith('.webp')) return 'image/webp';
  if (name.endsWith('.heic') || name.endsWith('.heif')) return 'image/heic';
  return 'image/jpeg';
}

/// Uploads an attachment via the backend's presigned-URL flow:
/// `POST /uploads/sign` mints a short-lived signed PUT URL, the bytes go straight
/// to Storage, and the returned object path is what we persist on the request.
/// The backend stays the single trusted boundary — the client never touches the
/// Storage SDK directly.
abstract class UploadService {
  /// Returns the stored object path (e.g. `material-requests/{uid}/{uuid}.jpg`).
  /// [scope] = `'attachment'` (default) for request photos/audio, `'profile'` for the avatar.
  /// Throws [ApiException] if signing or the upload fails.
  Future<String> upload({
    required AttachmentKind kind,
    required Uint8List bytes,
    required String contentType,
    String? scope,
  });

  /// Reads a locally-recorded audio blob URL into its bytes + content type, so the form
  /// doesn't do network I/O itself. (On web the recorder yields a `blob:` URL.)
  Future<({Uint8List bytes, String contentType})> readRecording(String url);
}

class ApiUploadService implements UploadService {
  ApiUploadService(this._api, {http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final DcplApi _api;
  final http.Client _http;

  @override
  Future<String> upload({
    required AttachmentKind kind,
    required Uint8List bytes,
    required String contentType,
    String? scope,
  }) async {
    final signed = await _api.uploads.sign(
      kind: kind.wire,
      contentType: contentType,
      scope: scope,
    );

    // PUT straight to Storage. The Content-Type MUST match what was signed, or GCS
    // rejects the request with a signature mismatch.
    final res = await _http.put(
      Uri.parse(signed.uploadUrl),
      headers: {'Content-Type': contentType},
      body: bytes,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(res.statusCode, 'Upload failed');
    }
    return signed.path;
  }

  @override
  Future<({Uint8List bytes, String contentType})> readRecording(
    String url,
  ) async {
    final res = await _http.get(Uri.parse(url));
    final contentType = (res.headers['content-type'] ?? 'audio/webm')
        .split(';')
        .first
        .trim();
    return (bytes: res.bodyBytes, contentType: contentType);
  }
}
