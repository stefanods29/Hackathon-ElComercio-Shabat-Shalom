import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/sync/sync_service.dart';
import 'package:vecinal/core/time/time_ago.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Offline notice: how old the data the neighbor is looking at is (section 7.3).
class ConnectionBanner extends ConsumerWidget {
  const ConnectionBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider).value ?? SyncStatus.initial;
    if (status.connected) {
      return const SizedBox.shrink();
    }
    final texts = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final lastSyncedAt = status.lastSyncedAt;
    final detail = lastSyncedAt == null
        ? texts.statusSavedOnPhoneDetail
        : texts.dataFrom(timeAgo(lastSyncedAt, ref.watch(clockProvider)(), texts));
    return Semantics(
      liveRegion: true,
      child: Material(
        color: scheme.surfaceContainerHighest,
        child: ListTile(
          leading: Icon(Icons.cloud_off, color: scheme.onSurface),
          title: Text(texts.offline, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(detail),
        ),
      ),
    );
  }
}
