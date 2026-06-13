import 'dart:async';

import 'package:flutter/foundation.dart';

/// Drives go_router to re-run its `redirect` whenever the auth state changes
/// (sign-in / sign-out), so login/logout navigation happens automatically.
class AuthRefresh extends ChangeNotifier {
  AuthRefresh(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
