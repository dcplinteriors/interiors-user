import 'package:dcpl_shared/dcpl_shared.dart';

/// An (id, name) reference to a project, for filter dropdowns.
typedef ProjectRef = ({String id, String name});

/// Distinct projects across [workOrders], in first-seen order — the supervisor has no direct
/// "my projects" endpoint, so the project filter is derived from their assigned work orders.
List<ProjectRef> distinctProjects(Iterable<WorkOrder> workOrders) {
  final seen = <String>{};
  return [
    for (final w in workOrders)
      if (w.projectName != null && seen.add(w.project))
        (id: w.project, name: w.projectName!),
  ];
}

/// Port for the supervisor's work orders. The backend scopes `/work-orders` to the caller, so
/// these are only the work orders currently assigned to this supervisor.
abstract class WorkOrderRepository {
  /// One page, optionally narrowed to a [project], continuing after [cursor].
  Future<Page<WorkOrder>> list({String? project, String? cursor});

  /// Every assigned work order (pages through `list`) — for the project-filter options.
  Future<List<WorkOrder>> listAll();

  /// Every assigned work order under [project] — for the request form's work-order cascade.
  Future<List<WorkOrder>> listAllForProject(String project);
}

class ApiWorkOrderRepository implements WorkOrderRepository {
  ApiWorkOrderRepository(this._api);

  final DcplApi _api;

  @override
  Future<Page<WorkOrder>> list({String? project, String? cursor}) =>
      _api.workOrders.list(project: project, cursor: cursor);

  @override
  Future<List<WorkOrder>> listAll() => _pageAll();

  @override
  Future<List<WorkOrder>> listAllForProject(String project) =>
      _pageAll(project: project);

  Future<List<WorkOrder>> _pageAll({String? project}) async {
    final all = <WorkOrder>[];
    String? cursor;
    do {
      final page = await _api.workOrders.list(project: project, cursor: cursor);
      all.addAll(page.items);
      cursor = page.nextCursor;
    } while (cursor != null);
    return all;
  }
}
