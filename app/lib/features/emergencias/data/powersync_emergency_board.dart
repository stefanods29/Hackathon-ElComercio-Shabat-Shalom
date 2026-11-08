import 'package:powersync/powersync.dart';
import 'package:vecinal/features/emergencias/domain/public_emergency_board.dart';

/// The public projection for the authenticated zone, read from the encrypted offline database.
class PowerSyncEmergencyBoard implements EmergencyBoardRepository {
  const PowerSyncEmergencyBoard(this._database, {required this.zoneId});

  final PowerSyncDatabase _database;
  final String zoneId;

  @override
  Stream<PublicEmergencySnapshot> watch() => _database
      .watch('SELECT 1', triggerOnTables: ['agregados_celda', 'recursos_publicos'])
      .asyncMap(
        (_) => _database.readTransaction((tx) async {
          final demands = await tx.getAll(
            '''
          SELECT celda, necesidad, cantidad, actualizado_en FROM agregados_celda
          WHERE zona_id = ? AND cantidad >= 3 ORDER BY celda, necesidad
          ''',
            [zoneId],
          );
          final resources = await tx.getAll(
            '''
          SELECT id, tipo, cantidad, celda, reportado_en, umbral_segundos, verificacion,
                 confirmaciones, etiqueta_publica, fuente_url, oficial
          FROM recursos_publicos WHERE zona_id = ? ORDER BY reportado_en DESC, id
          ''',
            [zoneId],
          );
          return PublicEmergencySnapshot(
            demands: List.unmodifiable(demands.map(_demand).whereType<CellDemand>()),
            resources: List.unmodifiable(
              resources.map(_resource).whereType<PublicCriticalResource>(),
            ),
          );
        }),
      );

  static CellDemand? _demand(Map<String, Object?> row) {
    final cell = row['celda'] as String?;
    final need = row['necesidad'] as String?;
    final count = row['cantidad'] as int?;
    final updatedAt = DateTime.tryParse(row['actualizado_en'] as String? ?? '');
    if (cell == null || need == null || count == null || count < 3 || updatedAt == null) {
      return null;
    }
    return CellDemand(cell: cell, need: need, count: count, updatedAt: updatedAt);
  }

  static PublicCriticalResource? _resource(Map<String, Object?> row) {
    final kind = row['tipo'] as String?;
    final quantity = row['cantidad'] as int?;
    final cell = row['celda'] as String?;
    final seconds = row['umbral_segundos'] as int?;
    final reportedAt = DateTime.tryParse(row['reportado_en'] as String? ?? '');
    if (kind == null ||
        quantity == null ||
        quantity < 0 ||
        cell == null ||
        seconds == null ||
        seconds < 60 ||
        reportedAt == null) {
      return null;
    }
    final source = Uri.tryParse(row['fuente_url'] as String? ?? '');
    final safeSource =
        source != null &&
        source.scheme == 'https' &&
        source.host.isNotEmpty &&
        source.userInfo.isEmpty &&
        !source.hasFragment;
    return PublicCriticalResource(
      id: row['id'] as String,
      kind: kind,
      quantity: quantity,
      cell: cell,
      reportedAt: reportedAt,
      staleAfter: Duration(seconds: seconds),
      verification: row['verificacion'] as String? ?? 'sin_verificar',
      confirmations: row['confirmaciones'] as int? ?? 0,
      label: row['etiqueta_publica'] as String?,
      source: safeSource ? source : null,
      official: safeSource && row['oficial'] == 1,
    );
  }
}
