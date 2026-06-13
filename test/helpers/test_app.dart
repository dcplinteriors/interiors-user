import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:dcpl_user/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Wraps [home] in a MaterialApp with the l10n delegates and the global snackbar
/// key, so views and snackbars render the same way as in the real app.
Widget testApp(Widget home) => MaterialApp(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );
