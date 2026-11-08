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
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_off, color: scheme.onSecondaryContainer),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      texts.offline,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSecondaryContainer,
                      ),
                    ),
                    Text(detail, style: TextStyle(color: scheme.onSecondaryContainer)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
