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
                      padding: const EdgeInsets.fromLTRB(20, 2, 8, 2),
                      child: Row(
                        children: [
                          Icon(
                            Icons.science_outlined,
                            size: 18,
                            color: Theme.of(context).colorScheme.onTertiaryContainer,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context).practiceMode,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: Theme.of(context).colorScheme.onTertiaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (!ref.watch(practiceLockedProvider))
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer,
                                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
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
