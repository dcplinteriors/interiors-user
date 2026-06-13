import 'dart:async';

import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:dcpl_user/features/material_requests/data/material_request_repository.dart';
import 'package:dcpl_user/features/material_requests/material_requests_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMaterialRequestRepository extends Mock implements MaterialRequestRepository {}

MaterialRequest req(String id, String status, String createdAt) => MaterialRequest(
      id: id,
      project: 'p1',
      orderBy: 'sup1',
      poNumber: 'PO_26-27_06/0001',
      jobNumber: 'JB_26-27_06/0001',
      batchId: 'b1',
      particular: 'Gypsum board',
      make: 'Saint-Gobain',
      quantity: 25,
      unit: 'SHEET',
      status: status,
      createdAt: createdAt,
    );

void main() {
  late MockMaterialRequestRepository repo;
  late MaterialRequestsController controller;

  setUpAll(() => registerFallbackValue(<NewRequestItem>[]));

  setUp(() {
    repo = MockMaterialRequestRepository();
    controller = MaterialRequestsController(repo);
  });

  RequestPage page(List<MaterialRequest> items, {String? next}) =>
      (items: items, nextCursor: next);

  const item = NewRequestItem(particular: 'x', make: 'y', size: 's', quantity: 1, unit: 'PCS');

  test('fetch() populates requests and cursor on success', () async {
    when(() => repo.list(status: any(named: 'status'), cursor: any(named: 'cursor')))
        .thenAnswer((_) async => page([req('r1', 'requested', '2026-06-06T00:00:00Z')], next: 'c1'));
    await controller.fetch();
    expect(controller.requests, hasLength(1));
    expect(controller.hasMore, isTrue);
    expect(controller.error.value, isNull);
  });

  test('fetch() sets the error message on ApiException', () async {
    when(() => repo.list(status: any(named: 'status'), cursor: any(named: 'cursor')))
        .thenThrow(ApiException(500, 'boom'));
    await controller.fetch();
    expect(controller.error.value, 'boom');
  });

  test('setFilter sends the status to the server and refetches; re-selecting is a no-op', () async {
    final statuses = <String?>[];
    when(() => repo.list(status: any(named: 'status'), cursor: any(named: 'cursor')))
        .thenAnswer((invocation) async {
      statuses.add(invocation.namedArguments[#status] as String?);
      return page(<MaterialRequest>[]);
    });

    await controller.setFilter('accepted');
    expect(controller.statusFilter.value, 'accepted');
    expect(statuses, ['accepted']);

    await controller.setFilter('accepted'); // same filter → no fetch
    expect(statuses, ['accepted']);

    await controller.setFilter('declined'); // changed → refetch
    expect(statuses, ['accepted', 'declined']);
  });

  test('loadMore() appends the next page and clears the cursor', () async {
    when(() => repo.list(status: any(named: 'status'), cursor: null))
        .thenAnswer((_) async => page([req('r1', 'requested', '2026-06-06T00:00:00Z')], next: 'c1'));
    when(() => repo.list(status: any(named: 'status'), cursor: 'c1'))
        .thenAnswer((_) async => page([req('r2', 'requested', '2026-06-05T00:00:00Z')]));
    await controller.fetch();
    await controller.loadMore();
    expect(controller.requests.map((r) => r.id), ['r1', 'r2']);
    expect(controller.hasMore, isFalse);
  });

  test('submit() prepends created items that match the active filter', () async {
    controller.requests.add(req('old', 'requested', '2026-06-01T00:00:00Z'));
    when(() => repo.submit(projectId: any(named: 'projectId'), items: any(named: 'items')))
        .thenAnswer((_) async => [req('new1', 'requested', '2026-06-06T00:00:00Z')]);

    await controller.submit(projectId: 'p1', items: const [item]);

    expect(controller.requests.first.id, 'new1');
    expect(controller.requests, hasLength(2));
  });

  test('submit() does NOT show new requested items while a non-matching filter is active', () async {
    controller.statusFilter.value = 'accepted';
    when(() => repo.submit(projectId: any(named: 'projectId'), items: any(named: 'items')))
        .thenAnswer((_) async => [req('new1', 'requested', '2026-06-06T00:00:00Z')]);

    await controller.submit(projectId: 'p1', items: const [item]);

    expect(controller.requests, isEmpty);
  });

  test('a slow in-flight fetch does NOT overwrite an optimistic submit', () async {
    // fetch() issued first but its (stale) response lands AFTER submit prepends.
    final pending = Completer<RequestPage>();
    when(() => repo.list(status: any(named: 'status'), cursor: any(named: 'cursor')))
        .thenAnswer((_) => pending.future);
    final fetchFuture = controller.fetch(); // in flight, not awaited

    when(() => repo.submit(projectId: any(named: 'projectId'), items: any(named: 'items')))
        .thenAnswer((_) async => [req('new', 'requested', '2026-06-06T00:00:00Z')]);
    await controller.submit(projectId: 'p1', items: const [item]);
    expect(controller.requests.single.id, 'new');

    // The stale fetch resolves now — its result must be discarded.
    pending.complete(page([req('stale', 'requested', '2026-06-01T00:00:00Z')]));
    await fetchFuture;

    expect(controller.requests.map((r) => r.id), ['new']);
  });

  test('cancel() updates the request in place when it still matches the filter', () async {
    controller.requests.add(req('r1', 'requested', '2026-06-06T00:00:00Z'));
    when(() => repo.cancel('r1')).thenAnswer((_) async => req('r1', 'cancelled', '2026-06-06T00:00:00Z'));

    await controller.cancel('r1');

    expect(controller.requests.single.status, 'cancelled');
  });

  test('cancel() drops the request when it no longer matches the active filter', () async {
    controller.statusFilter.value = 'requested';
    controller.requests.add(req('r1', 'requested', '2026-06-06T00:00:00Z'));
    when(() => repo.cancel('r1')).thenAnswer((_) async => req('r1', 'cancelled', '2026-06-06T00:00:00Z'));

    await controller.cancel('r1');

    expect(controller.requests, isEmpty);
  });
}
