class CellDemand {
  const CellDemand({
    required this.cell,
    required this.need,
    required this.count,
    required this.updatedAt,
  });

  final String cell;
  final String need;
  final int count;
  final DateTime updatedAt;
}

class PublicCriticalResource {
  const PublicCriticalResource({
    required this.id,
    required this.kind,
    required this.quantity,
    required this.cell,
    required this.reportedAt,
    required this.staleAfter,
    required this.verification,
    required this.confirmations,
    required this.official,
    this.label,
    this.source,
  });

  final String id;
  final String kind;
  final int quantity;
  final String cell;
  final DateTime reportedAt;
  final Duration staleAfter;
  final String verification;
  final int confirmations;
  final bool official;
  final String? label;
  final Uri? source;

  DateTime get staleAt => reportedAt.add(staleAfter);

  bool isStaleAt(DateTime now) => !now.isBefore(staleAt);
}

class PublicEmergencySnapshot {
  const PublicEmergencySnapshot({required this.demands, required this.resources});

  final List<CellDemand> demands;
  final List<PublicCriticalResource> resources;
}

abstract interface class EmergencyBoardRepository {
  Stream<PublicEmergencySnapshot> watch();
}
