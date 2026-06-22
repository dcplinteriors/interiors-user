import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:dcpl_user/features/work_orders/work_orders.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWorkOrderRepository extends Mock implements WorkOrderRepository {}

WorkOrder wo(String id, {String project = 'p1'}) => WorkOrder(
  id: id,
  project: project,
  number: '26-27_0001/0001',
  name: 'Civil',
  date: '2026-06-10',
  status: WorkOrderStatus.active,
  supervisorId: 'sup1',
  projectName: 'Lobby',
  clientName: 'Acme',
);

void main() {
  late MockWorkOrderRepository repo;
  late WorkOrdersController controller;

  setUp(() {
    repo = MockWorkOrderRepository();
    controller = WorkOrdersController(repo);
  });

  void stubList(List<WorkOrder> items, {String? next}) {
    when(
      () => repo.list(
        project: any(named: 'project'),
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer((_) async => Page(items: items, nextCursor: next));
  }

  test('fetch() populates work orders and cursor', () async {
    stubList([wo('w1')], next: 'c1');
    await controller.fetch();
    expect(controller.workOrders, hasLength(1));
    expect(controller.hasMore, isTrue);
  });

  test('setProjectFilter() refetches with the project', () async {
    stubList([]);
    await controller.setProjectFilter('p1');
    verify(
      () => repo.list(
        project: 'p1',
        cursor: any(named: 'cursor'),
      ),
    ).called(1);
  });

  test(
    'loadProjectOptions() derives distinct projects from the full set',
    () async {
      when(() => repo.listAll()).thenAnswer(
        (_) async => [
          wo('w1', project: 'p1'),
          wo('w2', project: 'p1'),
          wo('w3', project: 'p2'),
        ],
      );
      await controller.loadProjectOptions();
      expect(controller.projects.map((p) => p.id), ['p1', 'p2']);
    },
  );

  test('loadProjectOptions() swallows ApiException (non-fatal)', () async {
    when(() => repo.listAll()).thenThrow(ApiException(500, 'boom'));
    await controller.loadProjectOptions();
    expect(controller.projects, isEmpty);
  });
}
