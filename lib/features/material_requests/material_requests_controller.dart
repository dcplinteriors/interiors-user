import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:get/get.dart';

import 'data/material_request_repository.dart';

/// The supervisor's own material requests — list (server-side status filter + cursor
/// pagination), submit a new multi-item request, and cancel while `requested`.
class MaterialRequestsController extends GetxController {
  MaterialRequestsController(this._repo);

  final MaterialRequestRepository _repo;

  final requests = <MaterialRequest>[].obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final error = RxnString();

  /// Active status filter; null = all. Applied server-side.
  final statusFilter = RxnString();

  /// Cursor for the next page, or null when the loaded list is complete.
  final _nextCursor = RxnString();
  bool get hasMore => _nextCursor.value != null;

  /// Bumped on every `fetch()` AND every optimistic mutation (submit/cancel), so a slow
  /// in-flight fetch or load-more can't overwrite newer state when its response lands.
  int _generation = 0;

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  /// Switches the active filter and pulls the first page server-side, so requests an admin
  /// has just accepted/declined show up immediately.
  Future<void> setFilter(String? status) async {
    if (statusFilter.value == status) return;
    statusFilter.value = status;
    await fetch();
  }

  /// Loads the first page for the active filter, replacing the list.
  Future<void> fetch() async {
    final gen = ++_generation;
    isLoading.value = true;
    error.value = null;
    try {
      final page = await _repo.list(status: statusFilter.value);
      if (gen != _generation) return; // superseded by a newer fetch or a local mutation
      requests.value = page.items;
      _nextCursor.value = page.nextCursor;
    } on ApiException catch (e) {
      if (gen == _generation) error.value = e.message;
    } finally {
      if (gen == _generation) isLoading.value = false;
    }
  }

  /// Appends the next page. No-op if already loading or there's nothing more.
  Future<void> loadMore() async {
    if (isLoadingMore.value || _nextCursor.value == null) return;
    final gen = _generation;
    isLoadingMore.value = true;
    try {
      final page = await _repo.list(status: statusFilter.value, cursor: _nextCursor.value);
      if (gen != _generation) return; // a filter change or mutation superseded this load
      requests.addAll(page.items);
      _nextCursor.value = page.nextCursor;
    } on ApiException catch (e) {
      if (gen == _generation) error.value = e.message;
    } finally {
      isLoadingMore.value = false;
    }
  }

  /// Submits a multi-item request and prepends the created items. Throws on failure.
  Future<List<MaterialRequest>> submit({
    required String projectId,
    required List<NewRequestItem> items,
  }) async {
    final created = await _repo.submit(projectId: projectId, items: items);
    _applyOptimistic(() {
      // New items are `requested`; only show them now if the active filter includes them.
      final filter = statusFilter.value;
      if (filter == null || filter == 'requested') requests.insertAll(0, created);
    });
    return created;
  }

  /// Cancels a request. Drops it from view when it no longer matches the active filter
  /// (e.g. cancelled while viewing "Requested"), else updates it in place. Throws on failure.
  Future<MaterialRequest> cancel(String id) async {
    final updated = await _repo.cancel(id);
    _applyOptimistic(() {
      final i = requests.indexWhere((r) => r.id == updated.id);
      if (i == -1) return;
      final filter = statusFilter.value;
      if (filter != null && filter != updated.status) {
        requests.removeAt(i);
      } else {
        requests[i] = updated;
      }
    });
    return updated;
  }

  /// Applies a local mutation and invalidates any in-flight `fetch()`/`loadMore()` so it
  /// can't overwrite this update when its (older) response lands.
  void _applyOptimistic(void Function() mutate) {
    _generation++;
    // Clear the spinner ourselves: the superseded fetch's `finally` is generation-guarded,
    // so it will NOT reset isLoading once we've bumped the generation. Don't remove this line.
    isLoading.value = false;
    mutate();
  }
}
