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
    repo = ApiMaterialRequestRepository(api);
  });

  Map<String, dynamic> reqJson({String status = 'requested'}) => {
        'id': 'r1',
        'project': 'p1',
        'orderBy': 'sup1',
        'poNumber': 'PO_26-27_06/0001',
        'jobNumber': 'JB_26-27_06/0001',
        'batchId': 'b1',
        'particular': 'Gypsum board',
        'make': 'Saint-Gobain',
        'quantity': 25,
        'unit': 'SHEET',
        'status': status,
        'createdAt': '2026-06-06T00:00:00.000Z',
        'expectedDate': null,
        'vendor': null,
        'remarks': null,
      };

  test('list() GETs /material-requests and parses the page', () async {
    when(() => api.get('/material-requests', query: any(named: 'query')))
        .thenAnswer((_) async => {'items': [reqJson()], 'nextCursor': 'c1'});
    final result = await repo.list();
    expect(result.items, hasLength(1));
    expect(result.items.first.particular, 'Gypsum board');
    expect(result.nextCursor, 'c1');
    verify(() => api.get('/material-requests', query: any(named: 'query'))).called(1);
  });

  test('list(status:, cursor:) forwards both in the query', () async {
    when(() => api.get('/material-requests', query: any(named: 'query')))
        .thenAnswer((_) async => {'items': <dynamic>[], 'nextCursor': null});
    await repo.list(status: 'accepted', cursor: 'abc');
    final query = verify(() => api.get('/material-requests', query: captureAny(named: 'query')))
        .captured
        .single as Map;
    expect(query['status'], 'accepted');
    expect(query['cursor'], 'abc');
  });

  test('submit() POSTs projectId + items and parses the returned array', () async {
    when(() => api.post('/material-requests', body: any(named: 'body')))
        .thenAnswer((_) async => [reqJson(), reqJson()]);

    final result = await repo.submit(
      projectId: 'p1',
      items: const [
        NewRequestItem(
            particular: 'Gypsum board', make: 'Saint-Gobain', size: '12mm', quantity: 25, unit: 'SHEET'),
        NewRequestItem(particular: 'GI channel', make: 'Local', size: '0.5mm', quantity: 40, unit: 'MTR'),
      ],
    );

    expect(result, hasLength(2));
    final body = verify(() => api.post('/material-requests', body: captureAny(named: 'body')))
        .captured
        .single as Map;
    expect(body['projectId'], 'p1');
    final items = body['items'] as List;
    expect(items, hasLength(2));
    expect(items.first, {
      'particular': 'Gypsum board',
      'make': 'Saint-Gobain',
      'size': '12mm',
      'quantity': 25,
      'unit': 'SHEET',
    });
  });

  test('submit() includes attachments only when present', () async {
    when(() => api.post('/material-requests', body: any(named: 'body')))
        .thenAnswer((_) async => [reqJson()]);

    await repo.submit(
      projectId: 'p1',
      items: const [
        // Has attachments → serialized.
        NewRequestItem(
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
        // No attachments → key omitted entirely.
        NewRequestItem(particular: 'GI channel', make: 'Local', size: '0.5mm', quantity: 40, unit: 'MTR'),
      ],
    );

    final body = verify(() => api.post('/material-requests', body: captureAny(named: 'body')))
        .captured
        .single as Map;
    final items = body['items'] as List;
    expect(items[0]['attachments'], {
      'photos': ['material-requests/sup1/a.jpg'],
      'audio': 'material-requests/sup1/note.m4a',
    });
    expect((items[1] as Map).containsKey('attachments'), isFalse);
  });

  test('cancel() POSTs to the cancel path and parses', () async {
    when(() => api.post('/material-requests/r1/cancel'))
        .thenAnswer((_) async => reqJson(status: 'cancelled'));
    final result = await repo.cancel('r1');
    expect(result.status, 'cancelled');
    verify(() => api.post('/material-requests/r1/cancel')).called(1);
  });
}
