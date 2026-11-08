import 'package:vecinal_consola/core/network/api_client.dart';
import 'package:vecinal_consola/features/casos/data/http_cases_repository.dart';
import 'package:vecinal_consola/features/casos/domain/emergency_case.dart';
import 'package:vecinal_consola/features/celdas/domain/cells.dart';

/// Per-cell aggregates of Phase 2, Lot B (`GET /v1/zonas/{zonaId}/celdas`).
///
/// The API sends one row per cell and need, only when there are three requests or more. It sends
/// no totals on purpose: a total minus the published needs would reveal a hidden "menos de 3".
/// So the total of a cell is never a number here either, and a need without a row is "menos de 3".
class HttpCellsRepository implements CellsRepository {
  const HttpCellsRepository(this._api);

  final ConsoleApi _api;

  @override
  Future<CellsSnapshot> cells(String zoneId) async {
    final json = await _api.getJson('/v1/zonas/$zoneId/celdas');
    final grouped = <String, ({CellBounds bounds, Map<EmergencyNeed, CellCount> byNeed})>{};
    for (final row in objects(json, 'elementos')) {
      final limits = row['limites'];
      if (limits is! Map) continue;
      double edge(String key) => (limits[key] as num).toDouble();
      final bounds = CellBounds(
        south: edge('sur'),
        west: edge('oeste'),
        north: edge('norte'),
        east: edge('este'),
      );
      final key = '${bounds.south}:${bounds.west}';
      final cell = grouped.putIfAbsent(key, () => (bounds: bounds, byNeed: {}));
      cell.byNeed[caseNeedFromApi(field<String>(row, 'necesidad'))] = CellCount(
        field<int>(row, 'cantidad'),
      );
    }
    var index = 0;
    return CellsSnapshot(
      cells: [
        for (final MapEntry(:key, :value) in grouped.entries)
          CellAggregate(
            id: key,
            label: 'Celda ${++index}',
            bounds: value.bounds,
            total: CellCount(null),
            byNeed: value.byNeed,
          ),
      ],
      updatedAt: optionalInstant(json, 'actualizadoEn') ?? DateTime.now(),
    );
  }
}
