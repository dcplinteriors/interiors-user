import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:dcpl_user/features/projects/data/project_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient api;
  late ApiProjectRepository repo;

  setUp(() {
    api = MockApiClient();
    repo = ApiProjectRepository(api);
  });

  final projectJson = {
    'id': 'p1',
    'particular': 'Lobby',
    'clientName': 'Acme',
    'date': '2026-06-06',
    'po': 'PO_26-27_06/0001',
    'supervisorId': 'sup1',
    'status': 'active',
    'createdAt': '2026-06-06T00:00:00.000Z',
  };

  test('list() GETs /projects and parses the page', () async {
    when(() => api.get('/projects', query: any(named: 'query')))
        .thenAnswer((_) async => {
              'items': [projectJson],
              'nextCursor': 'c1',
            });
    final result = await repo.list();
    expect(result.items, hasLength(1));
    expect(result.items.first.particular, 'Lobby');
    expect(result.items.first.po, 'PO_26-27_06/0001');
    expect(result.nextCursor, 'c1');
    verify(() => api.get('/projects', query: any(named: 'query'))).called(1);
  });

  test('list(cursor:) forwards the cursor in the query', () async {
    when(() => api.get('/projects', query: any(named: 'query')))
        .thenAnswer((_) async => {'items': <dynamic>[], 'nextCursor': null});
    await repo.list(cursor: 'abc');
    final query = verify(() => api.get('/projects', query: captureAny(named: 'query')))
        .captured
        .single as Map;
    expect(query['cursor'], 'abc');
  });
}
