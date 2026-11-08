import 'dart:math';

import 'package:vecinal/features/directorio/domain/directory.dart';

const _accents = {
  'á': 'a',
  'à': 'a',
  'ä': 'a',
  'â': 'a',
  'é': 'e',
  'è': 'e',
  'ë': 'e',
  'ê': 'e',
  'í': 'i',
  'ì': 'i',
  'ï': 'i',
  'î': 'i',
  'ó': 'o',
  'ò': 'o',
  'ö': 'o',
  'ô': 'o',
  'ú': 'u',
  'ù': 'u',
  'ü': 'u',
  'û': 'u',
  'ñ': 'n',
};

/// Lower case, without accents and with single spaces: "Gásfiter" → "gasfiter".
String normalizeForSearch(String text) {
  final buffer = StringBuffer();
  for (final char in text.toLowerCase().split('')) {
    buffer.write(_accents[char] ?? char);
  }
  return buffer.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

/// True when every word of [query] appears in [text], ignoring accents and case, and tolerating
/// one typo in words of 4 letters or more ("gasfiter" finds "Gasfitero a domicilio").
bool matchesSearch(String text, String query) {
  final words = normalizeForSearch(text).split(' ').where((word) => word.isNotEmpty).toList();
  final terms = normalizeForSearch(query).split(' ').where((term) => term.isNotEmpty);
  return terms.every((term) => words.any((word) => _termMatches(term, word)));
}

bool _termMatches(String term, String word) {
  if (word.startsWith(term) || word.contains(term)) return true;
  if (term.length < 4) return false;
  final prefix = word.length >= term.length ? word.substring(0, term.length) : word;
  return _distanceAtMostOne(term, prefix) || _distanceAtMostOne(term, word);
}

/// Levenshtein distance ≤ 1, without building the whole matrix.
bool _distanceAtMostOne(String a, String b) {
  if ((a.length - b.length).abs() > 1) return false;
  var i = 0;
  var j = 0;
  var edits = 0;
  while (i < a.length && j < b.length) {
    if (a[i] == b[j]) {
      i++;
      j++;
      continue;
    }
    if (++edits > 1) return false;
    if (a.length > b.length) {
      i++;
    } else if (a.length < b.length) {
      j++;
    } else {
      i++;
      j++;
    }
  }
  return edits + (a.length - i) + (b.length - j) <= 1;
}

/// Applies the filters of [query] and sorts like the server: Visto Bueno of verified neighbors
/// of the zone first, then the ranking score, then the title.
List<Service> filterAndSortServices(Iterable<Service> services, ServiceQuery query) {
  final text = query.text?.trim() ?? '';
  final filtered = services.where((service) {
    if (query.categoryId != null && service.categoryId != query.categoryId) return false;
    if (query.emergencyOnly && !service.availableInEmergency) return false;
    if (text.isEmpty) return true;
    return matchesSearch('${service.title} ${service.description ?? ''}', text);
  }).toList();
  filtered.sort((a, b) {
    final byEndorsements = b.zoneEndorsements.compareTo(a.zoneEndorsements);
    if (byEndorsements != 0) return byEndorsements;
    final byScore = b.rankingScore.compareTo(a.rankingScore);
    if (byScore != 0) return byScore;
    return normalizeForSearch(a.title).compareTo(normalizeForSearch(b.title));
  });
  return filtered;
}

/// Approximate distance in meters between two public locations, rounded to multiples of 50 so
/// it cannot be used to triangulate anyone.
int approximateDistanceMeters(GeoPoint from, GeoPoint to) {
  const earthRadius = 6371000.0;
  double radians(double degrees) => degrees * pi / 180;
  final dLat = radians(to.lat - from.lat);
  final dLng = radians(to.lng - from.lng);
  final a =
      pow(sin(dLat / 2), 2) + cos(radians(from.lat)) * cos(radians(to.lat)) * pow(sin(dLng / 2), 2);
  final meters = 2 * earthRadius * asin(min(1, sqrt(a)));
  return (meters / 50).round() * 50;
}
