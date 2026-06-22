import 'package:dcpl_shared/dcpl_shared.dart';

/// Port for the supervisor's own material requests. The backend scopes `/material-requests` to
/// the caller, so these are only requests on work orders currently assigned to this supervisor.
abstract class MaterialRequestRepository {
  /// One page, optionally filtered by [status]/[project]/[workOrder], continuing after [cursor].
  Future<Page<MaterialRequest>> list({
    MaterialRequestStatus? status,
    String? project,
    String? workOrder,
    String? cursor,
  });

  /// Submits a multi-item request against one assigned work order → one record per item.
  Future<List<MaterialRequest>> submit(
    String workOrderId,
    List<MaterialRequestItemInput> items,
  );

  /// Cancels the supervisor's own request while it is still `requested`.
  Future<MaterialRequest> cancel(String id);

  /// Closes a delivered (`accepted`) item — fulfilment complete.
  Future<MaterialRequest> close(String id);

  /// Returns a delivered (`accepted`) item, with a required reason.
  Future<MaterialRequest> returnItem(String id, String reason);
}

class ApiMaterialRequestRepository implements MaterialRequestRepository {
  ApiMaterialRequestRepository(this._api);

  final DcplApi _api;

  @override
  Future<Page<MaterialRequest>> list({
    MaterialRequestStatus? status,
    String? project,
    String? workOrder,
    String? cursor,
  }) => _api.materialRequests.list(
    status: status,
    project: project,
    workOrder: workOrder,
    cursor: cursor,
  );

  @override
  Future<List<MaterialRequest>> submit(
    String workOrderId,
    List<MaterialRequestItemInput> items,
  ) => _api.materialRequests.submit(workOrderId, items);

  @override
  Future<MaterialRequest> cancel(String id) => _api.materialRequests.cancel(id);

  @override
  Future<MaterialRequest> close(String id) => _api.materialRequests.close(id);

  @override
  Future<MaterialRequest> returnItem(String id, String reason) =>
      _api.materialRequests.returnItem(id, reason);
}
