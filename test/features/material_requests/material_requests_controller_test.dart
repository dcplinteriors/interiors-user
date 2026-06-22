import 'dart:async';

import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:dcpl_user/features/material_requests/material_requests.dart';
import 'package:dcpl_user/features/work_orders/work_orders.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMaterialRequestRepository extends Mock
    implements MaterialRequestRepository {}

class MockWorkOrderRepository extends Mock implements WorkOrderRepository {}

WorkOrder wo(String id, WorkOrderStatus status) => WorkOrder(
  id: id,
  project: 'p1',
  number: '26-27_0001/0001',
  name: 'Civil',
  date: '2026-06-10',
  status: status,
  supervisorId: 'sup1',
  projectName: 'Lobby',
  clientName: 'Acme',
);

MaterialRequest req(String id, MaterialRequestStatus status) => MaterialRequest(
  id: id,
  itemNumber: '26-27_0001/0001/0001',
  workOrder: 'w1',
  project: 'p1',
  orderBy: 'sup1',
  batchId: 'b1',
  particular: 'Gypsum board',
  make: 'Saint-Gobain',
  quantity: 25,
  unit: 'SHEET',
  status: status,
  createdAt: '2026-06-06T00:00:00Z',
);

void main() {
  late MockMaterialRequestRepository repo;
  late MockWorkOrderRepository workOrderRepo;
  late MaterialRequestsController controller;

  setUpAll(() => registerFallbackValue(<MaterialRequestItemInput>[]));

  setUp(() {
    repo = MockMaterialRequestRepository();
    workOrderRepo = MockWorkOrderRepository();
    controller = MaterialRequestsController(repo, workOrderRepo);
  });

  void stubList(List<MaterialRequest> items, {String? next}) {
    when(
      () => repo.list(
        status: any(named: 'status'),
        project: any(named: 'project'),
        workOrder: any(named: 'workOrder'),
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer((_) async => Page(items: items, nextCursor: next));
  }

  const item = MaterialRequestItemInput(
    particular: 'x',
    make: 'y',
    size: 's',
    quantity: 1,
    unit: 'PCS',
  );

  test('fetch() populates requests and cursor on success', () async {
    stubList([req('r1', MaterialRequestStatus.requested)], next: 'c1');
    await controller.fetch();
    expect(controller.requests, hasLength(1));
    expect(controller.hasMore, isTrue);
    expect(controller.error.value, isNull);
  });

  test('fetch() sets the error message on ApiException', () async {
    when(
      () => repo.list(
        status: any(named: 'status'),
        project: any(named: 'project'),
        workOrder: any(named: 'workOrder'),
        cursor: any(named: 'cursor'),
      ),
    ).thenThrow(ApiException(500, 'boom'));
    await controller.fetch();
    expect(controller.error.value, 'boom');
  });

  test(
    'setStatusFilter sends the status and refetches; re-selecting is a no-op',
    () async {
      final statuses = <MaterialRequestStatus?>[];
      when(
        () => repo.list(
          status: any(named: 'status'),
          project: any(named: 'project'),
          workOrder: any(named: 'workOrder'),
          cursor: any(named: 'cursor'),
        ),
      ).thenAnswer((inv) async {
        statuses.add(inv.namedArguments[#status] as MaterialRequestStatus?);
        return const Page(items: <MaterialRequest>[], nextCursor: null);
      });

      await controller.setStatusFilter(MaterialRequestStatus.accepted);
      await controller.setStatusFilter(
        MaterialRequestStatus.accepted,
      ); // same → no fetch
      await controller.setStatusFilter(MaterialRequestStatus.declined);
      expect(statuses, [
        MaterialRequestStatus.accepted,
        MaterialRequestStatus.declined,
      ]);
    },
  );

  test('loadMore() appends the next page', () async {
    when(
      () => repo.list(
        status: any(named: 'status'),
        project: any(named: 'project'),
        workOrder: any(named: 'workOrder'),
        cursor: null,
      ),
    ).thenAnswer(
      (_) async => Page(
        items: [req('r1', MaterialRequestStatus.requested)],
        nextCursor: 'c1',
      ),
    );
    when(
      () => repo.list(
        status: any(named: 'status'),
        project: any(named: 'project'),
        workOrder: any(named: 'workOrder'),
        cursor: 'c1',
      ),
    ).thenAnswer(
      (_) async => Page(
        items: [req('r2', MaterialRequestStatus.requested)],
        nextCursor: null,
      ),
    );
    await controller.fetch();
    await controller.loadMore();
    expect(controller.requests.map((r) => r.id), ['r1', 'r2']);
    expect(controller.hasMore, isFalse);
  });

  test(
    'submit() prepends created items that match the active filter',
    () async {
      controller.requests.add(req('old', MaterialRequestStatus.requested));
      when(
        () => repo.submit(any(), any()),
      ).thenAnswer((_) async => [req('new1', MaterialRequestStatus.requested)]);

      await controller.submit('w1', const [item]);

      expect(controller.requests.first.id, 'new1');
      expect(controller.requests, hasLength(2));
    },
  );

  test(
    'submit() does NOT show new requested items under a non-matching filter',
    () async {
      controller.statusFilter.value = MaterialRequestStatus.accepted;
      when(
        () => repo.submit(any(), any()),
      ).thenAnswer((_) async => [req('new1', MaterialRequestStatus.requested)]);

      await controller.submit('w1', const [item]);

      expect(controller.requests, isEmpty);
    },
  );

  test(
    'a slow in-flight fetch does NOT overwrite an optimistic submit',
    () async {
      final pending = Completer<Page<MaterialRequest>>();
      when(
        () => repo.list(
          status: any(named: 'status'),
          project: any(named: 'project'),
          workOrder: any(named: 'workOrder'),
          cursor: any(named: 'cursor'),
        ),
      ).thenAnswer((_) => pending.future);
      final fetchFuture = controller.fetch(); // in flight, not awaited

      when(
        () => repo.submit(any(), any()),
      ).thenAnswer((_) async => [req('new', MaterialRequestStatus.requested)]);
      await controller.submit('w1', const [item]);
      expect(controller.requests.single.id, 'new');

      // The stale fetch resolves now — its result must be discarded.
      pending.complete(
        Page(
          items: [req('stale', MaterialRequestStatus.requested)],
          nextCursor: null,
        ),
      );
      await fetchFuture;

      expect(controller.requests.map((r) => r.id), ['new']);
    },
  );

  test(
    'cancel() updates the request in place when it still matches the filter',
    () async {
      controller.requests.add(req('r1', MaterialRequestStatus.requested));
      when(
        () => repo.cancel('r1'),
      ).thenAnswer((_) async => req('r1', MaterialRequestStatus.cancelled));
      await controller.cancel('r1');
      expect(
        controller.requests.single.status,
        MaterialRequestStatus.cancelled,
      );
    },
  );

  test(
    'cancel() drops the request when it no longer matches the active filter',
    () async {
      controller.statusFilter.value = MaterialRequestStatus.requested;
      controller.requests.add(req('r1', MaterialRequestStatus.requested));
      when(
        () => repo.cancel('r1'),
      ).thenAnswer((_) async => req('r1', MaterialRequestStatus.cancelled));
      await controller.cancel('r1');
      expect(controller.requests, isEmpty);
    },
  );

  test('close() updates a delivered item to closed', () async {
    controller.requests.add(req('r1', MaterialRequestStatus.accepted));
    when(
      () => repo.close('r1'),
    ).thenAnswer((_) async => req('r1', MaterialRequestStatus.closed));
    await controller.close('r1');
    expect(controller.requests.single.status, MaterialRequestStatus.closed);
  });

  test(
    'returnItem() sends the reason and updates the item to returned',
    () async {
      controller.requests.add(req('r1', MaterialRequestStatus.accepted));
      when(
        () => repo.returnItem('r1', 'damaged'),
      ).thenAnswer((_) async => req('r1', MaterialRequestStatus.returned));
      await controller.returnItem('r1', 'damaged');
      verify(() => repo.returnItem('r1', 'damaged')).called(1);
      expect(controller.requests.single.status, MaterialRequestStatus.returned);
    },
  );

  test(
    'loadWorkOrders() populates filter options and flags assignable when one is active',
    () async {
      when(() => workOrderRepo.listAll()).thenAnswer(
        (_) async => [
          wo('w1', WorkOrderStatus.completed),
          wo('w2', WorkOrderStatus.active),
        ],
      );
      await controller.loadWorkOrders();
      expect(controller.workOrders.map((w) => w.id), ['w1', 'w2']);
      expect(controller.hasAssignableWorkOrder.value, isTrue);
    },
  );

  test(
    'loadWorkOrders() clears the flag when no work order is active',
    () async {
      when(() => workOrderRepo.listAll()).thenAnswer(
        (_) async => [
          wo('w1', WorkOrderStatus.completed),
          wo('w2', WorkOrderStatus.cancelled),
        ],
      );
      await controller.loadWorkOrders();
      expect(controller.hasAssignableWorkOrder.value, isFalse);
    },
  );

  test('loadWorkOrders() keeps the optimistic flag on load failure', () async {
    when(() => workOrderRepo.listAll()).thenThrow(ApiException(500, 'boom'));
    await controller.loadWorkOrders();
    expect(controller.hasAssignableWorkOrder.value, isTrue);
  });

  test('setWorkOrderFilter() refetches with the work order', () async {
    final workOrders = <String?>[];
    when(
      () => repo.list(
        status: any(named: 'status'),
        project: any(named: 'project'),
        workOrder: any(named: 'workOrder'),
        cursor: any(named: 'cursor'),
      ),
    ).thenAnswer((inv) async {
      workOrders.add(inv.namedArguments[#workOrder] as String?);
      return const Page(items: <MaterialRequest>[], nextCursor: null);
    });

    await controller.setWorkOrderFilter('w2');
    await controller.setWorkOrderFilter('w2'); // same → no fetch
    await controller.setWorkOrderFilter(null);
    expect(workOrders, ['w2', null]);
  });
}
