import 'package:vecinal/core/router/routes.dart';

final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Untrusted push data may select a known route, never an arbitrary URL.
String? routeFor(Map<String, String> data) {
  final (id, route) = switch (data['tipo']) {
    'favor_tomado' => (data['publicacionId'], Routes.postDetail),
    'aviso_urgente' => (data['casoId'], Routes.operationalCase),
    _ => (null, null),
  };
  if (id == null || route == null || !_uuid.hasMatch(id)) return null;
  return route.replaceFirst(':id', id);
}
