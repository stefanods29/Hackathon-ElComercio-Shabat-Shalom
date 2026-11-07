import 'package:vecinal/l10n/app_localizations.dart';

/// "hace X" in plain language, to show how fresh the data is (section 7.3).
///
/// Texts come from `app_es.arb` with ICU plurals so they translate cleanly
/// (e.g. to Quechua in Fase 3).
String timeAgo(DateTime moment, DateTime now, AppLocalizations texts) {
  final difference = now.difference(moment);
  if (difference.isNegative || difference.inSeconds < 60) {
    return texts.timeAgoMoment;
  }
  if (difference.inMinutes < 60) {
    return texts.timeAgoMinutes(difference.inMinutes);
  }
  if (difference.inHours < 24) {
    return texts.timeAgoHours(difference.inHours);
  }
  return texts.timeAgoDays(difference.inDays);
}
