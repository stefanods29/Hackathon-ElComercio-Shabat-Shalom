import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/l10n/app_localizations.dart';
import 'package:vecinal/prototype_router.dart';

/// App principal del prototipo con tema accesible y paleta de colores definida.
class PrototypeApp extends StatelessWidget {
  const PrototypeApp({super.key, this.router});

  final GoRouter? router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Winki',
      debugShowCheckedModeBanner: false,
      theme: winkiTheme(),
      locale: const Locale('es'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router ?? prototypeRouter,
    );
  }
}
