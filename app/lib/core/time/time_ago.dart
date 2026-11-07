/// "hace X" in plain language, to show how fresh the data is (section 7.3).
///
/// Lot D moves it to the language files when Quechua is added.
String timeAgo(DateTime moment, DateTime now) {
  final difference = now.difference(moment);
  if (difference.isNegative || difference.inSeconds < 60) {
    return 'hace un momento';
  }
  if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes;
    return minutes == 1 ? 'hace 1 minuto' : 'hace $minutes minutos';
  }
  if (difference.inHours < 24) {
    final hours = difference.inHours;
    return hours == 1 ? 'hace 1 hora' : 'hace $hours horas';
  }
  final days = difference.inDays;
  return days == 1 ? 'hace 1 día' : 'hace $days días';
}
