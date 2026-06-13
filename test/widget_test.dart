import 'package:dcpl_user/app/routes/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('route paths are defined', () {
    expect(AppRoutes.login, '/login');
    expect(AppRoutes.projects, '/projects');
    expect(AppRoutes.requests, '/requests');
    expect(AppRoutes.newRequest, '/new-request');
  });
}
