import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/platform/pilot_platforms.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/ui/submission_status_chip.dart';
import 'package:vecinal/features/directorio/data/providers.dart';
import 'package:vecinal/features/directorio/domain/directory.dart';
import 'package:vecinal/features/directorio/presentation/directory_page.dart';
import 'package:vecinal/features/mapa/presentation/map_view.dart';
import 'package:vecinal/features/onboarding/demo_profiles.dart';
import 'package:vecinal/features/reputacion/domain/reputation.dart';
import 'package:vecinal/features/reputacion/presentation/report_button.dart';
import 'package:vecinal/features/reputacion/presentation/reviews_section.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// C3 may inject the public profile link once its canonical host is deployed.
final profileShareLinkProvider = Provider<Uri? Function(String)>(
  (ref) =>
      (_) => null,
);

class ServiceDetailPage extends ConsumerWidget {
  const ServiceDetailPage({super.key, required this.serviceId});
  final String serviceId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.viewService)),
      body: SafeArea(
        child: ref
            .watch(serviceProvider(serviceId))
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(child: Text(t.serviceUnavailable)),
              data: (service) => service == null
                  ? Center(child: Text(t.serviceUnavailable))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Text(service.title, style: Theme.of(context).textTheme.headlineSmall),
                        if (service.description != null) Text(service.description!),
                        SubmissionStatusChip(status: service.submissionStatus),
                        Text(
                          t.serviceRating(
                            service.averageRating.toStringAsFixed(1),
                            service.reviewCount,
                          ),
                        ),
                        Text(t.zoneEndorsements(service.zoneEndorsements)),
                        Text(t.publicApproximateLocation),
                        OutlinedButton.icon(
                          onPressed: () => context.push(
                            Routes.map,
                            extra: MapFocus([
                              MapMarker(
                                label: service.title,
                                location: service.location.approximate(),
                              ),
                            ]),
                          ),
                          icon: const Icon(Icons.map_outlined),
                          label: Text(t.openOnMap),
                        ),
                        FilledButton(
                          onPressed: () => context.push('/proveedores/${service.providerId}'),
                          child: Text(t.viewProvider),
                        ),
                        ReportButton(content: ReportedContent.service, contentId: service.id),
                        ReviewsSection(
                          serviceId: service.id,
                          isOwnService:
                              service.providerId == ref.watch(effectiveSessionProvider).neighborId,
                        ),
                        if (service.providerId ==
                            ref.watch(effectiveSessionProvider).neighborId) ...[
                          OutlinedButton(
                            onPressed: () => context.push('/servicios/${service.id}/editar'),
                            child: Text(t.editService),
                          ),
                          TextButton(
                            onPressed: () => _withdraw(context, ref, service),
                            child: Text(t.withdrawService),
                          ),
                        ],
                      ],
                    ),
            ),
      ),
    );
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref, Service service) async {
    final t = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.withdrawService),
        content: Text(t.withdrawServiceBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t.confirm)),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await ref.read(serviceDirectoryRepositoryProvider).withdrawService(service.id);
      if (context.mounted) {
        context.go(Routes.directory);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.statusSavedOnPhone)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.actionFailed)));
      }
    }
  }
}

class ProviderProfilePage extends ConsumerWidget {
  const ProviderProfilePage({super.key, required this.providerId});
  final String providerId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final items = ref.watch(providerServicesProvider(providerId)).value ?? const <Service>[];
    final profile = ref.watch(providerProfileProvider(providerId));
    return Scaffold(
      appBar: AppBar(title: Text(t.providerTitle)),
      body: SafeArea(
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(child: Text(t.providerUnavailable)),
          data: (provider) => provider == null
              ? Center(child: Text(t.providerUnavailable))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(provider.publicName, style: Theme.of(context).textTheme.headlineSmall),
                    if (provider.description != null) Text(provider.description!),
                    SubmissionStatusChip(status: provider.submissionStatus),
                    Text(
                      t.serviceRating(
                        _rating(items).toStringAsFixed(1),
                        items.fold(0, (n, s) => n + s.reviewCount),
                      ),
                    ),
                    Text(t.zoneEndorsements(items.fold(0, (n, s) => n + s.zoneEndorsements))),
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          await ref
                              .read(appShareProvider)
                              .text(
                                [
                                  provider.publicName,
                                  ...items.map((s) => s.title),
                                  if (ref.read(profileShareLinkProvider)(provider.id)
                                      case final link?)
                                    link.toString(),
                                ].join('\n'),
                                shareOrigin(context),
                              );
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(t.actionFailed)));
                          }
                        }
                      },
                      icon: const Icon(Icons.share_outlined),
                      label: Text(t.shareAction),
                    ),
                    for (final service in items) ServiceTile(service: service),
                  ],
                ),
        ),
      ),
    );
  }

  double _rating(List<Service> items) {
    final count = items.fold(0, (n, s) => n + s.reviewCount);
    return count == 0 ? 0 : items.fold(0.0, (n, s) => n + s.averageRating * s.reviewCount) / count;
  }
}
