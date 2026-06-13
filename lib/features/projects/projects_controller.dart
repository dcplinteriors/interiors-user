import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:get/get.dart';

import 'data/project_repository.dart';

/// The supervisor's assigned projects (read-only).
class ProjectsController extends GetxController {
  ProjectsController(this._repo);

  final ProjectRepository _repo;

  final projects = <Project>[].obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final error = RxnString();

  /// Cursor for the next page, or null when the loaded list is complete.
  final _nextCursor = RxnString();
  bool get hasMore => _nextCursor.value != null;

  /// Bumped on every `fetch()`. A `loadMore()` captures the current value and discards its
  /// result if a fetch superseded it meanwhile.
  int _generation = 0;

  @override
  void onInit() {
    super.onInit();
    fetch();
  }

  /// Loads the first page, replacing the list.
  Future<void> fetch() async {
    final gen = ++_generation;
    isLoading.value = true;
    error.value = null;
    try {
      final page = await _repo.list();
      if (gen != _generation) return; // superseded by a newer fetch
      projects.value = page.items;
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
      final page = await _repo.list(cursor: _nextCursor.value);
      if (gen != _generation) return; // a refresh superseded this load
      projects.addAll(page.items);
      _nextCursor.value = page.nextCursor;
    } on ApiException catch (e) {
      if (gen == _generation) error.value = e.message;
    } finally {
      isLoadingMore.value = false;
    }
  }
}
