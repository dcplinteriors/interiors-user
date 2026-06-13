import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Firebase config for the DCPL User (supervisor) app.
///
/// Its own web-app registration within the shared `dcpl-interiors` project (distinct
/// appId from the Admin app; Auth/Firestore/Storage are project-scoped and shared).
/// Android/iOS options can be added later via `flutterfire configure`.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'Firebase is configured for web only so far. '
      'Run `flutterfire configure` to add Android/iOS for the dcpl-interiors project.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC7r-96NGuOzRsfUE0fvmvVS16o9rlWS5I',
    appId: '1:385822650057:web:330945eeb5db7e3ad62718',
    messagingSenderId: '385822650057',
    projectId: 'dcpl-interiors',
    authDomain: 'dcpl-interiors.firebaseapp.com',
    storageBucket: 'dcpl-interiors.firebasestorage.app',
  );
}
