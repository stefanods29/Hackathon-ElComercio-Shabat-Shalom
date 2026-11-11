import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/core/platform/pilot_platforms.dart';
import 'package:vecinal/core/theme/accessible_theme.dart';
import 'package:vecinal/core/ui/large_button.dart';
import 'package:vecinal/features/directorio/presentation/directory_page.dart';
import 'package:vecinal/features/emergencias/data/emergency_providers.dart';
import 'package:vecinal/features/emergencias/domain/emergency.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_ui.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_widgets.dart';
import 'package:vecinal/l10n/app_localizations.dart';

final emergencyNowProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  final now = ref.watch(clockProvider);
  yield now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => now());
});

/// Six needs with a big icon each (section 5.4): the second of the three taps.
class EmergencyNeedsPage extends ConsumerWidget {
  const EmergencyNeedsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return EmergencyScopeGate(
      title: t.emergencyNeedHelp,
      builder: (scope) {
        final available = ref.watch(emergencySnapshotProvider).value?.coverageVerified == true;
        final scheme = Theme.of(context).colorScheme;
        return EmergencyLayout(
          title: t.emergencyNeedHelp,
          children: [
            Semantics(
              header: true,
              child: Text(t.emergencyChooseNeed, style: Theme.of(context).textTheme.headlineSmall),
            ),
            if (!available)
              EmergencyNotice(
                icon: Icons.info_outline,
                text: t.emergencyNoCoverage,
                liveRegion: true,
              ),
            EmergencyTileGrid(
              children: [
                for (final need in EmergencyNeed.values)
                  FilledButton(
                    onPressed: available
                        ? () => context.push('/emergencia/nuevo/${need.name}')
                        : null,
                    style: emergencyCardStyle(
                      scheme,
                      minimumSize: const Size(48, 128),
                      padding: const EdgeInsets.all(16),
                      alignment: Alignment.center,
                      enabled: available,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        EmergencyIconBadge(
                          icon: needIcon(need),
                          size: 60,
                          background: available ? null : scheme.surfaceContainerHighest,
                          foreground: available ? null : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          needLabel(t, need),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const EmergencyAlternatives(),
          ],
        );
      },
    );
  }
}

class HelpRequestFormPage extends StatelessWidget {
  const HelpRequestFormPage({super.key, required this.need});
  final EmergencyNeed need;
  @override
  Widget build(BuildContext context) => EmergencyScopeGate(
    title: AppLocalizations.of(context).emergencyNeedHelp,
    builder: (scope) =>
        _HelpRequestForm(key: ValueKey('${scope.key}:${need.name}'), scope: scope, need: need),
  );
}

class _HelpRequestForm extends ConsumerStatefulWidget {
  const _HelpRequestForm({super.key, required this.scope, required this.need});
  final EmergencyScope scope;
  final EmergencyNeed need;
  @override
  ConsumerState<_HelpRequestForm> createState() => _HelpRequestFormState();
}

/// Hides the character counter: the limit still applies, but "25/500" is noise in an emergency.
Widget? _noCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) => null;

class _HelpRequestFormState extends ConsumerState<_HelpRequestForm> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _id = newLocalId();
  final _idempotencyKey = newLocalId();
  bool _initialized = false;
  bool _busy = false;
  bool _listening = false;
  CommentDictation? _dictation;
  String? _error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final t = AppLocalizations.of(context);
    _description.text = t.emergencyDefaultRequest(needLabel(t, widget.need));
    _initialized = true;
  }

  @override
  void dispose() {
    if (_dictation != null) unawaited(_dictation!.stop());
    _description.dispose();
    _location.dispose();
    super.dispose();
  }

  bool get _current => mounted && ref.read(emergencyScopeProvider)?.key == widget.scope.key;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final available = ref.watch(emergencySnapshotProvider).value?.coverageVerified == true;
    final online = ref.watch(syncStatusProvider).value?.connected == true;
    return EmergencyLayout(
      title: widget.need == EmergencyNeed.other
          ? t.emergencyNeedHelp
          : t.emergencyRequestTitle(needLabel(t, widget.need).toLowerCase()),
      children: [
        if (!available)
          EmergencyNotice(icon: Icons.info_outline, text: t.emergencyNoCoverage, liveRegion: true),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 20,
            children: [
              TextFormField(
                controller: _description,
                enabled: !_busy,
                maxLength: 500,
                buildCounter: _noCounter,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: t.emergencyChooseNeed,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  suffixIcon: IconButton(
                    tooltip: _listening ? t.emergencyStopDictation : t.emergencyDictation,
                    icon: Icon(_listening ? Icons.stop_circle_outlined : Icons.mic_none),
                    onPressed: _busy ? null : _dictate,
                  ),
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? t.emergencyRequired : null,
              ),
              TextFormField(
                controller: _location,
                enabled: !_busy,
                maxLength: 120,
                buildCounter: _noCounter,
                decoration: InputDecoration(
                  labelText: t.emergencyWhereAreYou,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  hintText: t.emergencyLocationHint,
                  helperText: t.emergencyLocationHelp,
                  helperMaxLines: 3,
                  prefixIcon: const Icon(Icons.place_outlined),
                ),
              ),
            ],
          ),
        ),
        if (!widget.scope.practice && !online)
          EmergencyNotice(icon: Icons.cloud_off_outlined, text: t.emergencyOfflineSaveLater),
        if (_error != null)
          EmergencyNotice(
            icon: Icons.error_outline,
            text: _error!,
            tone: NoticeTone.danger,
            liveRegion: true,
          ),
        LargeButton(
          icon: Icons.send_outlined,
          label: widget.scope.practice ? t.emergencySavePractice : t.emergencySendRequest,
          onPressed: _busy || !available ? null : _save,
        ),
        const EmergencyAlternatives(),
      ],
    );
  }

  Future<void> _dictate() async {
    final t = AppLocalizations.of(context);
    if (!_current) return;
    // Dictation only fills this field on the phone, so it also works in practice.
    final dictation = _dictation ??= ref.read<CommentDictation>(commentDictationProvider);
    if (_listening) {
      await dictation.stop();
      if (_current) setState(() => _listening = false);
      return;
    }
    var started = false;
    try {
      started = await dictation.start(
        (words) {
          if (_current) _description.text = words.length > 500 ? words.substring(0, 500) : words;
        },
        () {
          if (_current) {
            setState(() {
              _listening = false;
              _error = t.emergencyDictationFailed;
            });
          }
        },
      );
    } catch (_) {}
    if (!_current) {
      await dictation.stop();
      return;
    }
    setState(() {
      _listening = started;
      if (!started) _error = t.emergencyDictationFailed;
    });
  }

  Future<void> _save() async {
    if (!_current ||
        _busy ||
        !_form.currentState!.validate() ||
        ref.read(emergencySnapshotProvider).value?.coverageVerified != true) {
      return;
    }
    final t = AppLocalizations.of(context);
    final repository = ref.read(emergencyRepositoryProvider);
    final location = ref.read(directoryOriginProvider).approximate();
    // The reference is optional: without one the request keeps the suggested point of the zone.
    final reference = _location.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final request = await repository.saveRequest(
        HelpRequestDraft(
          id: _id,
          idempotencyKey: _idempotencyKey,
          need: widget.need,
          description: _description.text.trim(),
          locationLabel: reference.isEmpty ? t.emergencySuggestedLocation : reference,
          approximateLocation: location,
        ),
      );
      if (_current && mounted) context.replace('/emergencia/pedidos/${request.id}');
    } catch (_) {
      if (_current) setState(() => _error = t.emergencySaveFailed);
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }
}

class OwnHelpRequestPage extends StatelessWidget {
  const OwnHelpRequestPage({super.key, required this.requestId});
  final String requestId;
  @override
  Widget build(BuildContext context) => EmergencyScopeGate(
    title: AppLocalizations.of(context).emergencyMyRequest,
    builder: (scope) => _OwnHelpRequest(scope: scope, requestId: requestId),
  );
}

class _OwnHelpRequest extends ConsumerStatefulWidget {
  const _OwnHelpRequest({required this.scope, required this.requestId});
  final EmergencyScope scope;
  final String requestId;
  @override
  ConsumerState<_OwnHelpRequest> createState() => _OwnHelpRequestState();
}

class _OwnHelpRequestState extends ConsumerState<_OwnHelpRequest> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final snapshot = ref.watch(emergencySnapshotProvider);
    final request = snapshot.value?.requests.where((r) => r.id == widget.requestId).firstOrNull;
    final now = ref.watch(emergencyNowProvider).value ?? ref.watch(clockProvider)();
    if (request == null) {
      return EmergencyLayout(
        title: t.emergencyMyRequest,
        children: [
          if (snapshot.isLoading)
            const LinearProgressIndicator()
          else
            EmergencyNotice(
              icon: Icons.info_outline,
              text: t.emergencyRequestUnavailable,
              tone: NoticeTone.info,
            ),
          const EmergencyAlternatives(),
        ],
      );
    }
    final repository = ref.watch(emergencyRepositoryProvider);
    final practice = repository is PracticeEmergencyRepository ? repository : null;
    final canSimulate =
        request.status == HelpRequestStatus.local ||
        request.status == HelpRequestStatus.sent ||
        request.status == HelpRequestStatus.seen;
    return EmergencyLayout(
      title: t.emergencyMyRequest,
      practiceActions: [
        if (practice != null && canSimulate)
          PracticeAction(
            icon: Icons.fast_forward_outlined,
            label: t.simulationNextStep,
            onSelected: () => practice.simulateNextStep(request.id),
          ),
      ],
      children: [
        _StatusBanner(request: request, now: now),
        if (widget.scope.practice != true && ref.watch(syncStatusProvider).value?.connected != true)
          EmergencyNotice(icon: Icons.cloud_off_outlined, text: t.emergencyOfflineWarning),
        if (request.reason != null || request.nextStep != null)
          _ReasonCard(reason: request.reason, nextStep: request.nextStep),
        _NeedCard(request: request),
        _Timeline(request: request),
        if (request.canConfirmAttendance)
          LargeButton(
            icon: Icons.check_circle_outline,
            label: t.emergencyConfirmAttendance,
            onPressed: _busy ? null : () => _confirm(request),
          ),
        EmergencyAlternatives(request: request),
      ],
    );
  }

  Future<void> _confirm(OwnHelpRequest request) async {
    final t = AppLocalizations.of(context);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(t.emergencyConfirmAttendance),
        content: Text(t.emergencyConfirmAttendanceHelp),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(t.cancelAction)),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(t.emergencyConfirmAttendance),
          ),
        ],
      ),
    );
    if (accepted != true ||
        !mounted ||
        ref.read(emergencyScopeProvider)?.key != widget.scope.key ||
        ref
                .read(emergencySnapshotProvider)
                .value
                ?.requests
                .where((r) => r.id == request.id && r.canConfirmAttendance)
                .isNotEmpty !=
            true) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(emergencyRepositoryProvider).confirmAttendance(request.id);
    } catch (_) {
      if (mounted) emergencyMessage(context, t.emergencySaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// The state first, as a colored band with an icon and one short sentence (section 5.3).
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.request, required this.now});
  final OwnHelpRequest request;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = request.status;
    final (icon, background, foreground) = switch (status) {
      HelpRequestStatus.local => (
        Icons.phone_android,
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      HelpRequestStatus.sent => (
        Icons.cloud_done_outlined,
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      HelpRequestStatus.seen => (
        Icons.visibility_outlined,
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      HelpRequestStatus.onTheWay => (
        Icons.directions_walk,
        AccessibleTheme.action(scheme),
        AccessibleTheme.onAction(scheme),
      ),
      HelpRequestStatus.attended => (
        Icons.check_circle_outline,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      HelpRequestStatus.referred => (
        Icons.alt_route,
        scheme.surfaceContainerHigh,
        scheme.onSurface,
      ),
      HelpRequestStatus.closedUnattended => (
        Icons.cancel_outlined,
        scheme.surfaceContainerHigh,
        scheme.onSurface,
      ),
    };
    final help = switch (status) {
      HelpRequestStatus.local => t.emergencyRequestLocalHelp,
      HelpRequestStatus.sent => t.emergencyRequestSentHelp,
      HelpRequestStatus.seen => t.emergencyRequestSeenHelp,
      HelpRequestStatus.onTheWay => t.emergencyRequestOnTheWayHelp,
      HelpRequestStatus.attended => t.emergencyRequestAttendedHelp,
      HelpRequestStatus.referred ||
      HelpRequestStatus.closedUnattended => t.emergencyRequestClosedHelp,
    };
    final sentAt = request.sentAt;
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(child: Icon(icon, size: 40, color: foreground)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Text(
                      requestStatusLabel(t, status),
                      style: theme.textTheme.headlineSmall?.copyWith(color: foreground),
                    ),
                    Text(help, style: TextStyle(color: foreground, fontSize: 16, height: 1.4)),
                    if (status == HelpRequestStatus.sent && sentAt != null)
                      Text(
                        t.emergencyUnreviewedMinutes(
                          now.difference(sentAt).inMinutes.clamp(0, 999999).toInt(),
                        ),
                        style: TextStyle(color: foreground, fontWeight: FontWeight.w700),
                      ),
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

/// Why a request was referred or closed, and what to do now.
class _ReasonCard extends StatelessWidget {
  const _ReasonCard({this.reason, this.nextStep});
  final String? reason;
  final String? nextStep;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 8,
          children: [
            if (reason != null) Text(t.emergencyReason(reason!)),
            if (nextStep != null)
              Text(
                t.emergencyNextStep(nextStep!),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
          ],
        ),
      ),
    );
  }
}

/// What was asked and where, as the neighbor wrote it.
class _NeedCard extends StatelessWidget {
  const _NeedCard({required this.request});
  final OwnHelpRequest request;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EmergencyIconBadge(icon: needIcon(request.need)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(
                    needLabel(t, request.need),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(request.description),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: ExcludeSemantics(
                          child: Icon(
                            Icons.place_outlined,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(child: Text(request.locationLabel, style: muted)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The history as a timeline: steps done with their hour, the current one and what is left.
/// Nothing ahead is shown while the request is only on the phone: "Enviado" must not appear yet.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.request});
  final OwnHelpRequest request;

  static const _flow = [
    HelpRequestStatus.local,
    HelpRequestStatus.sent,
    HelpRequestStatus.seen,
    HelpRequestStatus.onTheWay,
    HelpRequestStatus.attended,
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    String hour(DateTime value) => DateFormat.Hm(t.localeName).format(value.toLocal());
    final entries = [...request.history];
    // The creation and the server receipt keep their hour even if the history starts later.
    if (!entries.any((e) => e.status == HelpRequestStatus.local)) {
      entries.add(RequestHistoryEntry(status: HelpRequestStatus.local, at: request.createdAt));
    }
    final sentAt = request.sentAt;
    if (sentAt != null && !entries.any((e) => e.status == HelpRequestStatus.sent)) {
      entries.add(RequestHistoryEntry(status: HelpRequestStatus.sent, at: sentAt));
    }
    // In time order; steps saved at the same moment (practice) follow the flow.
    entries.sort((a, b) {
      final byTime = a.at.compareTo(b.at);
      return byTime != 0 ? byTime : _flowIndex(a.status).compareTo(_flowIndex(b.status));
    });
    final status = request.status;
    final open =
        status == HelpRequestStatus.sent ||
        status == HelpRequestStatus.seen ||
        status == HelpRequestStatus.onTheWay;
    final ahead = open ? _flow.skip(_flow.indexOf(status) + 1).toList() : <HelpRequestStatus>[];
    final finished = !open && status != HelpRequestStatus.local;
    final steps = <Widget>[
      for (final (index, entry) in entries.indexed)
        EmergencyTimelineStep(
          label: requestStatusLabel(t, entry.status),
          time: hour(entry.at),
          detail: entry.reason,
          state: index == entries.length - 1 && !finished
              ? TimelineState.current
              : TimelineState.done,
          isLast: index == entries.length - 1 && ahead.isEmpty,
        ),
      for (final (index, next) in ahead.indexed)
        EmergencyTimelineStep(
          label: requestStatusLabel(t, next),
          state: TimelineState.pending,
          isLast: index == ahead.length - 1,
        ),
    ];
    return Semantics(
      label: t.emergencyHistory,
      container: true,
      explicitChildNodes: true,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: steps),
        ),
      ),
    );
  }

  /// Order of the steps: the flow first, then the closings that can follow any of them.
  static int _flowIndex(HelpRequestStatus status) {
    final index = _flow.indexOf(status);
    return index < 0 ? _flow.length : index;
  }
}
