import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/core/platform/pilot_platforms.dart';
import 'package:vecinal/core/ui/large_button.dart';
import 'package:vecinal/features/directorio/presentation/directory_page.dart';
import 'package:vecinal/features/emergencias/data/emergency_providers.dart';
import 'package:vecinal/features/emergencias/domain/emergency.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_widgets.dart';
import 'package:vecinal/l10n/app_localizations.dart';

final emergencyNowProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  final now = ref.watch(clockProvider);
  yield now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => now());
});

class EmergencyNeedsPage extends ConsumerWidget {
  const EmergencyNeedsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return EmergencyScopeGate(
      title: t.emergencyNeedHelp,
      builder: (scope) {
        final available = ref.watch(emergencySnapshotProvider).value?.coverageVerified == true;
        return EmergencyLayout(
          title: t.emergencyNeedHelp,
          children: [
            Text(t.emergencyChooseNeed),
            if (!available) Text(t.emergencyNoCoverage),
            for (final need in EmergencyNeed.values)
              LargeButton(
                icon: _needIcon(need),
                label: needLabel(t, need),
                onPressed: available ? () => context.push('/emergencia/nuevo/${need.name}') : null,
              ),
            const EmergencyAlternatives(),
          ],
        );
      },
    );
  }

  IconData _needIcon(EmergencyNeed need) => switch (need) {
    EmergencyNeed.water => Icons.water_drop_outlined,
    EmergencyNeed.food => Icons.restaurant_outlined,
    EmergencyNeed.medicine => Icons.medication_outlined,
    EmergencyNeed.transport => Icons.directions_bus_outlined,
    EmergencyNeed.shelter => Icons.home_outlined,
    EmergencyNeed.other => Icons.help_outline,
  };
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
    _location.text = t.emergencySuggestedLocation;
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
    return EmergencyLayout(
      title: needLabel(t, widget.need),
      children: [
        if (widget.scope.practice) Text(t.emergencyPracticeHelp),
        if (!available) Text(t.emergencyNoCoverage),
        Text(t.emergencyMinimalForm),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _description,
                enabled: !_busy,
                maxLength: 500,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(labelText: t.emergencyDescription),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? t.emergencyRequired : null,
              ),
              OutlinedButton.icon(
                icon: Icon(_listening ? Icons.stop : Icons.mic_outlined),
                label: Text(_listening ? t.emergencyStopDictation : t.emergencyDictation),
                onPressed: _busy ? null : _dictate,
              ),
              Text(t.emergencyDictationHelp),
              TextFormField(
                controller: _location,
                enabled: !_busy,
                maxLength: 120,
                decoration: InputDecoration(labelText: t.emergencyApproximateLocation),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? t.emergencyRequired : null,
              ),
              Text(t.emergencyLocationHelp),
              if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
              LargeButton(
                icon: Icons.send_outlined,
                label: widget.scope.practice ? t.emergencySavePractice : t.emergencySend,
                onPressed: _busy || !available ? null : _save,
              ),
            ],
          ),
        ),
        const EmergencyAlternatives(),
      ],
    );
  }

  Future<void> _dictate() async {
    final t = AppLocalizations.of(context);
    if (!_current) return;
    if (widget.scope.practice) {
      emergencyMessage(context, t.emergencyPracticeExternal);
      return;
    }
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
          locationLabel: _location.text.trim(),
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
            Text(t.emergencyRequestUnavailable),
          const EmergencyAlternatives(),
        ],
      );
    }
    String date(DateTime value) => DateFormat.yMd(t.localeName).add_Hm().format(value.toLocal());
    return EmergencyLayout(
      title: t.emergencyMyRequest,
      children: [
        if (widget.scope.practice) Text(t.emergencyPracticeHelp),
        Semantics(
          liveRegion: true,
          child: Text(
            requestStatusLabel(t, request.status),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        Text(switch (request.status) {
          HelpRequestStatus.local => t.emergencyRequestLocalHelp,
          HelpRequestStatus.sent => t.emergencyRequestSentHelp,
          HelpRequestStatus.seen => t.emergencyRequestSeenHelp,
          HelpRequestStatus.onTheWay => t.emergencyRequestOnTheWayHelp,
          HelpRequestStatus.attended => t.emergencyRequestAttendedHelp,
          HelpRequestStatus.referred ||
          HelpRequestStatus.closedUnattended => t.emergencyRequestClosedHelp,
        }),
        Text(t.emergencyLastChange(date(request.updatedAt))),
        if (request.sentAt != null) Text(t.emergencySentAt(date(request.sentAt!))),
        if (request.status == HelpRequestStatus.sent && request.sentAt != null)
          Text(
            t.emergencyUnreviewedMinutes(
              now.difference(request.sentAt!).inMinutes.clamp(0, 999999).toInt(),
            ),
          ),
        if (widget.scope.practice != true && ref.watch(syncStatusProvider).value?.connected != true)
          Text(t.emergencyOfflineWarning),
        Text(needLabel(t, request.need), style: Theme.of(context).textTheme.titleLarge),
        Text(request.description),
        Text('${t.emergencyApproximateLocation}: ${request.locationLabel}'),
        if (request.reason != null) Text(t.emergencyReason(request.reason!)),
        if (request.nextStep != null) Text(t.emergencyNextStep(request.nextStep!)),
        if (request.canConfirmAttendance)
          LargeButton(
            icon: Icons.check_circle_outline,
            label: t.emergencyConfirmAttendance,
            onPressed: _busy ? null : () => _confirm(request),
          ),
        Semantics(
          header: true,
          child: Text(t.emergencyHistory, style: Theme.of(context).textTheme.titleLarge),
        ),
        for (final entry in request.history)
          Text(
            '${requestStatusLabel(t, entry.status)} · ${date(entry.at)}${entry.role == null ? "" : " · ${entry.role}"}${entry.reason == null ? "" : "\n${entry.reason}"}',
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
