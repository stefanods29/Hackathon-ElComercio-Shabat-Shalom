import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal_consola/core/config/console_environment.dart';
import 'package:vecinal_consola/core/network/api_client.dart';
import 'package:vecinal_consola/core/network/api_errors.dart';
import 'package:vecinal_consola/core/session/operator.dart';
import 'package:vecinal_consola/core/session/session_controller.dart';
import 'package:vecinal_consola/core/time/clock.dart';
import 'package:vecinal_consola/features/avisos_urgentes/domain/urgent_notices.dart';

final urgentNoticesRepositoryProvider = Provider<UrgentNoticesRepository?>((ref) {
  if (ref.watch(currentOperatorProvider) == null) return null;
  if (ref.watch(demoDataProvider)) return DemoUrgentNoticesRepository(now: ref.watch(clockProvider));
  return HttpUrgentNoticesRepository(ref.watch(consoleApiProvider));
});

/// Only the roles that receive urgent notices ask for them.
final receivesUrgentNoticesProvider = Provider<bool>((ref) {
  final user = ref.watch(currentOperatorProvider);
  return user != null &&
      (user.coordinates || user.has(OperationalRole.brigadist));
});

final pendingUrgentNoticesProvider = FutureProvider.autoDispose<List<UrgentNotice>>((ref) async {
  final repository = ref.watch(urgentNoticesRepositoryProvider);
  if (repository == null || !ref.watch(receivesUrgentNoticesProvider)) return const [];
  final notices = await repository.pending();
  return [...notices]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
});

/// Days of the summary on screen (1, 7 or 30).
final summaryDaysProvider = NotifierProvider<SummaryDays, int>(SummaryDays.new);

class SummaryDays extends Notifier<int> {
  @override
  int build() => 7;

  void select(int days) => state = days;
}

final urgentSummaryProvider = FutureProvider.autoDispose<UrgentNoticeSummary>((ref) async {
  final repository = ref.watch(urgentNoticesRepositoryProvider);
  if (repository == null) throw const ModuleNotAvailable();
  final days = ref.watch(summaryDaysProvider);
  return repository.summary(since: ref.read(clockProvider)().subtract(Duration(days: days)));
});

/// Confirms a notice and reloads the banner.
Future<void> confirmUrgentNotice(WidgetRef ref, UrgentNotice notice, String idempotencyKey) async {
  final repository = ref.read(urgentNoticesRepositoryProvider);
  if (repository == null) return;
  await repository.confirm(notice.id, idempotencyKey: idempotencyKey);
  ref.invalidate(pendingUrgentNoticesProvider);
}

class HttpUrgentNoticesRepository implements UrgentNoticesRepository {
  HttpUrgentNoticesRepository(this._api);

  final ConsoleApi _api;

  @override
  Future<List<UrgentNotice>> pending() async {
    final body = await _api.getJson('/v1/avisos-urgentes');
    return [
      for (final row in objects(body, 'datos'))
        if (UrgentTemplate.fromCode(field<String>(row, 'plantilla')) case final template?)
          UrgentNotice(
            id: field<String>(row, 'id'),
            template: template,
            caseId: row['casoId'] is String ? row['casoId'] as String : null,
            createdAt: instant(row, 'creadoEn'),
          ),
    ];
  }

  @override
  Future<void> confirm(String noticeId, {required String idempotencyKey}) async {
    await _api.postJson(
      '/v1/avisos-urgentes/$noticeId/confirmar',
      idempotencyKey: idempotencyKey,
      expected: const {200},
    );
  }

  @override
  Future<UrgentNoticeSummary> summary({DateTime? since}) async {
    final body = await _api.getJson(
      '/v1/operacion/avisos-urgentes/resumen',
      query: {if (since != null) 'desde': since.toUtc().toIso8601String()},
    );
    final withoutBackup = field<Map<Object?, Object?>>(body, 'sinRespaldo');
    final latency = field<Map<Object?, Object?>>(body, 'confirmacionSegundos');
    final spending = Map<String, Object?>.from(field<Map<Object?, Object?>>(body, 'gasto'));
    return UrgentNoticeSummary(
      since: instant(body, 'desde'),
      until: instant(body, 'hasta'),
      smsProvider: field<String>(body, 'proveedorSms'),
      total: field<int>(body, 'total'),
      confirmed: field<int>(body, 'confirmados'),
      unconfirmed: field<int>(body, 'sinConfirmar'),
      smsSent: field<int>(body, 'smsEnviados'),
      withoutBackup: {
        for (final MapEntry(:key, :value) in withoutBackup.entries)
          if (key is String && value is int) key: value,
      },
      confirmationP50Seconds: latency['p50'] is int ? latency['p50'] as int : null,
      confirmationP95Seconds: latency['p95'] is int ? latency['p95'] as int : null,
      todayCents: field<int>(spending, 'hoyCentavos'),
      monthCents: field<int>(spending, 'mesCentavos'),
      dailyCapCents: field<int>(spending, 'topeDiarioCentavos'),
      monthlyCapCents: field<int>(spending, 'topeMensualCentavos'),
    );
  }
}

/// One pending notice about a seeded case, for `CONSOLE_DATA=demo`.
class DemoUrgentNoticesRepository implements UrgentNoticesRepository {
  DemoUrgentNoticesRepository({required this.now}) {
    _pending.add(
      UrgentNotice(
        id: '00000000-0000-4000-8000-000000000501',
        template: UrgentTemplate.aboutToEscalate,
        caseId: '00000000-0000-4000-8000-000000000001',
        createdAt: now().subtract(const Duration(minutes: 2)),
      ),
    );
  }

  final DateTime Function() now;
  final _pending = <UrgentNotice>[];

  @override
  Future<List<UrgentNotice>> pending() async => List.unmodifiable(_pending);

  @override
  Future<void> confirm(String noticeId, {required String idempotencyKey}) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    _pending.removeWhere((notice) => notice.id == noticeId);
  }

  @override
  Future<UrgentNoticeSummary> summary({DateTime? since}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final until = now();
    return UrgentNoticeSummary(
      since: since ?? until.subtract(const Duration(days: 7)),
      until: until,
      smsProvider: 'fake',
      total: 42,
      confirmed: 37,
      unconfirmed: 5,
      smsSent: 4,
      withoutBackup: const {'tope_de_gasto': 0, 'sin_proveedor': 0, 'sin_telefono': 1, 'sms_fallido': 0},
      confirmationP50Seconds: 48,
      confirmationP95Seconds: 170,
      todayCents: 10,
      monthCents: 85,
      dailyCapCents: 500,
      monthlyCapCents: 5000,
    );
  }
}
