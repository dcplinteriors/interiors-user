import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:dcpl_user/features/material_requests/data/material_request_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient api;
  late ApiMaterialRequestRepository repo;

  setUp(() {
    api = MockApiClient();
    repo = ApiMaterialRequestRepository(DcplApi(api));
  });

  Map<String, dynamic> reqJson({String status = 'requested'}) => {
    'id': 'r1',
    'itemNumber': '26-27_0001/0001/0001',
    'workOrder': 'w1',
    'project': 'p1',
    'orderBy': 'sup1',
    'batchId': 'b1',
    'particular': 'Gypsum board',
    'make': 'Saint-Gobain',
    'size': '12mm',
    'quantity': 25,
    'unit': 'SHEET',
    'status': status,
    'createdAt': '2026-06-06T00:00:00.000Z',
    'attachments': {'photos': <String>[]},
  };

  test(
    'list() forwards status/project/workOrder filters and parses the page',
    () async {
      when(
        () => api.get('/material-requests', query: any(named: 'query')),
      ).thenAnswer(
        (_) async => {
          'items': [reqJson()],
          'nextCursor': 'c1',
        },
      );
      final result = await repo.list(
        status: MaterialRequestStatus.accepted,
        project: 'p1',
        workOrder: 'w1',
      );
      expect(result.items.single.particular, 'Gypsum board');
      expect(result.nextCursor, 'c1');
      final query =
          verify(
                () => api.get(
                  '/material-requests',
                  query: captureAny(named: 'query'),
                ),
              ).captured.single
              as Map;
      expect(query['status'], 'accepted');
      expect(query['project'], 'p1');
      expect(query['workOrder'], 'w1');
    },
  );

  test(
    'submit() POSTs workOrderId + items and parses the returned array',
    () async {
      when(
        () => api.post('/material-requests', body: any(named: 'body')),
      ).thenAnswer((_) async => [reqJson(), reqJson()]);

      final result = await repo.submit('w1', const [
        MaterialRequestItemInput(
          particular: 'Gypsum board',
          make: 'Saint-Gobain',
          size: '12mm',
          quantity: 25,
          unit: 'SHEET',
        ),
      ]);

      expect(result, hasLength(2));
      final body =
          verify(
                () => api.post(
                  '/material-requests',
                  body: captureAny(named: 'body'),
                ),
              ).captured.single
              as Map;
      expect(body['workOrderId'], 'w1');
      expect((body['items'] as List).single, {
        'particular': 'Gypsum board',
        'make': 'Saint-Gobain',
        'size': '12mm',
        'quantity': 25,
        'unit': 'SHEET',
      });
    },
  );

  test('submit() includes attachments only when present', () async {
    when(
      () => api.post('/material-requests', body: any(named: 'body')),
    ).thenAnswer((_) async => [reqJson()]);

    await repo.submit('w1', const [
      MaterialRequestItemInput(
        particular: 'Gypsum board',
        make: 'Saint-Gobain',
        size: '12mm',
        quantity: 25,
        unit: 'SHEET',
        attachments: Attachments(
          photos: ['material-requests/sup1/a.jpg'],
          audio: 'material-requests/sup1/note.m4a',
        ),
      ),
      MaterialRequestItemInput(
        particular: 'GI channel',
        make: 'Local',
        size: '0.5mm',
        quantity: 40,
        unit: 'MTR',
      ),
    ]);

    final body =
        verify(
              () => api.post(
                '/material-requests',
                body: captureAny(named: 'body'),
              ),
            ).captured.single
            as Map;
    final items = body['items'] as List;
    expect(items[0]['attachments'], {
      'photos': ['material-requests/sup1/a.jpg'],
      'audio': 'material-requests/sup1/note.m4a',
    });
    expect((items[1] as Map).containsKey('attachments'), isFalse);
  });

  test('cancel / close POST to their paths', () async {
    when(
      () => api.post('/material-requests/r1/cancel'),
    ).thenAnswer((_) async => reqJson(status: 'cancelled'));
    when(
      () => api.post('/material-requests/r1/close', body: any(named: 'body')),
    ).thenAnswer((_) async => reqJson(status: 'closed'));

    expect((await repo.cancel('r1')).status, MaterialRequestStatus.cancelled);
    expect(
      (await repo.close(
        'r1',
        billImages: const ['material-requests/s1/bill.jpg'],
      )).status,
      MaterialRequestStatus.closed,
    );
  });

}
