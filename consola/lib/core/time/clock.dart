import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal_consola/l10n/app_localizations.dart';

/// Current time; tests and the demo data replace it.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

String _two(int value) => value.toString().padLeft(2, '0');

/// `14:05`, in the browser's time zone (the pilot works in America/Lima).
String formatClock(DateTime at) {
  final local = at.toLocal();
  return '${_two(local.hour)}:${_two(local.minute)}';
}

/// `07/11/2026`.
String formatDay(DateTime at) {
  final local = at.toLocal();
  return '${_two(local.day)}/${_two(local.month)}/${local.year}';
}

/// `07/11/2026 14:05`.
String formatDayAndClock(DateTime at) => '${formatDay(at)} ${formatClock(at)}';

/// `2026-11-07`, the local calendar day of [at].
String isoDay(DateTime at) {
  final local = at.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-${_two(local.month)}-${_two(local.day)}';
}

/// Waiting times in words: "12 min", "2 h 5 min" or "menos de 1 min".
String describeDuration(AppLocalizations l10n, Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 1) return l10n.durationUnderAMinute;
  if (minutes < 60) return l10n.durationMinutes(minutes);
  final hours = duration.inHours;
  final rest = minutes - hours * 60;
  return rest == 0 ? l10n.durationHours(hours) : l10n.durationHoursMinutes(hours, rest);
}
