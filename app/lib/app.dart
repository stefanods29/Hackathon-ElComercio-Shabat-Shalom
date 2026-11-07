import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/router/router.dart';
import 'package:vecinal/core/theme/accessible_theme.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class VecinalApp extends ConsumerWidget {
  const VecinalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      theme: AccessibleTheme.light(),
      darkTheme: AccessibleTheme.dark(),
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
