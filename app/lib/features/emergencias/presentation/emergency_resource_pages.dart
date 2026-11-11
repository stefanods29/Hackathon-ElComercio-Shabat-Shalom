import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/core/platform/pilot_platforms.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/submissions/submission_status.dart';
import 'package:vecinal/core/time/time_ago.dart';
import 'package:vecinal/core/ui/image_policy.dart';
import 'package:vecinal/core/ui/large_button.dart';
import 'package:vecinal/core/ui/spaced.dart';
import 'package:vecinal/core/ui/submission_status_chip.dart';
import 'package:vecinal/features/directorio/domain/directory.dart';
import 'package:vecinal/features/directorio/presentation/directory_page.dart';
import 'package:vecinal/features/emergencias/data/emergency_providers.dart';
import 'package:vecinal/features/emergencias/data/providers.dart';
import 'package:vecinal/features/emergencias/domain/emergency.dart';
import 'package:vecinal/features/emergencias/domain/public_emergency_board.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_ui.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_widgets.dart';
import 'package:vecinal/features/emergencias/presentation/help_request_pages.dart';
import 'package:vecinal/features/emergencias/presentation/public_emergency_board_page.dart';
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
    final theme = Theme.of(context);
    final snapshot = ref.watch(emergencySnapshotProvider).value;
    final available = snapshot?.coverageVerified == true;
    return EmergencyLayout(
      title: t.emergencyCanHelp,
      children: [
        Text(t.emergencyOfferHelp, style: theme.textTheme.bodyLarge),
        if (!available)
          EmergencyNotice(icon: Icons.info_outline, text: t.emergencyNoCoverage, liveRegion: true),
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
        if (_error != null)
          EmergencyNotice(
            icon: Icons.error_outline,
            text: _error!,
            tone: NoticeTone.danger,
            liveRegion: true,
          ),
        if (_saved)
          EmergencyNotice(
            icon: Icons.check_circle_outline,
            text: t.emergencyOfferSaved,
            tone: NoticeTone.info,
            liveRegion: true,
          ),
        LargeButton(
          icon: Icons.volunteer_activism_outlined,
          label: widget.scope.practice ? t.emergencySavePractice : t.emergencySend,
          onPressed: _busy || _saved || !available ? null : _save,
        ),
        for (final offer in snapshot?.offers ?? <HelpOffer>[])
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 10,
                children: [
                  Text(offer.description, style: theme.textTheme.bodyLarge),
                  SubmissionStatusChip(status: offer.status),
                  Text(
                    t.emergencyOfferNoAssignment,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
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
        ref.read(emergencySnapshotProvider).value?.coverageVerified != true) {
      return;
    }
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
      if (mounted && ref.read(emergencyScopeProvider)?.key == widget.scope.key) {
        setState(() => _saved = true);
      }
    } catch (_) {
      if (mounted) setState(() => _error = t.emergencySaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// "Recursos cerca" (section 5.5): the resources with filters by kind, and the requests of the zone
/// grouped by sector in a second tab. Reporting opens its own form.
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
  ResourceKind? _filter;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(emergencySnapshotProvider);
    final available = state.value?.coverageVerified == true;
    final online = ref.watch(syncStatusProvider).value?.connected == true;
    // The most recent first: availability changes, so the newest report matters most.
    final resources = [...?state.value?.resources]
      ..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
    final kinds = [
      for (final kind in ResourceKind.values)
        if (resources.any((r) => r.kind == kind)) kind,
    ];
    final filter = kinds.contains(_filter) ? _filter : null;
    final visible = [
      for (final resource in resources)
        if (filter == null || resource.kind == filter) resource,
    ];
    return DefaultTabController(
      length: 2,
      child: EmergencyLayout(
        title: t.emergencyResources,
        bottom: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          // 52 dp: the default tab (46) is below the minimum touch target.
          tabs: [
            Tab(height: 52, text: t.emergencyTabResources),
            Tab(height: 52, text: t.emergencyTabDemands),
          ],
        ),
        floatingActionButton: available
            ? FloatingActionButton.extended(
                icon: const Icon(Icons.add_location_alt_outlined),
                label: Text(t.emergencyReportResource),
                onPressed: () => context.push(Routes.emergencyReportResource),
              )
            : null,
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 112),
              children: spaced([
                if (!available)
                  EmergencyNotice(
                    icon: Icons.info_outline,
                    text: t.emergencyNoCoverage,
                    liveRegion: true,
                  ),
                if (!widget.scope.practice && !online)
                  EmergencyNotice(icon: Icons.cloud_off_outlined, text: t.emergencyOfflineWarning),
                if (kinds.length > 1)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    child: Row(
                      spacing: 8,
                      children: [
                        _FilterChip(
                          label: t.emergencyFilterAll,
                          selected: filter == null,
                          onSelected: () => setState(() => _filter = null),
                        ),
                        for (final kind in kinds)
                          _FilterChip(
                            label: resourceLabel(t, kind),
                            selected: filter == kind,
                            onSelected: () => setState(() => _filter = kind),
                          ),
                      ],
                    ),
                  ),
                state.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => EmergencyNotice(
                    icon: Icons.sync_problem_outlined,
                    text: t.emergencyCoordinationUnavailable,
                  ),
                  data: (_) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [
                      if (visible.isEmpty) Text(t.emergencyResourcesEmpty),
                      for (final resource in visible)
                        CriticalResourceCard(
                          resource: resource,
                          onTap: () => context.push(resourceDetailRoute(resource.id)),
                        ),
                    ],
                  ),
                ),
                Text(
                  t.emergencyResourcesFooter,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.handyman_outlined),
                  label: Text(t.emergencyUsefulServices),
                  onPressed: () {
                    ref.read(imagesEnabledProvider.notifier).set(false);
                    context.go('${Routes.directory}?emergencia=1');
                  },
                ),
                const EmergencyAlternatives(),
              ]),
            ),
            _ZoneDemands(practice: widget.scope.practice),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onSelected});
  final String label;
  final bool selected;
  final VoidCallback onSelected;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? scheme.onSecondary : scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: scheme.secondary,
      onSelected: (_) => onSelected(),
    );
  }
}

/// Where a resource of the list opens.
String resourceDetailRoute(String id) =>
    Routes.emergencyResourceDetail.replaceFirst(':id', Uri.encodeComponent(id));

/// Where the requests of one need in one sector open.
String zoneDemandRoute(CellDemand demand) => Routes.emergencyZoneDemand
    .replaceFirst(':cell', Uri.encodeComponent(demand.cell))
    .replaceFirst(':need', Uri.encodeComponent(demand.need));

/// The zone board: the fictitious one in practice, or the API's; null when the pilot has none.
AsyncValue<PublicEmergencySnapshot>? zoneBoard(WidgetRef ref, {required bool practice}) => practice
    ? AsyncData(practiceBoardSnapshot(ref.watch(clockProvider)()))
    : ref.watch(emergencyBoardRepositoryProvider) == null
    ? null
    : ref.watch(emergencyBoardProvider);

/// Requests of the zone grouped by sector: never a person or a case. Practice shows a fictitious
/// zone, so this tab also works in the demo. Each group opens how to help with it.
class _ZoneDemands extends ConsumerWidget {
  const _ZoneDemands({required this.practice});
  final bool practice;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = ref.watch(emergencyNowProvider).value ?? ref.watch(clockProvider)();
    final board = zoneBoard(ref, practice: practice);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 112),
      children: spaced([
        Text(
          t.emergencyDemandsHelp,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        if (board == null)
          EmergencyNotice(
            icon: Icons.info_outline,
            text: t.emergencyBoardUnavailable,
            tone: NoticeTone.info,
          )
        else
          board.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => EmergencyNotice(
              icon: Icons.sync_problem_outlined,
              text: t.emergencyBoardUnavailable,
            ),
            data: (snapshot) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                if (snapshot.demands.isEmpty) Text(t.emergencyBoardNoDemands),
                for (final demand in snapshot.demands)
                  _DemandCard(
                    demand: demand,
                    now: now,
                    onTap: () => context.push(zoneDemandRoute(demand)),
                  ),
              ],
            ),
          ),
      ]),
    );
  }
}

class _DemandCard extends StatelessWidget {
  const _DemandCard({required this.demand, required this.now, required this.onTap});
  final CellDemand demand;
  final DateTime now;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    return FilledButton(
      onPressed: onTap,
      style: emergencyCardStyle(
        scheme,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.all(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EmergencyIconBadge(icon: demandIcon(demand.need)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Text(
                  t.emergencyBoardDemand(demand.count, t.emergencyBoardCategory(demand.need)),
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(t.emergencySector(demand.cell), style: muted),
                Text(t.updatedAgo(timeAgo(demand.updatedAt, now, t)), style: muted),
              ],
            ),
          ),
          const _OpensDetail(),
        ],
      ),
    );
  }
}

/// The chevron that says a card opens more; the card itself is the button the reader hears.
class _OpensDetail extends StatelessWidget {
  const _OpensDetail();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 8, top: 12),
    child: ExcludeSemantics(
      child: Icon(
        Icons.chevron_right,
        size: 28,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

/// Reporting a resource has its own screen, reached from "Recursos cerca".
class EmergencyReportResourcePage extends StatelessWidget {
  const EmergencyReportResourcePage({super.key, this.initialKind});

  /// Already chosen when the report starts from a request of the zone.
  final ResourceKind? initialKind;
  @override
  Widget build(BuildContext context) => EmergencyScopeGate(
    title: AppLocalizations.of(context).emergencyReportResource,
    builder: (scope) => _ReportResourceForm(scope: scope, initialKind: initialKind),
  );
}

class _ReportResourceForm extends ConsumerStatefulWidget {
  const _ReportResourceForm({required this.scope, this.initialKind});
  final EmergencyScope scope;
  final ResourceKind? initialKind;
  @override
  ConsumerState<_ReportResourceForm> createState() => _ReportResourceFormState();
}

class _ReportResourceFormState extends ConsumerState<_ReportResourceForm> {
  final _form = GlobalKey<FormState>();
  final _text = TextEditingController();
  final _quantity = TextEditingController();
  final _id = newLocalId();
  final _idempotencyKey = newLocalId();
  late ResourceKind _kind = widget.initialKind ?? ResourceKind.water;
  bool _busy = false;
  bool _listening = false;
  CommentDictation? _dictation;
  String? _error;

  bool get _current => mounted && ref.read(emergencyScopeProvider)?.key == widget.scope.key;

  @override
  void dispose() {
    if (_dictation != null) unawaited(_dictation!.stop());
    _text.dispose();
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    final available = ref.watch(emergencySnapshotProvider).value?.coverageVerified == true;
    return EmergencyLayout(
      title: t.emergencyReportResource,
      children: [
        if (!available)
          EmergencyNotice(icon: Icons.info_outline, text: t.emergencyNoCoverage, liveRegion: true),
        Semantics(
          header: true,
          child: Text(t.emergencyReportWhat, style: theme.textTheme.headlineSmall),
        ),
        EmergencyTileGrid(
          children: [
            // Lot B has no "other" type: outside practice every report has a known type.
            for (final kind in ResourceKind.values)
              if (widget.scope.practice || kind != ResourceKind.other)
                _KindOption(
                  kind: kind,
                  selected: _kind == kind,
                  onPressed: _busy ? null : () => setState(() => _kind = kind),
                ),
          ],
        ),
        Form(
          key: _form,
          // Lot B accepts no free text from the reporter: the real report is type and quantity.
          child: widget.scope.practice
              ? TextFormField(
                  controller: _text,
                  enabled: !_busy,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: 300,
                  // The limit still applies; "0/300" is only noise here.
                  buildCounter:
                      (_, {required currentLength, required isFocused, required maxLength}) => null,
                  decoration: InputDecoration(
                    labelText: t.emergencyResourceDescription,
                    hintText: t.emergencyReportDetailHint,
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    suffixIcon: IconButton(
                      tooltip: _listening ? t.emergencyStopDictation : t.emergencyDictation,
                      icon: Icon(_listening ? Icons.stop_circle_outlined : Icons.mic_none),
                      onPressed: _busy ? null : _dictate,
                    ),
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? t.emergencyRequired : null,
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 8,
                  children: [
                    IconButton.filledTonal(
                      tooltip: t.emergencyQuantityLess,
                      icon: const Icon(Icons.remove),
                      onPressed: _busy ? null : () => _step(-1),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: _quantity,
                        enabled: !_busy,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge,
                        decoration: InputDecoration(labelText: t.emergencyResourceQuantity),
                        validator: (value) {
                          final quantity = int.tryParse(value?.trim() ?? '');
                          return quantity == null || quantity < 0 || quantity > 1000000
                              ? t.emergencyResourceQuantityInvalid
                              : null;
                        },
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: t.emergencyQuantityMore,
                      icon: const Icon(Icons.add),
                      onPressed: _busy ? null : () => _step(1),
                    ),
                  ],
                ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(Icons.place_outlined, size: 20, color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(t.emergencyReportLocation, style: muted)),
          ],
        ),
        EmergencyNotice(
          icon: Icons.verified_user_outlined,
          text: '${t.emergencyUnverifiedReport} ${t.emergencyReportPrivacy}',
          tone: NoticeTone.info,
        ),
        if (_error != null)
          EmergencyNotice(
            icon: Icons.error_outline,
            text: _error!,
            tone: NoticeTone.danger,
            liveRegion: true,
          ),
        LargeButton(
          icon: Icons.add_location_alt_outlined,
          label: widget.scope.practice ? t.emergencySavePractice : t.emergencyReportResource,
          onPressed: _busy || !available ? null : _save,
        ),
      ],
    );
  }

  /// The stepper of the real report: no keyboard needed for a rough count.
  void _step(int delta) {
    final current = int.tryParse(_quantity.text.trim()) ?? 0;
    final next = (current + delta).clamp(0, 1000000);
    setState(() => _quantity.text = '$next');
  }

  Future<void> _dictate() async {
    final t = AppLocalizations.of(context);
    if (!_current) return;
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
          if (_current) _text.text = words.length > 300 ? words.substring(0, 300) : words;
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
    if (_busy ||
        !_form.currentState!.validate() ||
        ref.read(emergencyScopeProvider)?.key != widget.scope.key ||
        ref.read(emergencySnapshotProvider).value?.coverageVerified != true) {
      return;
    }
    final t = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_listening) {
      await _dictation?.stop();
      if (mounted) setState(() => _listening = false);
    }
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
              quantity: int.tryParse(_quantity.text.trim()),
              location: ref.read<GeoPoint>(directoryOriginProvider).approximate(),
            ),
          );
      if (mounted && ref.read(emergencyScopeProvider)?.key == widget.scope.key) {
        context.pop();
        messenger.showSnackBar(SnackBar(content: Text(t.emergencyResourceSaved)));
      }
    } catch (_) {
      if (mounted) setState(() => _error = t.emergencySaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// One kind of resource to pick: a big icon and its name; the chosen one is outlined in teal and
/// carries a check, like a radio button for the screen reader.
class _KindOption extends StatelessWidget {
  const _KindOption({required this.kind, required this.selected, required this.onPressed});
  final ResourceKind kind;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final style = resourceStyle(scheme, kind);
    final base = emergencyCardStyle(
      scheme,
      minimumSize: const Size(48, 112),
      padding: const EdgeInsets.all(14),
      alignment: Alignment.center,
      enabled: onPressed != null,
    );
    return FilledButton(
      onPressed: onPressed,
      style: selected
          ? base.copyWith(
              backgroundColor: WidgetStatePropertyAll(scheme.primaryContainer),
              foregroundColor: WidgetStatePropertyAll(scheme.onPrimaryContainer),
              side: WidgetStatePropertyAll(BorderSide(color: scheme.primary, width: 2.5)),
            )
          : base,
      child: Semantics(
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                EmergencyIconBadge(
                  icon: style.icon,
                  // On the chosen tile the badge turns white so it still stands out.
                  background: selected ? scheme.surface : style.background,
                  foreground: style.foreground,
                  size: 54,
                ),
                if (selected)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: ExcludeSemantics(
                      child: Icon(Icons.check_circle, color: scheme.primary, size: 24),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              resourceLabel(t, kind),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Sin verificar", "Confirmado por 2 vecinos" or "Verificado": the pill, and the share text.
String verificationLabel(AppLocalizations t, CriticalResource resource) =>
    switch (resource.verification) {
      ResourceVerification.unverified => t.emergencyUnverified,
      ResourceVerification.neighbors => t.emergencyConfirmedNeighbors(resource.confirmations),
      ResourceVerification.verified => t.emergencyVerified,
    };

/// A resource at a glance (section 5.5): an icon by kind, its place, and the age and the
/// verification as pills. The source shows only when a person verified it. With [onTap] the
/// whole card is a button that opens the detail.
class CriticalResourceCard extends StatelessWidget {
  const CriticalResourceCard({super.key, required this.resource, this.onTap});
  final CriticalResource resource;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final source = resource.verification == ResourceVerification.verified ? resource.source : null;
    final style = resourceStyle(scheme, resource.kind);
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmergencyIconBadge(
          icon: style.icon,
          background: style.background,
          foreground: style.foreground,
          size: 52,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Text(
                resourceLabel(t, resource.kind),
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (resource.description.isNotEmpty)
                Text(
                  resource.description,
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ResourcePills(resource: resource),
              if (source != null)
                Text(
                  t.sourceAndDate(
                    source.name,
                    DateFormat.yMd(t.localeName).format(source.verifiedAt),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
        if (onTap != null) const _OpensDetail(),
      ],
    );
    if (onTap == null) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(padding: const EdgeInsets.all(18), child: content),
      );
    }
    return FilledButton(
      onPressed: onTap,
      style: emergencyCardStyle(
        scheme,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.all(18),
      ),
      child: content,
    );
  }
}

/// The age (amber once old) and the verification of a resource, and the source when official.
class ResourcePills extends ConsumerWidget {
  const ResourcePills({super.key, required this.resource});
  final CriticalResource resource;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final light = scheme.brightness == Brightness.light;
    final now = ref.watch(emergencyNowProvider).value ?? ref.watch(clockProvider)();
    final stale = ref.watch(resourceFreshnessPolicyProvider).isStale(resource, now);
    final source = resource.verification == ResourceVerification.verified ? resource.source : null;
    final ago = timeAgo(resource.reportedAt, now, t);
    final fresh = pillColors(scheme, NoticeTone.info);
    final warning = pillColors(scheme, NoticeTone.warning);
    final neutral = pillColors(scheme, null);
    final verified = light
        ? (background: scheme.secondary, foreground: scheme.onSecondary)
        : (background: scheme.surfaceContainerHigh, foreground: scheme.onSurface);
    final checked = resource.verification == ResourceVerification.verified ? verified : neutral;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // "Hace 20 minutos" in green; once old, "Hace 3 horas · confirma antes de
        // ir" in amber. The screen reader hears the full warning.
        Semantics(
          label: stale
              ? '${t.emergencyReportedAgo(ago)}. ${t.emergencyResourceStale}'
              : t.emergencyReportedAgo(ago),
          excludeSemantics: true,
          child: EmergencyPill(
            icon: stale ? Icons.warning_amber_rounded : Icons.schedule,
            text: stale
                ? '${sentenceCase(ago)} · ${t.emergencyConfirmBeforeGoing}'
                : sentenceCase(ago),
            background: stale ? warning.background : fresh.background,
            foreground: stale ? warning.foreground : fresh.foreground,
          ),
        ),
        EmergencyPill(
          icon: switch (resource.verification) {
            ResourceVerification.unverified => Icons.help_outline,
            ResourceVerification.neighbors => Icons.groups_outlined,
            ResourceVerification.verified => Icons.verified_outlined,
          },
          text: verificationLabel(t, resource),
          background: checked.background,
          foreground: checked.foreground,
        ),
        if (source?.official == true)
          EmergencyPill(
            icon: Icons.account_balance_outlined,
            text: t.emergencyOfficialSource,
            background: verified.background,
            foreground: verified.foreground,
          ),
        // Only what is not normal: the neighbor's own report still on the phone.
        if (resource.status != SubmissionStatus.sent) SubmissionStatusChip(status: resource.status),
      ],
    );
  }
}
