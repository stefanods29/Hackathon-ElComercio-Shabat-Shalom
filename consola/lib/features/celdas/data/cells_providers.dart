import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal_consola/core/config/console_environment.dart';
import 'package:vecinal_consola/core/network/api_client.dart';
import 'package:vecinal_consola/core/network/api_errors.dart';
import 'package:vecinal_consola/core/session/session_controller.dart';
import 'package:vecinal_consola/core/time/clock.dart';
import 'package:vecinal_consola/features/casos/domain/emergency_case.dart';
import 'package:vecinal_consola/features/celdas/domain/cells.dart';

/// Integration seam for Phase 2, Lot B (part 4).
final operationalCellsFactoryProvider = Provider<CellsRepository Function(ConsoleApi api)?>(
  (ref) => null,
);

final cellsRepositoryProvider = Provider<CellsRepository?>((ref) {
  if (ref.watch(currentOperatorProvider) == null) return null;
  if (ref.watch(demoDataProvider)) return DemoCellsRepository(now: ref.watch(clockProvider));
  return ref.watch(operationalCellsFactoryProvider)?.call(ref.watch(consoleApiProvider));
});

final cellsProvider = FutureProvider.autoDispose<CellsSnapshot>((ref) async {
  final repository = ref.watch(cellsRepositoryProvider);
  final zoneId = ref.watch(currentOperatorProvider)?.zoneId;
  if (repository == null) throw const ModuleNotAvailable();
  if (zoneId == null) return CellsSnapshot(cells: const [], updatedAt: ref.read(clockProvider)());
  return repository.cells(zoneId);
});

/// A 3 × 3 grid over the pilot's demonstration rectangle, with fictitious counts. The threshold
/// is applied here as the API will: under 3 the number never leaves the repository.
class DemoCellsRepository implements CellsRepository {
  DemoCellsRepository({required this.now});

  final DateTime Function() now;

  static const _counts = <List<int>>[
    // water, food, medicine, transport, shelter, other, total
    [2, 0, 1, 0, 0, 0, 3],
    [7, 4, 2, 1, 0, 1, 15],
    [0, 0, 0, 0, 0, 0, 0],
    [12, 9, 3, 2, 4, 1, 31],
    [1, 2, 0, 0, 0, 0, 3],
    [3, 3, 0, 0, 0, 0, 6],
    [0, 1, 0, 0, 0, 0, 1],
    [26, 11, 6, 3, 5, 2, 53],
    [4, 0, 0, 0, 0, 0, 4],
  ];

  @override
  Future<CellsSnapshot> cells(String zoneId) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    const south = ConsoleEnvironment.pilotSouth;
    const west = ConsoleEnvironment.pilotWest;
    const height = (ConsoleEnvironment.pilotNorth - south) / 3;
    const width = (ConsoleEnvironment.pilotEast - west) / 3;
    const rows = ['A', 'B', 'C'];
    return CellsSnapshot(
      updatedAt: now(),
      cells: [
        for (var row = 0; row < 3; row++)
          for (var column = 0; column < 3; column++)
            _cell(
              id: '${rows[row]}${column + 1}',
              bounds: CellBounds(
                south: south + row * height,
                west: west + column * width,
                north: south + (row + 1) * height,
                east: west + (column + 1) * width,
              ),
              counts: _counts[row * 3 + column],
            ),
      ],
    );
  }

  static CellAggregate _cell({
    required String id,
    required CellBounds bounds,
    required List<int> counts,
  }) => CellAggregate(
    id: id,
    label: 'Celda $id (ejemplo)',
    bounds: bounds,
    total: CellCount(counts[6]),
    byNeed: {
      for (final need in EmergencyNeed.values) need: CellCount(counts[need.index]),
    },
  );
}
