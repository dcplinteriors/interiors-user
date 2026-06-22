import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:dcpl_user/features/work_orders/data/work_order_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient api;
  late ApiWorkOrderRepository repo;

  setUp(() {
    api = MockApiClient();
    repo = ApiWorkOrderRepository(DcplApi(api));
  });

  Map<String, dynamic> woJson({String id = 'w1', String? project}) => {
    'id': id,
    'project': project ?? 'p1',
    'number': '26-27_0001/0001',
    'name': 'Civil',
    'date': '2026-06-10',
    'status': 'active',
    'supervisorId': 'sup1',
    'projectName': 'Lobby',
    'clientName': 'Acme',
  };

  test('list() forwards the project filter and parses the page', () async {
    when(() => api.get('/work-orders', query: any(named: 'query'))).thenAnswer(
      (_) async => {
        'items': [woJson()],
        'nextCursor': null,
      },
    );
    await repo.list(project: 'p1');
    final query =
        verify(
              () => api.get('/work-orders', query: captureAny(named: 'query')),
            ).captured.single
            as Map;
    expect(query['project'], 'p1');
  });

  test('listAll() pages through every assigned work order', () async {
    var call = 0;
    when(() => api.get('/work-orders', query: any(named: 'query'))).thenAnswer((
      _,
    ) async {
      call++;
      return call == 1
          ? {
              'items': [woJson()],
              'nextCursor': 'c1',
            }
          : {'items': <dynamic>[], 'nextCursor': null};
    });
    final all = await repo.listAll();
    expect(all, hasLength(1));
    verify(() => api.get('/work-orders', query: any(named: 'query'))).called(2);
  });

  test('distinctProjects derives unique (id, name) pairs from work orders', () {
    final wos = [
      WorkOrder.fromJson(woJson(id: 'w1', project: 'p1')),
      WorkOrder.fromJson(woJson(id: 'w2', project: 'p1')),
      WorkOrder.fromJson(woJson(id: 'w3', project: 'p2')),
    ];
    final projects = distinctProjects(wos);
    expect(projects.map((p) => p.id), ['p1', 'p2']);
    expect(projects.first.name, 'Lobby');
  });
}
