final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Untrusted push data may select a known route, never an arbitrary URL.
///
/// The zone's emergency notice and urgent notices open the emergency dashboard: the push carries
/// no case data, and the dashboard opens without a session (Phase 2, Lot C).
String? routeFor(Map<String, String> data) {
  final type = data['tipo'];
  if (type == 'modo_emergencia_activado') return '/emergencia/tablero';
  if (type == 'aviso_urgente') {
    return urgentNoticeIdFor(data) == null ? null : '/emergencia/tablero';
  }
  final id = data['publicacionId'];
  if (type != 'favor_tomado' || id == null || !_uuid.hasMatch(id)) return null;
  return '/publicaciones/$id';
}

/// Id of the urgent notice to confirm when it is opened, which stops its SMS backup; null for any
/// other push or a malformed id.
String? urgentNoticeIdFor(Map<String, String> data) {
  final id = data['avisoId'];
  if (data['tipo'] != 'aviso_urgente' || id == null || !_uuid.hasMatch(id)) return null;
  return id;
}
