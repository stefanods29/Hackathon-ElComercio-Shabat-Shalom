import 'dart:math';

import 'package:vecinal_consola/features/casos/domain/emergency_case.dart';

/// Requests in a cell. Below [threshold] it is never a number, so nobody can be singled out
/// (spec: "Mapa de celdas sin ubicaciones exactas"). Zero is also "fewer than three".
class CellCount {
  factory CellCount(int? value) => CellCount._(value != null && value >= threshold ? value : null);

  const CellCount._(this.value);

  static const threshold = 3;

  /// Null means "menos de 3": the number itself never reaches the screen.
  final int? value;

  bool get isBelowThreshold => value == null;
}

enum CellLevel { belowThreshold, low, medium, high }

CellLevel levelOf(CellCount count) {
  final value = count.value;
  if (value == null) return CellLevel.belowThreshold;
  if (value < 10) return CellLevel.low;
  if (value < 25) return CellLevel.medium;
  return CellLevel.high;
}

class CellBounds {
  const CellBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  /// Closed GeoJSON ring, longitude first.
  List<List<double>> get ring => [
    [west, south],
    [east, south],
    [east, north],
    [west, north],
    [west, south],
  ];
}

/// Aggregate of one public cell. Totals come from the API with the same threshold: the console
/// never adds counts up, since a sum could reveal a hidden "menos de 3".
class CellAggregate {
  const CellAggregate({
    required this.id,
    required this.label,
    required this.bounds,
    required this.total,
    required this.byNeed,
  });

  final String id;
  final String label;
  final CellBounds bounds;
  final CellCount total;
  final Map<EmergencyNeed, CellCount> byNeed;

  /// Lot B publishes no totals: a total minus the published needs would reveal a hidden
  /// "menos de 3". Without one, "all needs" shows the busiest published need, never a sum.
  bool get totalPublished => !total.isBelowThreshold;

  CellCount countFor(EmergencyNeed? need) {
    if (need != null) return byNeed[need] ?? CellCount(null);
    if (totalPublished) return total;
    final published = [for (final count in byNeed.values) ?count.value];
    return CellCount(published.isEmpty ? null : published.reduce(max));
  }
}

class CellsSnapshot {
  const CellsSnapshot({required this.cells, required this.updatedAt});

  final List<CellAggregate> cells;
  final DateTime updatedAt;
}

/// Port to the per-cell aggregates of Phase 2, Lot B (part 4).
abstract interface class CellsRepository {
  Future<CellsSnapshot> cells(String zoneId);
}

/// GeoJSON for the map: only polygons and levels, never points of people.
Map<String, dynamic> cellsGeoJson(List<CellAggregate> cells, EmergencyNeed? need) => {
  'type': 'FeatureCollection',
  'features': [
    for (final cell in cells)
      {
        'type': 'Feature',
        'id': cell.id,
        'properties': {'nivel': levelOf(cell.countFor(need)).name},
        'geometry': {
          'type': 'Polygon',
          'coordinates': [cell.bounds.ring],
        },
      },
  ],
};
