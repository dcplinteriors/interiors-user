import 'dart:async';

import 'package:dcpl_user/app/router/auth_refresh.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notifies listeners on each stream event and stops after dispose', () async {
    final stream = StreamController<dynamic>();
    final refresh = AuthRefresh(stream.stream);

    var notifications = 0;
    refresh.addListener(() => notifications++);

    stream.add(null);
    await Future<void>.delayed(Duration.zero);
    stream.add(null);
    await Future<void>.delayed(Duration.zero);

    expect(notifications, 2);

    refresh.dispose();
    await stream.close();
  });
}
