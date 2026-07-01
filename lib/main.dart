import 'dart:async';

import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:get/get.dart';

import 'app/app.dart';
import 'features/features.dart';
import 'firebase_options.dart';
import 'l10n/l10n.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) usePathUrlStrategy();
  // Initialize Firebase + register dependencies BEFORE runApp, so the app builds
  // straight into MaterialApp.router (mirrors the Admin app). Critical on web: a
  // second, NON-router MaterialApp shown during init (e.g. a splash screen) reads
  // the deep-linked URL as its legacy initial route, can't match it, and resets the
  // location to "/" — which then redirects to the default tab on every refresh.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  _registerDependencies();
  runApp(const DcplUserApp());
}

/// GetX is the DI container + state layer (go_router owns routing). Core services
/// come from the shared package.
void _registerDependencies() {
  Get.put(AuthService(), permanent: true);
  Get.put(ApiClient(Get.find<AuthService>()), permanent: true);
  // Single typed endpoint layer; every repo delegates to it.
  Get.put(DcplApi(Get.find<ApiClient>()), permanent: true);

  // Wake a scaled-to-zero backend instance during launch so the first data screen
  // doesn't hit a cold start. Fire-and-forget; never throws.
  unawaited(Get.find<ApiClient>().warmUp());

  Get.lazyPut<WorkOrderRepository>(() => ApiWorkOrderRepository(Get.find()));
  Get.lazyPut<MaterialRequestRepository>(
    () => ApiMaterialRequestRepository(Get.find()),
  );
  Get.lazyPut<MeRepository>(() => ApiMeRepository(Get.find()));
  Get.lazyPut<UploadService>(() => ApiUploadService(Get.find()));
  Get.lazyPut<AttachmentRepository>(() => ApiAttachmentRepository(Get.find()));

  // Drives the first-login password gate; permanent so its auth listener lives
  // for the whole session and the router can read its flags synchronously.
  Get.put(
    SessionController(Get.find<AuthService>(), Get.find<MeRepository>()),
    permanent: true,
  );

  Get.lazyPut(() => LoginController(Get.find()), fenix: true);
  Get.lazyPut(
    () => SetPasswordController(
      Get.find<AuthService>(),
      Get.find<MeRepository>(),
      Get.find<SessionController>(),
    ),
    fenix: true,
  );
  Get.lazyPut(
    () => WorkOrdersController(Get.find<WorkOrderRepository>()),
    fenix: true,
  );
  Get.lazyPut(
    () => MaterialRequestsController(
      Get.find<MaterialRequestRepository>(),
      Get.find<WorkOrderRepository>(),
    ),
    fenix: true,
  );
  Get.lazyPut(
    () =>
        AccountController(Get.find<MeRepository>(), Get.find<UploadService>()),
    fenix: true,
  );
}

class DcplUserApp extends StatelessWidget {
  const DcplUserApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    debugShowCheckedModeBanner: false,
    // Both themes are wired so switching works; the app is locked to dark for now
    // (no UI toggle). Flip to ThemeMode.system/.light for light.
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    themeMode: ThemeMode.dark,
    scaffoldMessengerKey: rootScaffoldMessengerKey,
    routerConfig: AppRouter.router,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
  );
}
