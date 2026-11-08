import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/core/time/time_ago.dart';
import 'package:vecinal/core/ui/large_button.dart';
import 'package:vecinal/core/ui/submission_status_chip.dart';
import 'package:vecinal/features/emergencias/data/emergency_providers.dart';
import 'package:vecinal/features/emergencias/domain/emergency.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_widgets.dart';
import 'package:vecinal/features/emergencias/presentation/help_request_pages.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class EmergencyOfferPage extends StatelessWidget {
  const EmergencyOfferPage({super.key});
  @override
  Widget build(BuildContext context) => EmergencyScopeGate(
    title: AppLocalizations.of(context).emergencyCanHelp,
    builder: (scope) => _OfferForm(scope: scope),
  );
}

class _OfferForm extends ConsumerStatefulWidget {
  const _OfferForm({required this.scope});
  final EmergencyScope scope;
  @override
  ConsumerState<_OfferForm> createState() => _OfferFormState();
}

class _OfferFormState extends ConsumerState<_OfferForm> {
  final _form = GlobalKey<FormState>();
  final _text = TextEditingController();
  final _id = newLocalId();
  final _idempotencyKey = newLocalId();
  bool _busy = false;
  bool _saved = false;
  String? _error;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final snapshot = ref.watch(emergencySnapshotProvider).value;
    final available = snapshot?.coverageVerified == true;
    return EmergencyLayout(
      title: t.emergencyCanHelp,
      children: [
        Text(t.emergencyOfferHelp),
        if (widget.scope.practice) Text(t.emergencyPracticeHelp),
        if (!available) Text(t.emergencyNoCoverage),
        Form(
          key: _form,
          child: TextFormField(
            controller: _text,
            enabled: !_busy && !_saved,
            minLines: 2,
            maxLines: 5,
            maxLength: 300,
            decoration: InputDecoration(labelText: t.emergencyOfferDescription),
            validator: (value) =>
                value == null || value.trim().isEmpty ? t.emergencyRequired : null,
          ),
        ),
        if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
        if (_saved) Text(t.emergencyOfferSaved),
        LargeButton(
          icon: Icons.volunteer_activism_outlined,
          label: widget.scope.practice ? t.emergencySavePractice : t.emergencySend,
          onPressed: _busy || _saved || !available ? null : _save,
        ),
        for (final offer in snapshot?.offers ?? <HelpOffer>[])
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(offer.description),
                  SubmissionStatusChip(status: offer.status),
                  Text(t.emergencyOfferNoAssignment),
                ],
              ),
            ),
          ),
        const EmergencyAlternatives(),
      ],
    );
  }

  Future<void> _save() async {
    if (_busy ||
        _saved ||
        !_form.currentState!.validate() ||
        ref.read(emergencyScopeProvider)?.key != widget.scope.key ||
        ref.read(emergencySnapshotProvider).value?.coverageVerified != true)
      return;
    final t = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(emergencyRepositoryProvider)
          .saveOffer(
            HelpOffer(
              id: _id,
              idempotencyKey: _idempotencyKey,
              description: _text.text.trim(),
              createdAt: ref.read(clockProvider)(),
            ),
          );
      if (mounted && ref.read(emergencyScopeProvider)?.key == widget.scope.key)
        setState(() => _saved = true);
    } catch (_) {
      if (mounted) setState(() => _error = t.emergencySaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class EmergencyResourcesPage extends StatelessWidget {
  const EmergencyResourcesPage({super.key});
  @override
  Widget build(BuildContext context) => EmergencyScopeGate(
    title: AppLocalizations.of(context).emergencyResources,
    builder: (scope) => _Resources(scope: scope),
  );
}

class _Resources extends ConsumerStatefulWidget {
  const _Resources({required this.scope});
  final EmergencyScope scope;
  @override
  ConsumerState<_Resources> createState() => _ResourcesState();
}

class _ResourcesState extends ConsumerState<_Resources> {
  final _form = GlobalKey<FormState>();
  final _text = TextEditingController();
  final _id = newLocalId();
  final _idempotencyKey = newLocalId();
  ResourceKind _kind = ResourceKind.water;
  bool _busy = false;
  bool _saved = false;
  String? _error;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final state = ref.watch(emergencySnapshotProvider);
    final available = state.value?.coverageVerified == true;
    return EmergencyLayout(
      title: t.emergencyResources,
      children: [
        if (widget.scope.practice) Text(t.emergencyPracticeHelp),
        if (!available) Text(t.emergencyNoCoverage),
        Text(t.emergencyResourceHelp),
        Text(t.emergencyFreshnessIllustrative),
        if (!widget.scope.practice && ref.watch(syncStatusProvider).value?.connected != true)
          Text(t.emergencyOfflineWarning),
        state.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => Text(t.emergencyCoordinationUnavailable),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (data.resources.isEmpty) Text(t.emergencyResourcesEmpty),
              for (final resource in data.resources) CriticalResourceCard(resource: resource),
            ],
          ),
        ),
        const Divider(),
        Semantics(
          header: true,
          child: Text(t.emergencyReportResource, style: Theme.of(context).textTheme.titleLarge),
        ),
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButtonFormField<ResourceKind>(
                initialValue: _kind,
                isExpanded: true,
                itemHeight: null,
                decoration: InputDecoration(labelText: t.emergencyResourceType),
                items: [
                  for (final kind in ResourceKind.values)
                    DropdownMenuItem(value: kind, child: Text(resourceLabel(t, kind))),
                ],
                onChanged: _busy || _saved
                    ? null
                    : (value) {
                        if (value != null) setState(() => _kind = value);
                      },
              ),
              TextFormField(
                controller: _text,
                enabled: !_busy && !_saved,
                minLines: 2,
                maxLines: 5,
                maxLength: 300,
                decoration: InputDecoration(labelText: t.emergencyResourceDescription),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? t.emergencyRequired : null,
              ),
            ],
          ),
        ),
        Text(t.emergencyUnverifiedReport),
        if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
        if (_saved) Text(t.emergencyResourceSaved),
        LargeButton(
          icon: Icons.add_location_alt_outlined,
          label: widget.scope.practice ? t.emergencySavePractice : t.emergencyReportResource,
          onPressed: _busy || _saved || !available ? null : _save,
        ),
        const EmergencyAlternatives(),
      ],
    );
  }

  Future<void> _save() async {
    if (_busy ||
        _saved ||
        !_form.currentState!.validate() ||
        ref.read(emergencyScopeProvider)?.key != widget.scope.key ||
        ref.read(emergencySnapshotProvider).value?.coverageVerified != true)
      return;
    final t = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(emergencyRepositoryProvider)
          .reportResource(
            ResourceReportDraft(
              id: _id,
              idempotencyKey: _idempotencyKey,
              kind: _kind,
              description: _text.text.trim(),
            ),
          );
      if (mounted && ref.read(emergencyScopeProvider)?.key == widget.scope.key)
        setState(() => _saved = true);
    } catch (_) {
      if (mounted) setState(() => _error = t.emergencySaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class CriticalResourceCard extends ConsumerWidget {
  const CriticalResourceCard({super.key, required this.resource});
  final CriticalResource resource;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final now = ref.watch(emergencyNowProvider).value ?? ref.watch(clockProvider)();
    final stale = ref.watch(resourceFreshnessPolicyProvider).isStale(resource, now);
    final source = resource.source;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(resourceLabel(t, resource.kind), style: Theme.of(context).textTheme.titleLarge),
            Text(resource.description),
            Text(t.emergencyReportedAgo(timeAgo(resource.reportedAt, now, t))),
            if (stale) Text(t.emergencyResourceStale),
            Text(switch (resource.verification) {
              ResourceVerification.unverified => t.emergencyUnverified,
              ResourceVerification.neighbors => t.emergencyConfirmedNeighbors(
                resource.confirmations,
              ),
              ResourceVerification.verified => t.emergencyVerified,
            }),
            if (source?.official == true)
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [const Icon(Icons.verified_outlined), Text(t.emergencyOfficialSource)],
              ),
            if (source != null)
              Text(
                t.sourceAndDate(
                  '${source.name}${source.url == null ? "" : " · ${source.url}"}',
                  DateFormat.yMd(t.localeName).format(source.verifiedAt),
                ),
              ),
            SubmissionStatusChip(status: resource.status),
          ],
        ),
      ),
    );
  }
}
