import 'package:vecinal/core/router/routes.dart';

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Untrusted push data may select a known route, never an arbitrary URL.
///
/// The push never carries case data: the route only names the screen, which loads what the
/// session may see.
/// - The zone's emergency notice opens the emergency dashboard, which works without a session.
/// - An urgent notice about a case opens the protected case view of the coordinator or brigade
///   member (Lot A, part 3); one without a valid case opens the dashboard (Phase 2, Lot C).
/// - An update of a help request opens the requester's own request (Lot B, part 2), which always
///   offers the official alternatives.
String? routeFor(Map<String, String> data) {
  switch (data['tipo']) {
    case 'modo_emergencia_activado':
      return Routes.emergencyDashboard;
    case 'aviso_urgente':
      if (urgentNoticeIdFor(data) == null) return null;
      final caseId = data['casoId'];
      return caseId != null && _uuid.hasMatch(caseId)
          ? Routes.operationalCase.replaceFirst(':id', caseId)
          : Routes.emergencyDashboard;
    case 'pedido_actualizado':
      return _withId(Routes.emergencyRequest, data['pedidoId']);
    case 'favor_tomado':
      return _withId(Routes.postDetail, data['publicacionId']);
  }
  return null;
}

String? _withId(String route, String? id) =>
    id == null || !_uuid.hasMatch(id) ? null : route.replaceFirst(':id', id);

/// Id of the urgent notice to confirm when it is opened, which stops its SMS backup; null for any
/// other push or a malformed id.
String? urgentNoticeIdFor(Map<String, String> data) {
  final id = data['avisoId'];
  if (data['tipo'] != 'aviso_urgente' || id == null || !_uuid.hasMatch(id)) return null;
  return id;
}
