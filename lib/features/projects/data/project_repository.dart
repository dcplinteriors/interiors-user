import 'package:dcpl_shared/dcpl_shared.dart';

/// One page of projects plus the cursor for the next page (null = last page).
typedef ProjectPage = ({List<Project> items, String? nextCursor});

/// Read-only project access for the supervisor — the backend scopes `/projects`
/// to the projects assigned to the signed-in supervisor.
abstract class ProjectRepository {
  /// Lists assigned projects (cursor-paginated), continuing after [cursor] (null = first page).
  Future<ProjectPage> list({String? cursor});
}

class ApiProjectRepository implements ProjectRepository {
  ApiProjectRepository(this._api);

  final ApiClient _api;

  @override
  Future<ProjectPage> list({String? cursor}) async {
    final data = await _api.get(
      '/projects',
      query: {'cursor': ?cursor},
    ) as Map<String, dynamic>;
    final items = (data['items'] as List)
        .map((e) => Project.fromJson(e as Map<String, dynamic>))
        .toList();
    return (items: items, nextCursor: data['nextCursor'] as String?);
  }
}
