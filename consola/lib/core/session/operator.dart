/// Roles that open the console (section 9.1). `curador` arrives with Phase 2, Lot B (part 5).
enum OperationalRole {
  coordinator('coordinador'),
  brigadist('brigadista'),
  moderator('moderador'),
  administrator('administrador'),
  curator('curador');

  const OperationalRole(this.code);

  /// Code in the session's `usuario.roles` (public contract, in Spanish).
  final String code;

  static OperationalRole? fromCode(String code) {
    for (final role in values) {
      if (role.code == code) return role;
    }
    return null;
  }
}

/// Sections of the console, in the order the navigation shows them.
enum ConsoleSection { cases, cells, shifts, moderation, curation, urgentNotices }

/// The person signed in to the console: only what the screens need, never the phone number.
class Operator {
  const Operator({
    required this.id,
    required this.displayName,
    required this.zoneId,
    required this.roles,
  });

  final String id;
  final String displayName;
  final String? zoneId;
  final Set<OperationalRole> roles;

  bool has(OperationalRole role) => roles.contains(role);

  bool get isOperational => roles.isNotEmpty;

  /// Reviews, assigns and closes cases of the zone.
  bool get coordinates =>
      has(OperationalRole.coordinator) || has(OperationalRole.administrator);

  /// Which sections this person may open. The API applies the same roles again.
  bool canOpen(ConsoleSection section) => switch (section) {
    ConsoleSection.cases => coordinates || has(OperationalRole.brigadist),
    ConsoleSection.cells || ConsoleSection.shifts || ConsoleSection.urgentNotices => coordinates,
    // The Phase 1 moderation routes require `moderador`.
    ConsoleSection.moderation => has(OperationalRole.moderator),
    ConsoleSection.curation => coordinates || has(OperationalRole.curator),
  };

  @override
  bool operator ==(Object other) =>
      other is Operator &&
      other.id == id &&
      other.displayName == displayName &&
      other.zoneId == zoneId &&
      other.roles.length == roles.length &&
      other.roles.containsAll(roles);

  @override
  int get hashCode => Object.hash(id, displayName, zoneId, Object.hashAllUnordered(roles));
}

/// Fixed zone of the demo data (`CONSOLE_DATA=demo`).
const demoZoneId = '00000000-0000-4000-8000-0000000000a1';

/// Seeded account for the demo data: no API call and no token behind it.
Operator demoOperator(OperationalRole role) => Operator(
  id: '00000000-0000-4000-8000-00000000010${role.index}',
  displayName: 'Demostración · ${role.code}',
  zoneId: demoZoneId,
  roles: {role},
);
