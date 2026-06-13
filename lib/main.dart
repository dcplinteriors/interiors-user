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
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  _registerDependencies();
  runApp(const DcplUserApp());
}

/// GetX is the DI container + state layer (go_router owns routing). Core services
/// come from the shared package.
void _registerDependencies() {
  Get.put(AuthService(), permanent: true);
  Get.put(ApiClient(Get.find<AuthService>()), permanent: true);

  Get.lazyPut<ProjectRepository>(() => ApiProjectRepository(Get.find()));
  Get.lazyPut<MaterialRequestRepository>(() => ApiMaterialRequestRepository(Get.find()));
  Get.lazyPut<UploadService>(() => ApiUploadService(Get.find()));

  Get.lazyPut(() => LoginController(Get.find()), fenix: true);
  Get.lazyPut(() => ProjectsController(Get.find<ProjectRepository>()), fenix: true);
  Get.lazyPut(
    () => MaterialRequestsController(Get.find<MaterialRequestRepository>()),
    fenix: true,
  );
}

class DcplUserApp extends StatelessWidget {
  const DcplUserApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        routerConfig: AppRouter.router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      );
}
