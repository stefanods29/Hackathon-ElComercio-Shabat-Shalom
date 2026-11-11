import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/platform/pilot_platforms.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/ui/large_button.dart';
import 'package:vecinal/core/ui/spaced.dart';
import 'package:vecinal/core/ui/wrapping_app_bar.dart';
import 'package:vecinal/features/directorio/domain/directory.dart';
import 'package:vecinal/features/directorio/domain/search.dart';
import 'package:vecinal/features/directorio/presentation/directory_page.dart';
import 'package:vecinal/features/emergencias/data/emergency_contacts.dart';
import 'package:vecinal/features/emergencias/data/emergency_providers.dart';
import 'package:vecinal/features/emergencias/domain/emergency.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_ui.dart';
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

/// An action of the practice sheet (simulations for a demo, never real).
class PracticeAction {
  const PracticeAction({required this.icon, required this.label, required this.onSelected});
  final IconData icon;
  final String label;
  final VoidCallback onSelected;
}

/// Frame of every emergency screen: the title bar with the "Práctica" chip while practicing, and
/// a list with even gaps. [body] replaces the list (tabs); [bottom] goes under the title.
class EmergencyLayout extends ConsumerWidget {
  const EmergencyLayout({
    super.key,
    required this.title,
    this.children = const [],
    this.practiceActions = const [],
    this.body,
    this.bottom,
    this.floatingActionButton,
    this.gap = 16,
  });
  final String title;
  final List<Widget> children;
  final List<PracticeAction> practiceActions;
  final Widget? body;
  final PreferredSizeWidget? bottom;
  final Widget? floatingActionButton;
  final double gap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final practice = ref.watch(emergencyScopeProvider)?.practice == true;
    // A long title keeps its room: the chip shrinks to its icon instead of covering it.
    final compact = emergencyLargeText(context) || _crowdedTitle(context, title);
    return Scaffold(
      appBar: wrappingAppBar(
        context,
        title,
        actions: [if (practice) PracticeChip(actions: practiceActions, compact: compact)],
        actionsWidth: practice
            ? (compact ? 64 : _fullChipWidth * MediaQuery.textScalerOf(context).scale(1))
            : 0,
        bottom: bottom,
      ),
      floatingActionButton: floatingActionButton,
      body: SafeArea(
        child:
            body ??
            ListView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, floatingActionButton == null ? 32 : 112),
              children: spaced(children, gap: gap),
            ),
      ),
    );
  }
}

/// Room the full "Práctica" chip takes at normal text size, margin included.
const _fullChipWidth = 150.0;

/// True when the title would not fit on one line next to the full chip.
bool _crowdedTitle(BuildContext context, String title) {
  final theme = Theme.of(context);
  final scaler = MediaQuery.textScalerOf(context);
  final painter = TextPainter(
    text: TextSpan(
      text: title,
      style: theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge,
    ),
    textDirection: Directionality.of(context),
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  final leading = ModalRoute.of(context)?.impliesAppBarDismissal == true ? 56.0 : 0.0;
  final spacing = theme.appBarTheme.titleSpacing ?? NavigationToolbar.kMiddleSpacing;
  final available = MediaQuery.sizeOf(context).width - leading - 2 * spacing;
  final crowded = painter.width + _fullChipWidth * scaler.scale(1) > available;
  painter.dispose();
  return crowded;
}

/// "Práctica" in the title bar: the honest notice in one word. Tapping it explains practice and
/// offers the simulations of the screen.
class PracticeChip extends StatelessWidget {
  const PracticeChip({super.key, this.actions = const [], this.compact = false});
  final List<PracticeAction> actions;

  /// With large text only the icon stays, so the title keeps its room.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final colors = pillColors(Theme.of(context).colorScheme, NoticeTone.warning);
    if (compact) {
      // The same amber mark in a circle; its name is read by the screen reader and on long press.
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: IconButton(
          tooltip: t.practiceChip,
          style: IconButton.styleFrom(backgroundColor: colors.background),
          icon: Icon(Icons.science_outlined, color: colors.foreground),
          onPressed: () => _open(context),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: ActionChip(
        avatar: Icon(Icons.science_outlined, color: colors.foreground, size: 20),
        label: Text(
          t.practiceChip,
          style: TextStyle(color: colors.foreground, fontWeight: FontWeight.w700),
        ),
        backgroundColor: colors.background,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        elevation: 0,
        onPressed: () => _open(context),
      ),
    );
  }

  Future<void> _open(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) {
      final t = AppLocalizations.of(sheet);
      final theme = Theme.of(sheet);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 12,
            children: [
              Row(
                children: [
                  const Icon(Icons.science_outlined),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t.practiceMode, style: theme.textTheme.titleLarge)),
                ],
              ),
              Text(
                t.emergencyPracticeShort,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                t.emergencyPracticeHelp,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 4),
                Semantics(
                  header: true,
                  child: Text(t.simulationTitle, style: theme.textTheme.titleMedium),
                ),
                for (final action in actions)
                  OutlinedButton.icon(
                    icon: Icon(action.icon),
                    label: Text(action.label),
                    onPressed: () {
                      Navigator.pop(sheet);
                      action.onSelected();
                    },
                  ),
              ],
              FilledButton(onPressed: () => Navigator.pop(sheet), child: Text(t.closeAction)),
            ],
          ),
        ),
      );
    },
  );
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
          const EmergencyAlternatives(),
          EmergencyNotice(
            icon: Icons.lock_outline,
            text: t.emergencySessionRequired,
            tone: NoticeTone.info,
          ),
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

/// The red strip with the official numbers: always one tap away. On "Mi pedido" it also prepares
/// an SMS for the neighbor's contacts and shows the nearest meeting point.
class EmergencyAlternatives extends ConsumerWidget {
  const EmergencyAlternatives({super.key, this.request});
  final OwnHelpRequest? request;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = callColors(theme.colorScheme);
    final directory = ref.watch(publicEmergencyDirectoryProvider).value;
    final scope = ref.watch(emergencyScopeProvider);
    final entries = directory?.entries ?? <PublicEmergencyEntry>[];
    final numbers = entries.where((e) => e.number != null).toList();
    final origin = request?.approximateLocation ?? ref.watch<GeoPoint>(directoryOriginProvider);
    final points =
        entries
            .where((e) => e.kind == PublicEmergencyKind.meetingPoint && e.location != null)
            .toList()
          ..sort(
            (a, b) => approximateDistanceMeters(
              origin,
              a.location!,
            ).compareTo(approximateDistanceMeters(origin, b.location!)),
          );
    final nearest = points.firstOrNull;
    final buttons = [
      for (final entry in numbers)
        (
          entry.number!,
          emergencyShortName(t, label: entry.label, number: entry.number!),
          t.emergencyCallSemantics(entry.label, entry.number!),
          () => _call(context, ref, entry.number!),
        ),
    ];
    final onStrip = TextStyle(color: colors.onStrip);
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.strip, borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            Semantics(
              header: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(Icons.warning_amber_rounded, color: colors.onStrip, size: 26),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      request == null ? t.emergencyCallNow : t.emergencyCallIfWorse,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colors.onStrip,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // While the directory opens, the sentence itself keeps the three numbers.
            if (buttons.isEmpty)
              Text(t.emergencyLifeRisk, style: onStrip)
            else
              EmergencyCallButtons(buttons: buttons),
            if (request != null && scope != null)
              OutlinedButton.icon(
                icon: const Icon(Icons.sms_outlined),
                label: Text(t.emergencyPrepareSms),
                onPressed: () => _prepareSms(context, ref, scope, request!),
              ),
            if (nearest != null) ...[
              Text(
                t.emergencyNearestPoint(nearest.label),
                style: onStrip.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                t.sourceAndDate(
                  nearest.sourceName,
                  DateFormat.yMd(t.localeName).format(nearest.verifiedAt),
                ),
                style: onStrip,
              ),
              if (nearest.staleAt(ref.watch(clockProvider)()))
                Text(t.emergencyStale, style: onStrip),
              Text(t.emergencyMapLimit, style: onStrip.copyWith(fontSize: 13)),
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
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _call(BuildContext context, WidgetRef ref, String number) async {
    final t = AppLocalizations.of(context);
    if (ref.read(practiceModeProvider).value != false) {
      emergencyMessage(context, t.emergencyPracticeExternal);
      return;
    }
    var opened = false;
    try {
      opened = await ref.read(phoneDialerProvider).dial(number);
    } catch (_) {}
    if (!opened && context.mounted) emergencyMessage(context, t.callFailed);
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

/// Shows a message at once: an older one in the queue would arrive late in an emergency.
void emergencyMessage(BuildContext context, String text) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(text)));
