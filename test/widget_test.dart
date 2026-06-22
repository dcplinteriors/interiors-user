import 'package:dcpl_user/app/routes/app_routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('route paths are defined', () {
    expect(AppRoutes.login, '/login');
    expect(AppRoutes.workOrders, '/work-orders');
    expect(AppRoutes.requests, '/requests');
    expect(AppRoutes.account, '/account');
    expect(AppRoutes.newRequest, '/new-request');
  });
}
