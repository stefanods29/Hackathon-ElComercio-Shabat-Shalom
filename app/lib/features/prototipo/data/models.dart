// Modelos simples del prototipo (solo para UI/UX, sin lógica de negocio real).

class ZoneProto {
  final String id;
  final String name;
  final String district;

  const ZoneProto({required this.id, required this.name, required this.district});
}

class PostProto {
  final String id;
  final String title;
  final String type;
  final String typeLabel;
  final String status;
  final String statusLabel;
  final String ago;
  final String author;
  final String zone;

  const PostProto({
    required this.id,
    required this.title,
    required this.type,
    required this.typeLabel,
    required this.status,
    required this.statusLabel,
    required this.ago,
    required this.author,
    required this.zone,
  });
}
