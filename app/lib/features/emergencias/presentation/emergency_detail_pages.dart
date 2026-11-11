import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/platform/pilot_platforms.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/time/time_ago.dart';
import 'package:vecinal/core/ui/large_button.dart';
import 'package:vecinal/features/emergencias/data/emergency_providers.dart';
import 'package:vecinal/features/emergencias/domain/emergency.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_resource_pages.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_ui.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_widgets.dart';
import 'package:vecinal/features/emergencias/presentation/help_request_pages.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// A resource of "Recursos cerca", opened: what and where, how fresh the report is, who confirms
/// it and what to keep in mind before going. It follows the live list, so a resource that leaves
/// it says so instead of showing old data.
class EmergencyResourceDetailPage extends StatelessWidget {
  const EmergencyResourceDetailPage({super.key, required this.resourceId});
  final String resourceId;
  @override
  Widget build(BuildContext context) => EmergencyScopeGate(
    title: AppLocalizations.of(context).emergencyResources,
    builder: (scope) => _ResourceDetail(resourceId: resourceId, practice: scope.practice),
  );
}

class _ResourceDetail extends ConsumerWidget {
  const _ResourceDetail({required this.resourceId, required this.practice});
  final String resourceId;
  final bool practice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final state = ref.watch(emergencySnapshotProvider);
    final resource = state.value?.resources.where((r) => r.id == resourceId).firstOrNull;
    if (resource == null) {
      return EmergencyLayout(
        title: t.emergencyResources,
        children: [
          if (state.isLoading)
            const LinearProgressIndicator()
          else
            EmergencyNotice(
              icon: Icons.info_outline,
              text: t.emergencyResourceGone,
              tone: NoticeTone.info,
              liveRegion: true,
            ),
        ],
      );
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    final now = ref.watch(emergencyNowProvider).value ?? ref.watch(clockProvider)();
    final policy = ref.watch(resourceFreshnessPolicyProvider);
    final stale = policy.isStale(resource, now);
    final freshFor = _duration(t, policy.freshFor(resource));
    final kind = resourceLabel(t, resource.kind);
    final style = resourceStyle(scheme, resource.kind);
    final ago = timeAgo(resource.reportedAt, now, t);
    final reportedAt = DateFormat.MMMd(t.localeName).add_Hm().format(resource.reportedAt.toLocal());
    final source = resource.verification == ResourceVerification.verified ? resource.source : null;
    final url = source?.url;
    return EmergencyLayout(
      title: kind,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EmergencyIconBadge(
              icon: style.icon,
              background: style.background,
              foreground: style.foreground,
              size: 64,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 10,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      resource.description.isEmpty ? kind : resource.description,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  ResourcePills(resource: resource),
                ],
              ),
            ),
          ],
        ),
        if (stale)
          EmergencyNotice(icon: Icons.warning_amber_rounded, text: t.emergencyStaleFor(freshFor)),
        _DetailSection(
          icon: Icons.schedule,
          title: t.emergencyWhenReported,
          children: [
            Text('${sentenceCase(ago)} · $reportedAt'),
            if (!stale) Text(t.emergencyFreshFor(freshFor), style: muted),
          ],
        ),
        _DetailSection(
          icon: switch (resource.verification) {
            ResourceVerification.unverified => Icons.help_outline,
            ResourceVerification.neighbors => Icons.groups_outlined,
            ResourceVerification.verified => Icons.verified_outlined,
          },
          title: t.emergencyWhoConfirms,
          children: [
            Text(switch (resource.verification) {
              ResourceVerification.unverified => t.emergencyDetailUnverified,
              ResourceVerification.neighbors => t.emergencyDetailNeighbors(resource.confirmations),
              ResourceVerification.verified =>
                source == null
                    ? t.emergencyVerified
                    : t.emergencyDetailVerified(
                        source.name,
                        DateFormat.yMd(t.localeName).format(source.verifiedAt),
                      ),
            }),
            if (url != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  icon: const Icon(Icons.open_in_new),
                  label: Text(t.emergencyOpenSource),
                  onPressed: () => launchUrl(url, mode: LaunchMode.externalApplication),
                ),
              ),
          ],
        ),
        _DetailSection(
          icon: Icons.checklist_outlined,
          title: t.emergencyBeforeGoing,
          children: [
            _Tip(text: _tip(t, resource.kind)),
            _Tip(text: t.emergencyTipSafety),
          ],
        ),
        Builder(
          builder: (button) => LargeButton(
            icon: Icons.share_outlined,
            label: t.emergencyShareResource,
            onPressed: () => _share(button, ref, resource, ago),
          ),
        ),
        const EmergencyAlternatives(),
      ],
    );
  }

  /// A short text for the family: what, where, how old and who confirms it. In practice it says
  /// that the data is fictitious, so nobody goes to a place that does not exist.
  Future<void> _share(
    BuildContext context,
    WidgetRef ref,
    CriticalResource resource,
    String ago,
  ) async {
    final t = AppLocalizations.of(context);
    final kind = resourceLabel(t, resource.kind);
    final what = resource.description.isEmpty
        ? kind
        : t.emergencyShareKindAt(kind, resource.description);
    final text = t.emergencyShareText(
      what,
      t.emergencyReportedAgo(ago),
      verificationLabel(t, resource),
    );
    await ref
        .read(appShareProvider)
        .text(practice ? t.emergencySharePractice(text) : text, shareOrigin(context));
  }
}

/// The requests of one need in one sector, opened: how many, how recent and how to help, with
/// the resources that answer them. Never who asked: the board only has counts by sector.
class EmergencyZoneDemandPage extends StatelessWidget {
  const EmergencyZoneDemandPage({super.key, required this.cell, required this.need});
  final String cell;
  final String need;
  @override
  Widget build(BuildContext context) => EmergencyScopeGate(
    title: AppLocalizations.of(context).emergencySector(cell),
    builder: (scope) => _ZoneDemandDetail(cell: cell, need: need, practice: scope.practice),
  );
}

class _ZoneDemandDetail extends ConsumerWidget {
  const _ZoneDemandDetail({required this.cell, required this.need, required this.practice});
  final String cell;
  final String need;
  final bool practice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final now = ref.watch(emergencyNowProvider).value ?? ref.watch(clockProvider)();
    final board = zoneBoard(ref, practice: practice);
    final demand = board?.value?.demands
        .where((demand) => demand.cell == cell && demand.need == need)
        .firstOrNull;
    final kind = resourceKindForDemand(need);
    final resources = ref.watch(emergencySnapshotProvider).value?.resources;
    final nearby = [
      for (final resource in resources ?? const <CriticalResource>[])
        if (resource.kind == kind) resource,
    ]..sort((a, b) => b.reportedAt.compareTo(a.reportedAt));
    final reportRoute = Uri(
      path: Routes.emergencyReportResource,
      queryParameters: {if (kind != null) 'tipo': kind.name},
    ).toString();
    return EmergencyLayout(
      title: t.emergencySector(cell),
      children: [
        if (demand != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EmergencyIconBadge(icon: demandIcon(need), size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        t.emergencyBoardDemand(demand.count, t.emergencyBoardCategory(need)),
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(t.updatedAgo(timeAgo(demand.updatedAt, now, t)), style: muted),
                  ],
                ),
              ),
            ],
          )
        else if (board?.isLoading == true)
          const LinearProgressIndicator()
        else
          EmergencyNotice(
            icon: Icons.info_outline,
            text: t.emergencyDemandGone,
            tone: NoticeTone.info,
            liveRegion: true,
          ),
        EmergencyNotice(
          icon: Icons.lock_outline,
          text: t.emergencyDemandPrivacy,
          tone: NoticeTone.info,
        ),
        _DetailSection(
          icon: Icons.volunteer_activism_outlined,
          title: t.emergencyHowToHelp,
          children: [Text(t.emergencyHowToHelpText)],
        ),
        LargeButton(
          icon: Icons.volunteer_activism_outlined,
          label: t.emergencyCanHelp,
          onPressed: () => context.push(Routes.emergencyOffer),
        ),
        OutlinedButton.icon(
          icon: const Icon(Icons.add_location_alt_outlined),
          label: Text(t.emergencyReportResource),
          onPressed: () => context.push(reportRoute),
        ),
        Semantics(
          header: true,
          child: Text(
            t.emergencyNearbyForThis,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (nearby.isEmpty)
          Text(t.emergencyNoNearbyForThis, style: muted)
        else
          for (final resource in nearby)
            CriticalResourceCard(
              resource: resource,
              onTap: () => context.push(resourceDetailRoute(resource.id)),
            ),
      ],
    );
  }
}

/// A titled block of a detail: an icon, the title read as a heading, and its lines.
class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.icon, required this.title, required this.children});
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EmergencyIconBadge(icon: icon, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  ...children,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One piece of advice, with a check mark the screen reader skips.
class _Tip extends StatelessWidget {
  const _Tip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: ExcludeSemantics(
          child: Icon(
            Icons.check_circle_outline,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(text)),
    ],
  );
}

String _tip(AppLocalizations t, ResourceKind kind) => switch (kind) {
  ResourceKind.water => t.emergencyTipWater,
  ResourceKind.food => t.emergencyTipFood,
  ResourceKind.medicine => t.emergencyTipMedicine,
  ResourceKind.shelter => t.emergencyTipShelter,
  ResourceKind.meetingPoint => t.emergencyTipMeetingPoint,
  ResourceKind.other => t.emergencyTipOther,
};

/// "2 horas", "30 días": how long a kind of report counts as current.
String _duration(AppLocalizations t, Duration duration) {
  if (duration.inMinutes < 60) return t.emergencyMinutes(duration.inMinutes);
  if (duration.inHours < 48) return t.emergencyHours(duration.inHours);
  return t.emergencyDays(duration.inDays);
}
