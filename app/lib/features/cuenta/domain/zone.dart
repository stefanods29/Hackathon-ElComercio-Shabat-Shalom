/// Una zona del vecindario (Parte 5 del Lote D).
final class Zone {
  const Zone({
    required this.id,
    required this.name,
    required this.district,
  });

  final String id;
  final String name;
  final String district;

  @override
  String toString() => '$name ($district)';
}
