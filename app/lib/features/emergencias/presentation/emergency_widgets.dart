import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/platform/pilot_platforms.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/ui/large_button.dart';
import 'package:vecinal/core/ui/simple_mode.dart';
import 'package:vecinal/features/directorio/domain/directory.dart';
import 'package:vecinal/features/directorio/domain/search.dart';
import 'package:vecinal/features/directorio/presentation/directory_page.dart';
import 'package:vecinal/features/emergencias/data/emergency_contacts.dart';
import 'package:vecinal/features/emergencias/data/emergency_providers.dart';
import 'package:vecinal/features/emergencias/domain/emergency.dart';
import 'package:vecinal/features/emergencias/public_emergency_directory.dart';
import 'package:vecinal/features/mapa/presentation/map_view.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';
import 'package:vecinal/l10n/app_localizations.dart';

String needLabel(AppLocalizations t, EmergencyNeed need) => switch (need) {
  EmergencyNeed.water => t.emergencyNeedWater,
  EmergencyNeed.food => t.emergencyNeedFood,
  EmergencyNeed.medicine => t.emergencyNeedMedicine,
  EmergencyNeed.transport => t.emergencyNeedTransport,
  EmergencyNeed.shelter => t.emergencyNeedShelter,
  EmergencyNeed.other => t.emergencyNeedOther,
};
String resourceLabel(AppLocalizations t, ResourceKind kind) => switch (kind) {
  ResourceKind.water => t.emergencyNeedWater,
  ResourceKind.food => t.emergencyNeedFood,
  ResourceKind.medicine => t.emergencyNeedMedicine,
  ResourceKind.shelter => t.emergencyNeedShelter,
  ResourceKind.meetingPoint => t.emergencyMeetingPoint,
  ResourceKind.other => t.emergencyNeedOther,
};
String requestStatusLabel(AppLocalizations t, HelpRequestStatus status) => switch (status) {
  HelpRequestStatus.local => t.statusSavedOnPhone,
  HelpRequestStatus.sent => t.statusSent,
  HelpRequestStatus.seen => t.emergencyRequestSeen,
  HelpRequestStatus.onTheWay => t.emergencyRequestOnTheWay,
  HelpRequestStatus.attended => t.emergencyRequestAttended,
  HelpRequestStatus.referred => t.emergencyRequestReferred,
  HelpRequestStatus.closedUnattended => t.emergencyRequestClosed,
};

class EmergencyLayout extends ConsumerWidget {
  const EmergencyLayout({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            for (final child in children)
              Padding(padding: const EdgeInsets.only(bottom: 16), child: child),
          ],
        ),
      ),
    );
    if (ref.watch(simpleModeProvider).value != true) return content;
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(
          MediaQuery.textScalerOf(context).scale(1) * simpleModeTextScale,
        ),
      ),
      child: content,
    );
  }
}

/// Replaces all private form state whenever the account/profile/mode changes.
class EmergencyScopeGate extends ConsumerWidget {
  const EmergencyScopeGate({super.key, required this.title, required this.builder});
  final String title;
  final Widget Function(EmergencyScope scope) builder;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = ref.watch(emergencyScopeProvider);
    final t = AppLocalizations.of(context);
    if (scope == null) {
      return EmergencyLayout(
        title: title,
        children: [
          Text(t.emergencySessionRequired),
          LargeButton(
            icon: Icons.local_phone_outlined,
            label: t.emergencyTitle,
            onPressed: () => context.push(Routes.emergency),
          ),
        ],
      );
    }
    return KeyedSubtree(key: ValueKey(scope.key), child: builder(scope));
  }
}

class EmergencyAlternatives extends ConsumerWidget {
  const EmergencyAlternatives({super.key, this.request});
  final OwnHelpRequest? request;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final directory = ref.watch(publicEmergencyDirectoryProvider).value;
    final scope = ref.watch(emergencyScopeProvider);
    final origin = request?.approximateLocation ?? ref.watch<GeoPoint>(directoryOriginProvider);
    final points =
        (directory?.entries ?? <PublicEmergencyEntry>[])
            .where((e) => e.kind == PublicEmergencyKind.meetingPoint && e.location != null)
            .toList()
          ..sort(
            (a, b) => approximateDistanceMeters(
              origin,
              a.location!,
            ).compareTo(approximateDistanceMeters(origin, b.location!)),
          );
    final nearest = points.firstOrNull;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            Semantics(
              header: true,
              child: Text(t.emergencyLifeRisk, style: Theme.of(context).textTheme.titleMedium),
            ),
            Text(t.emergencyAlternativesHelp),
            for (final entry in (directory?.entries ?? <PublicEmergencyEntry>[]).where(
              (e) => e.number != null,
            ))
              LargeButton(
                icon: Icons.phone_outlined,
                label: '${t.callAction} ${entry.label} · ${entry.number}',
                onPressed: () async {
                  if (ref.read(practiceModeProvider).value != false) {
                    emergencyMessage(context, t.emergencyPracticeExternal);
                    return;
                  }
                  var opened = false;
                  try {
                    opened = await ref.read(phoneDialerProvider).dial(entry.number!);
                  } catch (_) {}
                  if (!opened && context.mounted) emergencyMessage(context, t.callFailed);
                },
              ),
            TextButton.icon(
              icon: const Icon(Icons.source_outlined),
              label: Text(t.emergencyTitle),
              onPressed: () => context.push(Routes.emergency),
            ),
            if (request != null && scope != null)
              OutlinedButton.icon(
                icon: const Icon(Icons.sms_outlined),
                label: Text(t.emergencyPrepareSms),
                onPressed: () => _prepareSms(context, ref, scope, request!),
              ),
            if (nearest != null) ...[
              Text(t.emergencyNearestPoint(nearest.label)),
              Text(
                t.sourceAndDate(
                  nearest.sourceCitation,
                  DateFormat.yMd(t.localeName).format(nearest.verifiedAt),
                ),
              ),
              if (nearest.staleAt(ref.watch(clockProvider)())) Text(t.emergencyStale),
              Text(t.emergencyMapLimit),
              OutlinedButton.icon(
                icon: const Icon(Icons.map_outlined),
                label: Text(t.openOnMap),
                onPressed: () => context.push(
                  Routes.emergencyMap,
                  extra: MapFocus([
                    MapMarker(
                      label: nearest.label,
                      location: nearest.location!,
                      detail: nearest.address,
                    ),
                    MapMarker(label: t.emergencyApproximateLocation, location: origin),
                  ]),
                ),
              ),
            ] else
              Text(t.emergencyNoLocations),
          ],
        ),
      ),
    );
  }

  Future<void> _prepareSms(
    BuildContext context,
    WidgetRef ref,
    EmergencyScope scope,
    OwnHelpRequest request,
  ) async {
    final t = AppLocalizations.of(context);
    final body = t.emergencySmsBody(
      needLabel(t, request.need),
      request.description,
      request.locationLabel,
      request.approximateLocation.lat.toStringAsFixed(3),
      request.approximateLocation.lng.toStringAsFixed(3),
    );
    if (ref.read(emergencyScopeProvider)?.key != scope.key) return;
    if (scope.practice) {
      await showDialog<void>(
        context: context,
        builder: (dialog) => EmergencyScopedDialog(
          scopeKey: scope.key,
          child: AlertDialog(
            title: Text(t.emergencyPrepareSms),
            content: SingleChildScrollView(child: Text('${t.emergencyPracticeExternal}\n\n$body')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialog), child: Text(t.cancelAction)),
            ],
          ),
        ),
      );
      return;
    }
    final contacts = ref.read(emergencyContactsProvider).value ?? <EmergencyContact>[];
    if (contacts.isEmpty) {
      unawaited(context.push<void>(Routes.emergencyContacts));
      return;
    }
    final recipient = await showDialog<EmergencyContact>(
      context: context,
      builder: (dialog) => EmergencyScopedDialog(
        scopeKey: scope.key,
        child: _SmsRecipientDialog(body: body),
      ),
    );
    if (recipient == null ||
        !context.mounted ||
        ref.read(emergencyScopeProvider)?.key != scope.key ||
        ref.read(practiceModeProvider).value != false) {
      return;
    }
    // Recheck after the picker: deletion/revocation must not use a captured contact.
    final current = ref.read(emergencyContactsProvider).value ?? <EmergencyContact>[];
    if (!current.any((c) => c.id == recipient.id && c.phone == recipient.phone)) return;
    var opened = false;
    try {
      opened = await ref.read(smsComposerProvider).compose(recipient: recipient.phone, body: body);
    } catch (_) {}
    if (context.mounted) {
      emergencyMessage(context, opened ? t.emergencySmsNotSent : t.emergencySmsFailed);
    }
  }
}

class _SmsRecipientDialog extends ConsumerWidget {
  const _SmsRecipientDialog({required this.body});
  final String body;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final state = ref.watch(emergencyContactsProvider);
    final contacts = !state.isLoading && !state.hasError
        ? state.value ?? <EmergencyContact>[]
        : <EmergencyContact>[];
    return AlertDialog(
      title: Text(t.emergencyChooseContact),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            if (contacts.isEmpty)
              Text(t.emergencyContactsUnavailable)
            else ...[
              Text(body),
              Text(t.emergencySmsNotSent),
              for (final contact in contacts)
                ListTile(
                  minVerticalPadding: 12,
                  title: Text(contact.name),
                  subtitle: Text(contact.phone),
                  onTap: () => Navigator.pop(context, contact),
                ),
            ],
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancelAction))],
    );
  }
}

class EmergencyScopedDialog extends ConsumerStatefulWidget {
  const EmergencyScopedDialog({super.key, required this.scopeKey, required this.child});
  final String scopeKey;
  final Widget child;
  @override
  ConsumerState<EmergencyScopedDialog> createState() => _EmergencyScopedDialogState();
}

class _EmergencyScopedDialogState extends ConsumerState<EmergencyScopedDialog> {
  bool _invalidated = false;
  @override
  Widget build(BuildContext context) {
    ref.listen(emergencyScopeProvider, (_, next) {
      if (next?.key != widget.scopeKey && !_invalidated) setState(() => _invalidated = true);
    });
    if (ref.watch(emergencyScopeProvider)?.key != widget.scopeKey) _invalidated = true;
    if (!_invalidated) return widget.child;
    final t = AppLocalizations.of(context);
    return AlertDialog(
      content: Text(t.emergencySessionChanged),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancelAction))],
    );
  }
}

void emergencyMessage(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
