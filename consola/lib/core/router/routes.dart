import 'package:flutter/material.dart';
import 'package:vecinal_consola/core/session/operator.dart';
import 'package:vecinal_consola/l10n/app_localizations.dart';

/// Paths of the console. Ids in a path are opaque; no case data travels in the URL.
abstract final class Routes {
  static const signIn = '/ingreso';
  static const cases = '/casos';
  static const cells = '/celdas';
  static const shifts = '/turnos';
  static const moderation = '/moderacion';
  static const curation = '/curaduria';
  static const urgentNotices = '/avisos-urgentes';

  static String caseDetail(String id) => '$cases/$id';

  static String directory(String file) => '$curation/$file';
}

String pathOf(ConsoleSection section) => switch (section) {
  ConsoleSection.cases => Routes.cases,
  ConsoleSection.cells => Routes.cells,
  ConsoleSection.shifts => Routes.shifts,
  ConsoleSection.moderation => Routes.moderation,
  ConsoleSection.curation => Routes.curation,
  ConsoleSection.urgentNotices => Routes.urgentNotices,
};

/// Section a location belongs to, or null for an unknown path.
ConsoleSection? sectionOf(String location) {
  for (final section in ConsoleSection.values) {
    final path = pathOf(section);
    if (location == path || location.startsWith('$path/')) return section;
  }
  return null;
}

/// First section the person may open: where the console lands after signing in.
String homeFor(Operator user) {
  for (final section in ConsoleSection.values) {
    if (user.canOpen(section)) return pathOf(section);
  }
  return Routes.signIn;
}

String sectionLabel(AppLocalizations l10n, ConsoleSection section) => switch (section) {
  ConsoleSection.cases => l10n.navCases,
  ConsoleSection.cells => l10n.navCells,
  ConsoleSection.shifts => l10n.navShifts,
  ConsoleSection.moderation => l10n.navModeration,
  ConsoleSection.curation => l10n.navCuration,
  ConsoleSection.urgentNotices => l10n.navUrgentNotices,
};

IconData sectionIcon(ConsoleSection section) => switch (section) {
  ConsoleSection.cases => Icons.inbox_outlined,
  ConsoleSection.cells => Icons.grid_view_outlined,
  ConsoleSection.shifts => Icons.badge_outlined,
  ConsoleSection.moderation => Icons.gavel_outlined,
  ConsoleSection.curation => Icons.local_hospital_outlined,
  ConsoleSection.urgentNotices => Icons.sms_outlined,
};

String roleLabel(AppLocalizations l10n, OperationalRole role) => switch (role) {
  OperationalRole.coordinator => l10n.roleCoordinator,
  OperationalRole.brigadist => l10n.roleBrigadist,
  OperationalRole.moderator => l10n.roleModerator,
  OperationalRole.administrator => l10n.roleAdministrator,
  OperationalRole.curator => l10n.roleCurator,
};

/// Role code of a history entry or an assignee (`coordinador`, `vecino`, `sistema`…) in words.
String roleCodeLabel(AppLocalizations l10n, String code) {
  final role = OperationalRole.fromCode(code);
  if (role != null) return roleLabel(l10n, role);
  return switch (code) {
    'vecino' => l10n.roleNeighbor,
    'sistema' => l10n.roleSystem,
    _ => code,
  };
}
