import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/router/router.dart';
import 'package:vecinal/features/avisos/data/providers.dart';
import 'package:vecinal/features/avisos/domain/notification_route.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Only a generic in-app message is shown in the foreground, even if remote text is malformed.
class PushListener extends ConsumerWidget {
  const PushListener({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(pushControllerProvider);
    ref.listen(pushNavigationProvider, (_, route) {
      if (route != null) {
        ref.read(routerProvider).go(route);
        ref.read(pushNavigationProvider.notifier).clear();
      }
    });
    final message = ref.watch(foregroundPushProvider);
    final texts = AppLocalizations.of(context);
    return Column(
      children: [
        if (message != null)
          Material(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_outlined),
                    const SizedBox(width: 12),
                    Expanded(child: Text(texts.pushGenericUpdate)),
                    if (routeFor(message) != null)
                      TextButton(
                        onPressed: () {
                          ref.read(foregroundPushProvider.notifier).dismiss();
                          ref.read(pushControllerProvider.notifier).open(message);
                        },
                        child: Text(texts.pushOpen),
                      ),
                    IconButton(
                      tooltip: texts.pushDismiss,
                      onPressed: () => ref.read(foregroundPushProvider.notifier).dismiss(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: child),
      ],
    );
  }
}
