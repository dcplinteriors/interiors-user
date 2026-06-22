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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) usePathUrlStrategy();
  runApp(const DcplUserApp());
}

/// GetX is the DI container + state layer (go_router owns routing). Core services
/// come from the shared package.
void _registerDependencies() {
  Get.put(AuthService(), permanent: true);
  Get.put(ApiClient(Get.find<AuthService>()), permanent: true);
  // Single typed endpoint layer; every repo delegates to it.
  Get.put(DcplApi(Get.find<ApiClient>()), permanent: true);

  Get.lazyPut<WorkOrderRepository>(() => ApiWorkOrderRepository(Get.find()));
  Get.lazyPut<MaterialRequestRepository>(
    () => ApiMaterialRequestRepository(Get.find()),
  );
  Get.lazyPut<MeRepository>(() => ApiMeRepository(Get.find()));
  Get.lazyPut<UploadService>(() => ApiUploadService(Get.find()));

  Get.lazyPut(() => LoginController(Get.find()), fenix: true);
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

/// Shows the brand splash while Firebase initializes + dependencies register, then hands off to
/// the router (which redirects to login or home).
class DcplUserApp extends StatefulWidget {
  const DcplUserApp({super.key});

  @override
  State<DcplUserApp> createState() => _DcplUserAppState();
}

class _DcplUserAppState extends State<DcplUserApp> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _registerDependencies();
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const SplashScreen(),
      );
    }
    return MaterialApp.router(
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
}
