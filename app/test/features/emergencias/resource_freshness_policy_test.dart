import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/features/emergencias/domain/emergency.dart';

void main() {
  const policy = ResourceFreshnessPolicy();
  final now = DateTime.utc(2026, 11, 8, 12);
  const thresholds = {
    ResourceKind.water: Duration(hours: 2),
    ResourceKind.food: Duration(hours: 4),
    ResourceKind.medicine: Duration(hours: 2),
    ResourceKind.shelter: Duration(hours: 12),
    ResourceKind.meetingPoint: Duration(days: 30),
    ResourceKind.other: Duration(hours: 4),
  };

  for (final kind in ResourceKind.values) {
    test('respeta el límite local de ${kind.name} desde el instante exacto', () {
      final boundary = now.subtract(thresholds[kind]!);
      CriticalResource resource(DateTime reportedAt) => CriticalResource(
        id: 'recurso',
        kind: kind,
        description: 'Recurso de práctica',
        reportedAt: reportedAt,
      );

      expect(policy.isStale(resource(boundary.add(const Duration(milliseconds: 1))), now), isFalse);
      expect(policy.isStale(resource(boundary), now), isTrue);
    });
  }

  test('el límite del servidor prevalece aunque sea menor o mayor que el local', () {
    final reportedAt = now.subtract(const Duration(hours: 2));
    CriticalResource resource(Duration limit) => CriticalResource(
      id: 'agua',
      kind: ResourceKind.water,
      description: 'Recurso descargado',
      reportedAt: reportedAt,
      staleAfter: limit,
    );

    expect(policy.isStale(resource(const Duration(minutes: 5)), now), isTrue);
    expect(policy.isStale(resource(const Duration(hours: 3)), now), isFalse);
  });
}
