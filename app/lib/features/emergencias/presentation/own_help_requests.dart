import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:vecinal/features/emergencias/data/own_help_request_repository.dart';
import 'package:vecinal/features/emergencias/data/providers.dart';
import 'package:vecinal/features/emergencias/domain/own_help_request_state.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';
import 'package:vecinal/l10n/app_localizations.dart';

final _requestIds = StreamProvider.autoDispose.family<List<String>, OwnHelpRequestRepository>(
  (ref, repository) => repository.watchIds(),
);
final _request = StreamProvider.autoDispose
    .family<OwnHelpRequestState?, (OwnHelpRequestRepository, String)>(
      (ref, key) => key.$1.watch(key.$2),
    );

/// Shows only the real account's known requests, next to the offline emergency directory.
class OwnHelpRequests extends ConsumerWidget {
  const OwnHelpRequests({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(practiceModeProvider).value != false) return const SizedBox.shrink();
    final repository = ref.watch(ownHelpRequestRepositoryProvider);
    if (repository == null) return const SizedBox.shrink();
    final ids = ref.watch(_requestIds(repository)).value ?? const [];
    return Column(
      children: [
        for (final id in ids)
          if (ref.watch(_request((repository, id))).value case final state?)
            HelpRequestStatusCard(state: state),
      ],
    );
  }
}

class HelpRequestStatusCard extends StatelessWidget {
  const HelpRequestStatusCard({super.key, required this.state});
  final OwnHelpRequestState state;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final latest = state.latest;
    final status = switch (latest?.stage) {
      HelpRequestStage.sent => t.statusSent,
      HelpRequestStage.seen => t.emergencyHelpRequestSeen,
      HelpRequestStage.onTheWay => t.emergencyHelpRequestOnTheWay,
      HelpRequestStage.attended => t.emergencyHelpRequestAttended,
      HelpRequestStage.referred => t.emergencyHelpRequestReferred,
      HelpRequestStage.closedWithoutAssistance => t.emergencyHelpRequestClosed,
      null when state.received => t.statusSent,
      null when state.savedOnPhone => t.emergencyHelpRequestNotSent,
      null => t.statusCouldNotComplete,
    };
    final rejection = switch (state.rejectionReason?.code) {
      'zona_sin_cobertura' => t.emergencyHelpRequestNoCoverage,
      'ubicacion_fuera_de_zona' => t.emergencyHelpRequestOutsideZone,
      'validacion' => t.emergencyHelpRequestInvalid,
      _ => null,
    };
    final updatedAt = latest?.occurredAt ?? state.sentAt;
    return Card(
      child: ListTile(
        title: Text(t.emergencyHelpRequestTitle),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Text(status),
            if (latest?.reason case final reason?) Text(reason),
            if (rejection != null) Text(rejection),
            if (updatedAt != null)
              Text(DateFormat.yMd(t.localeName).add_jm().format(updatedAt.toLocal())),
            if (state.savedOnPhone ||
                state.rejectionReason != null ||
                latest?.stage == HelpRequestStage.referred ||
                latest?.stage == HelpRequestStage.closedWithoutAssistance)
              Text(t.emergencyLifeRisk),
          ],
        ),
      ),
    );
  }
}
