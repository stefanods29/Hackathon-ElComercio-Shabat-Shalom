import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal_consola/core/config/console_environment.dart';
import 'package:vecinal_consola/core/network/api_client.dart';
import 'package:vecinal_consola/core/network/api_errors.dart';
import 'package:vecinal_consola/core/session/operator.dart';
import 'package:vecinal_consola/core/session/session_controller.dart';
import 'package:vecinal_consola/core/time/clock.dart';
import 'package:vecinal_consola/features/casos/data/demo_cases_repository.dart';
import 'package:vecinal_consola/features/casos/domain/cases_repository.dart';
import 'package:vecinal_consola/features/casos/domain/emergency_case.dart';

/// Configurable times of section 9.2; the agreed values replace these examples.
final reviewPolicyProvider = Provider<ReviewPolicy>((ref) => const ReviewPolicy());

/// How often the queue reloads while the tab is visible.
const queueRefreshInterval = Duration(seconds: 15);

/// Integration seam for Phase 2, Lot B: the real cases API stays off until it is injected here
/// (see `docs/fase-2/lote-c-consola-web-y-avisos-urgentes/integracion.md`).
final operationalCasesFactoryProvider =
    Provider<CasesRepository Function(ConsoleApi api, Operator viewer)?>((ref) => null);

/// Null when the module is not available: the screens say so instead of inventing cases.
final casesRepositoryProvider = Provider<CasesRepository?>((ref) {
  final user = ref.watch(currentOperatorProvider);
  if (user == null) return null;
  if (ref.watch(demoDataProvider)) {
    return DemoCasesRepository(viewer: user, now: ref.watch(clockProvider));
  }
  return ref.watch(operationalCasesFactoryProvider)?.call(ref.watch(consoleApiProvider), user);
});

class QueueSnapshot {
  const QueueSnapshot({required this.cases, required this.fetchedAt});

  final List<EmergencyCase> cases;
  final DateTime fetchedAt;
}

final caseQueueProvider = FutureProvider.autoDispose<QueueSnapshot>((ref) async {
  final repository = ref.watch(casesRepositoryProvider);
  final zoneId = ref.watch(currentOperatorProvider)?.zoneId;
  if (repository == null) throw const ModuleNotAvailable();
  if (zoneId == null) return QueueSnapshot(cases: const [], fetchedAt: ref.read(clockProvider)());
  final cases = await repository.queue(zoneId);
  return QueueSnapshot(
    cases: sortQueue(cases.where((item) => item.status.isOpen)),
    fetchedAt: ref.read(clockProvider)(),
  );
});

final caseDetailProvider = FutureProvider.autoDispose.family<EmergencyCase, String>((
  ref,
  caseId,
) async {
  final repository = ref.watch(casesRepositoryProvider);
  if (repository == null) throw const ModuleNotAvailable();
  return repository.detail(caseId);
});

final availablePeopleProvider = FutureProvider.autoDispose<List<AvailablePerson>>((ref) async {
  final repository = ref.watch(casesRepositoryProvider);
  final zoneId = ref.watch(currentOperatorProvider)?.zoneId;
  if (repository == null) throw const ModuleNotAvailable();
  if (zoneId == null) return const [];
  return repository.availablePeople(zoneId);
});

final caseCommandsProvider = Provider<CaseCommands>(CaseCommands.new);

/// Applies a change with the version that was on screen and reloads what showed the old state.
class CaseCommands {
  CaseCommands(this._ref);

  final Ref _ref;

  Future<EmergencyCase> apply(
    EmergencyCase seen,
    CaseCommand command, {
    required String idempotencyKey,
  }) async {
    final repository = _ref.read(casesRepositoryProvider);
    if (repository == null) throw const ModuleNotAvailable();
    final updated = await repository.apply(
      seen.id,
      seenVersion: seen.version,
      command: command,
      idempotencyKey: idempotencyKey,
    );
    _ref.invalidate(caseDetailProvider(seen.id));
    _ref.invalidate(caseQueueProvider);
    return updated;
  }
}
