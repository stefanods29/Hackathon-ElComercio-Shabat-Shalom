import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/router/router.dart';
import 'package:vecinal/core/theme/accessible_theme.dart';
import 'package:vecinal/core/ui/simple_mode.dart';
import 'package:vecinal/features/avisos/presentation/push_listener.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class VecinalApp extends ConsumerWidget {
  const VecinalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simpleMode = ref.watch(simpleModeProvider).value == true;
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      theme: AccessibleTheme.light(),
      darkTheme: AccessibleTheme.dark(),
      highContrastTheme: AccessibleTheme.highContrastLight(),
      highContrastDarkTheme: AccessibleTheme.highContrastDark(),
      themeMode: ThemeMode.system,
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: simpleModeScaler(media.textScaler, simpleMode)),
          child: PushListener(child: child!),
        );
      },
    );
  }
}
