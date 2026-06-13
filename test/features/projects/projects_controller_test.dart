import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:dcpl_user/features/projects/data/project_repository.dart';
import 'package:dcpl_user/features/projects/projects_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockProjectRepository extends Mock implements ProjectRepository {}

void main() {
  late MockProjectRepository repo;
  late ProjectsController controller;

  const project = Project(
    id: 'p1',
    particular: 'Lobby',
    clientName: 'Acme',
    date: '2026-06-06',
    po: 'PO_26-27_06/0001',
    supervisorId: 'sup1',
    status: 'active',
    createdAt: '2026-06-06T00:00:00.000Z',
  );

  setUp(() {
    repo = MockProjectRepository();
    controller = ProjectsController(repo);
  });

  test('fetch() populates projects and cursor on success', () async {
    when(() => repo.list(cursor: any(named: 'cursor')))
        .thenAnswer((_) async => (items: [project], nextCursor: 'c1'));
    await controller.fetch();
    expect(controller.projects, [project]);
    expect(controller.hasMore, isTrue);
    expect(controller.isLoading.value, isFalse);
    expect(controller.error.value, isNull);
  });

  test('fetch() sets the error message on ApiException', () async {
    when(() => repo.list(cursor: any(named: 'cursor'))).thenThrow(ApiException(500, 'boom'));
    await controller.fetch();
    expect(controller.error.value, 'boom');
    expect(controller.projects, isEmpty);
    expect(controller.isLoading.value, isFalse);
  });

  test('loadMore() appends the next page and clears the cursor', () async {
    const p2 = Project(
      id: 'p2',
      particular: 'Tower',
      clientName: 'Acme',
      date: '2026-06-05',
      po: 'PO_26-27_06/0002',
      supervisorId: 'sup1',
      status: 'active',
      createdAt: '2026-06-05T00:00:00.000Z',
    );
    when(() => repo.list(cursor: null))
        .thenAnswer((_) async => (items: [project], nextCursor: 'c1'));
    when(() => repo.list(cursor: 'c1'))
        .thenAnswer((_) async => (items: [p2], nextCursor: null));
    await controller.fetch();
    await controller.loadMore();
    expect(controller.projects, [project, p2]);
    expect(controller.hasMore, isFalse);
  });
}
