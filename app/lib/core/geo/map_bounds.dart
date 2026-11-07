/// WGS84 bounds supported by a Web Mercator map, without platform dependencies.
class MapBounds {
  const MapBounds({
    required this.west,
    required this.south,
    required this.east,
    required this.north,
  });

  final double west;
  final double south;
  final double east;
  final double north;

  bool get isValid =>
      [west, south, east, north].every((coordinate) => coordinate.isFinite) &&
      west >= -180 &&
      east <= 180 &&
      west < east &&
      south >= -85.05112878 &&
      north <= 85.05112878 &&
      south < north;

  double get centerLatitude => (south + north) / 2;
  double get centerLongitude => (west + east) / 2;
}
