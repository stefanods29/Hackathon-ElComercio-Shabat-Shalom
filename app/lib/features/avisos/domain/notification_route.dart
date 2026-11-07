final _uuid = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// Untrusted push data may select a known route, never an arbitrary URL.
String? routeFor(Map<String, String> data) {
  final id = data['publicacionId'];
  if (data['tipo'] != 'favor_tomado' || id == null || !_uuid.hasMatch(id)) return null;
  return '/publicaciones/$id';
}
