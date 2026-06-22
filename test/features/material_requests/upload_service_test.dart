import 'dart:typed_data';

import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:dcpl_user/features/material_requests/data/upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient api;
  final bytes = Uint8List.fromList([1, 2, 3, 4]);

  setUp(() {
    api = MockApiClient();
  });

  test(
    'signs with kind + contentType, PUTs the bytes, and returns the path',
    () async {
      when(
        () => api.post('/uploads/sign', body: any(named: 'body')),
      ).thenAnswer(
        (_) async => {
          'uploadUrl': 'https://storage.example/upload?sig=abc',
          'path': 'material-requests/sup1/uuid.jpg',
        },
      );

      http.Request? sent;
      final client = MockClient((req) async {
        sent = req;
        return http.Response('', 200);
      });
      final service = ApiUploadService(DcplApi(api), httpClient: client);

      final path = await service.upload(
        kind: AttachmentKind.photo,
        bytes: bytes,
        contentType: 'image/jpeg',
      );

      expect(path, 'material-requests/sup1/uuid.jpg');

      // Signed with the right kind + content type.
      final body =
          verify(
                () =>
                    api.post('/uploads/sign', body: captureAny(named: 'body')),
              ).captured.single
              as Map;
      expect(body, {'kind': 'photo', 'contentType': 'image/jpeg'});

      // PUT the raw bytes to the signed URL, echoing the signed Content-Type.
      expect(sent!.method, 'PUT');
      expect(sent!.url.toString(), 'https://storage.example/upload?sig=abc');
      expect(sent!.headers['content-type'], startsWith('image/jpeg'));
      expect(sent!.bodyBytes, bytes);
    },
  );

  test('sends audio kind for an audio note', () async {
    when(() => api.post('/uploads/sign', body: any(named: 'body'))).thenAnswer(
      (_) async => {
        'uploadUrl': 'https://storage.example/u',
        'path': 'material-requests/sup1/u.m4a',
      },
    );
    final client = MockClient((_) async => http.Response('', 200));
    final service = ApiUploadService(DcplApi(api), httpClient: client);

    await service.upload(
      kind: AttachmentKind.audio,
      bytes: bytes,
      contentType: 'audio/mp4',
    );

    final body =
        verify(
              () => api.post('/uploads/sign', body: captureAny(named: 'body')),
            ).captured.single
            as Map;
    expect(body['kind'], 'audio');
  });

  test('throws ApiException when the PUT fails', () async {
    when(() => api.post('/uploads/sign', body: any(named: 'body'))).thenAnswer(
      (_) async => {
        'uploadUrl': 'https://storage.example/u',
        'path': 'material-requests/sup1/u.jpg',
      },
    );
    final client = MockClient((_) async => http.Response('denied', 403));
    final service = ApiUploadService(DcplApi(api), httpClient: client);

    expect(
      () => service.upload(
        kind: AttachmentKind.photo,
        bytes: bytes,
        contentType: 'image/jpeg',
      ),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403),
      ),
    );
  });

  test(
    'readRecording fetches the blob bytes + normalized content type',
    () async {
      final client = MockClient(
        (_) async => http.Response.bytes(
          [9, 8, 7],
          200,
          headers: {'content-type': 'audio/webm;codecs=opus'},
        ),
      );
      final service = ApiUploadService(DcplApi(api), httpClient: client);

      final recording = await service.readRecording('blob:abc');

      expect(recording.bytes, [9, 8, 7]);
      expect(recording.contentType, 'audio/webm'); // codec params stripped
    },
  );

  group('photoContentType', () {
    Uint8List bytesOf(List<int> head) {
      final b = Uint8List(16);
      for (var i = 0; i < head.length; i++) {
        b[i] = head[i];
      }
      return b;
    }

    test('sniffs PNG / JPEG / WebP magic bytes', () {
      expect(photoContentType(bytesOf([0x89, 0x50, 0x4E, 0x47])), 'image/png');
      expect(photoContentType(bytesOf([0xFF, 0xD8, 0xFF])), 'image/jpeg');
      // RIFF....WEBP
      expect(
        photoContentType(
          bytesOf([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50]),
        ),
        'image/webp',
      );
    });

    test('detects HEIC via the ISO-BMFF ftyp box', () {
      // bytes 4..7 == 'ftyp'
      expect(
        photoContentType(bytesOf([0, 0, 0, 0, 0x66, 0x74, 0x79, 0x70])),
        'image/heic',
      );
    });

    test('beats a wrong reported mime type — bytes win (web re-encode case)', () {
      // Picker claims HEIC but the actual bytes are PNG (canvas re-encoded on web).
      expect(
        photoContentType(
          bytesOf([0x89, 0x50, 0x4E, 0x47]),
          mimeType: 'image/heic',
          fileName: 'x.heic',
        ),
        'image/png',
      );
    });

    test(
      'falls back to a reported allowed mime when bytes are inconclusive',
      () {
        expect(
          photoContentType(Uint8List(4), mimeType: 'image/webp'),
          'image/webp',
        );
      },
    );

    test('falls back to the file extension, then defaults to jpeg', () {
      expect(
        photoContentType(Uint8List(4), fileName: 'photo.PNG'),
        'image/png',
      );
      expect(
        photoContentType(Uint8List(4), fileName: 'photo.heif'),
        'image/heic',
      );
      expect(photoContentType(Uint8List(4)), 'image/jpeg');
    });
  });
}
