import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/router/router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/theme/accessible_theme.dart';
import 'package:vecinal/features/avisos/presentation/push_listener.dart';
import 'package:vecinal/features/media/presentation/photo_runtime.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class VecinalApp extends ConsumerWidget {
  const VecinalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final practice = ref.watch(practiceModeProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      theme: AccessibleTheme.light(),
      darkTheme: AccessibleTheme.dark(),
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => PhotoRuntime(
        child: PushListener(
          child: Column(
            children: [
              if (practice.value == true)
                Material(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context).practiceMode,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onTertiaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              await ref.read(practiceModeProvider.notifier).set(false);
                              ref.read(routerProvider).go(Routes.home);
                            },
                            child: Text(AppLocalizations.of(context).exitPractice),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(child: child!),
            ],
          ),
        ),
      ),
    );
  }
}
