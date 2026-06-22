import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:get/get.dart';

import '../work_orders/data/work_order_repository.dart';
import 'data/material_request_repository.dart';

/// The supervisor's own material requests — a paginated list (status / work-order filters),
/// submitting new multi-item requests, and the post-delivery close / return actions.
///
/// Mutations are optimistic: they update the loaded list immediately and invalidate any in-flight
/// fetch so its late response can't clobber the change.
class MaterialRequestsController extends PaginatedController<MaterialRequest> {
  MaterialRequestsController(this._repo, this._workOrderRepo);

  final MaterialRequestRepository _repo;
  final WorkOrderRepository _workOrderRepo;

  final requests = <MaterialRequest>[].obs;

  /// Filters. `statusFilter` null = all; `workOrderFilter` is a work-order id (null = all).
  final statusFilter = Rxn<MaterialRequestStatus>();
  final workOrderFilter = RxnString();

  /// The supervisor's work orders — options for the work-order filter. All statuses, so requests
  /// on a now-completed work order stay filterable.
  final workOrders = <WorkOrder>[].obs;

  /// Whether the supervisor has at least one active work order to raise a request
  /// against. Gates the "New request" entry points — with nothing assigned there's
  /// nothing to request. Optimistic until the first load so the button never flashes
  /// disabled, and stays as-is on a transient load failure (the form is the backstop).
  final hasAssignableWorkOrder = true.obs;

  @override
  RxList<MaterialRequest> get items => requests;

  @override
  Future<Page<MaterialRequest>> fetchPage({String? cursor}) => _repo.list(
    status: statusFilter.value,
    workOrder: workOrderFilter.value,
    cursor: cursor,
  );

  @override
  void onInit() {
    super.onInit();
    loadWorkOrders();
  }

  Future<void> setStatusFilter(MaterialRequestStatus? status) async {
    if (statusFilter.value == status) return;
    statusFilter.value = status;
    await fetch();
  }

  Future<void> setWorkOrderFilter(String? workOrderId) async {
    if (workOrderFilter.value == workOrderId) return;
    workOrderFilter.value = workOrderId;
    await fetch();
  }

  /// Loads the supervisor's work orders (filter options) and flags whether any is active — the
  /// latter gates the "New request" entry points.
  Future<void> loadWorkOrders() async {
    try {
      final all = await _workOrderRepo.listAll();
      workOrders.value = all;
      hasAssignableWorkOrder.value = all.any(
        (w) => w.status == WorkOrderStatus.active,
      );
    } on ApiException catch (_) {
      // Filter simply shows no options; keep the optimistic flag.
    }
  }

  /// Submits a multi-item request against [workOrderId] and prepends the created items. Throws.
  Future<List<MaterialRequest>> submit(
    String workOrderId,
    List<MaterialRequestItemInput> items,
  ) async {
    final created = await _repo.submit(workOrderId, items);
    invalidateInFlightLoads();
    // New items are `requested`; show them now only if the active filter includes them.
    final f = statusFilter.value;
    if (f == null || f == MaterialRequestStatus.requested) {
      requests.insertAll(0, created);
    }
    return created;
  }

  Future<MaterialRequest> cancel(String id) => _mutate(() => _repo.cancel(id));

  Future<MaterialRequest> close(String id) => _mutate(() => _repo.close(id));

  Future<MaterialRequest> returnItem(String id, String reason) =>
      _mutate(() => _repo.returnItem(id, reason));

  /// Runs a transition, then optimistically updates the row: drop it when it no longer matches
  /// the active status filter, else replace it in place.
  Future<MaterialRequest> _mutate(
    Future<MaterialRequest> Function() action,
  ) async {
    final updated = await action();
    invalidateInFlightLoads();
    final i = requests.indexWhere((r) => r.id == updated.id);
    if (i != -1) {
      final f = statusFilter.value;
      if (f != null && f != updated.status) {
        requests.removeAt(i);
      } else {
        requests[i] = updated;
      }
    }
    return updated;
  }
}
