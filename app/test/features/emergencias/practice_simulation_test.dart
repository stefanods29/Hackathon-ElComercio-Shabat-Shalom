import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/features/directorio/domain/directory.dart';
import 'package:vecinal/features/emergencias/data/emergency_providers.dart';
import 'package:vecinal/features/emergencias/domain/emergency.dart';

/// The practice simulation shows the whole flow for a demo, only on an explicit action and always
/// marked as simulated; by itself a practice request never claims a server receipt.
void main() {
  final now = DateTime.utc(2026, 11, 8, 15);
  late PracticeEmergencyRepository practice;
  setUp(() => practice = PracticeEmergencyRepository(() => now));
  tearDown(() => practice.close());

  Future<OwnHelpRequest> request() async => (await practice.watch().first).requests.single;

  test('sin acción de simulación el pedido de práctica queda local', () async {
    await practice.saveRequest(
      const HelpRequestDraft(
        id: 'pedido',
        idempotencyKey: 'clave',
        need: EmergencyNeed.water,
        description: 'Pedido de práctica',
        locationLabel: '',
        approximateLocation: GeoPoint(-12.085, -77.035),
      ),
    );
    expect((await request()).status, HelpRequestStatus.local);
    expect((await request()).sentAt, isNull);
    await expectLater(practice.confirmAttendance('pedido'), throwsStateError);
  });

  test('cada paso simulado avanza el estado y la atención se confirma en camino', () async {
    await practice.saveRequest(
      const HelpRequestDraft(
        id: 'pedido',
        idempotencyKey: 'clave',
        need: EmergencyNeed.water,
        description: 'Pedido de práctica',
        locationLabel: '',
        approximateLocation: GeoPoint(-12.085, -77.035),
      ),
    );
    for (final expected in [
      HelpRequestStatus.sent,
      HelpRequestStatus.seen,
      HelpRequestStatus.onTheWay,
    ]) {
      practice.simulateNextStep('pedido');
      expect((await request()).status, expected);
    }
    expect((await request()).canConfirmAttendance, isTrue);
    expect((await request()).history.last.role, PracticeEmergencyRepository.simulatedRole);
    await practice.confirmAttendance('pedido');
    expect((await request()).status, HelpRequestStatus.attended);
    practice.simulateNextStep('pedido');
    expect((await request()).status, HelpRequestStatus.attended);
  });

  test('la emergencia y los recursos simulados se activan a pedido', () async {
    expect((await practice.watch().first).activeEvent, isFalse);
    practice.simulateEvent(active: true);
    expect((await practice.watch().first).activeEvent, isTrue);
    final before = (await practice.watch().first).resources.length;
    practice.simulateResource();
    final resources = (await practice.watch().first).resources;
    expect(resources, hasLength(before + 1));
    expect(resources.first.verification, ResourceVerification.unverified);
    practice.simulateEvent(active: false);
    expect((await practice.watch().first).activeEvent, isFalse);
  });
}
