import 'package:vecinal/l10n/app_localizations.dart';

String pilotRejectionText(AppLocalizations t, String code) => switch (code) {
  'conflicto_de_version' => t.serviceConflict,
  'resena_duplicada' => t.duplicateReview,
  'no_puedes_resenarte' => t.selfReview,
  'cuenta_muy_nueva' => t.newAccount,
  'fuera_de_tu_zona' => t.outsideZoneService,
  'limite_diario_alcanzado' => t.dailyLimit,
  'cuenta_suspendida' => t.suspendedAccount,
  _ => t.reviewAgainAlternative,
};
