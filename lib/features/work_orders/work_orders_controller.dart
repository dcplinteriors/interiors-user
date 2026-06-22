import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:get/get.dart';

import 'data/work_order_repository.dart';

/// The supervisor's assigned work orders — a paginated list with an optional project filter.
/// Tapping a work order starts a new material request against it (handled in the view).
class WorkOrdersController extends PaginatedController<WorkOrder> {
  WorkOrdersController(this._repo);

  final WorkOrderRepository _repo;

  final workOrders = <WorkOrder>[].obs;

  /// Project filter (a project id); null = all the supervisor's projects.
  final projectFilter = RxnString();

  /// Distinct projects across the supervisor's work orders — the filter-dropdown options.
  final projects = <ProjectRef>[].obs;

  @override
  RxList<WorkOrder> get items => workOrders;

  @override
  Future<Page<WorkOrder>> fetchPage({String? cursor}) =>
      _repo.list(project: projectFilter.value, cursor: cursor);

  @override
  void onInit() {
    super.onInit();
    loadProjectOptions();
  }

  Future<void> setProjectFilter(String? projectId) async {
    if (projectFilter.value == projectId) return;
    projectFilter.value = projectId;
    await fetch();
  }

  /// Loads the project-filter options from the full (unfiltered) assigned set. Non-fatal.
  Future<void> loadProjectOptions() async {
    try {
      projects.value = distinctProjects(await _repo.listAll());
    } on ApiException catch (_) {
      // Filter simply shows no project options.
    }
  }
}
