import 'package:vecinal/core/submissions/submission_status.dart';

/// A directory category (`directorio.categorias`). [id] is a stable slug, e.g. `gasfiteria`.
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.icon,
    required this.usefulInEmergency,
    required this.order,
  });

  final String id;
  final String name;

  /// Name of a Material icon, chosen by the backend.
  final String icon;
  final bool usefulInEmergency;
  final int order;
}

/// A latitude and longitude. In the directory it is always the public copy (ADR 0010).
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  /// The public copy: rounded to 3 decimals (about 110 m), as the server stores it.
  GeoPoint approximate() =>
      GeoPoint((lat * 1000).roundToDouble() / 1000, (lng * 1000).roundToDouble() / 1000);

  @override
  bool operator ==(Object other) => other is GeoPoint && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

/// A service of the neighbor's zone, as the phone sees it (read from the local database).
class Service {
  const Service({
    required this.id,
    required this.providerId,
    required this.zoneId,
    required this.categoryId,
    required this.title,
    required this.location,
    required this.version,
    required this.updatedAt,
    this.description,
    this.coverageRadiusMeters = 2000,
    this.availableInEmergency = false,
    this.attributes = const {},
    this.reviewCount = 0,
    this.averageRating = 0,
    this.rankingScore = 0,
    this.zoneEndorsements = 0,
    this.submissionStatus = SubmissionStatus.sent,
  });

  final String id;

  /// Id of the provider, who is the neighbor that owns the service.
  final String providerId;
  final String zoneId;
  final String categoryId;
  final String title;
  final String? description;

  /// Public copy of the location (ADR 0010).
  final GeoPoint location;
  final int coverageRadiusMeters;
  final bool availableInEmergency;

  /// Flexible attributes chosen by the provider (reference fee, schedule…).
  final Map<String, Object?> attributes;
  final int reviewCount;
  final double averageRating;
  final double rankingScore;

  /// Visto Bueno of verified neighbors of the service's zone, computed by the server.
  final int zoneEndorsements;

  /// Version the neighbor is looking at; it travels to the server when editing.
  final int version;
  final DateTime updatedAt;

  /// Status of the last local change of this service.
  final SubmissionStatus submissionStatus;

  Service copyWith({SubmissionStatus? submissionStatus}) => Service(
    id: id,
    providerId: providerId,
    zoneId: zoneId,
    categoryId: categoryId,
    title: title,
    description: description,
    location: location,
    coverageRadiusMeters: coverageRadiusMeters,
    availableInEmergency: availableInEmergency,
    attributes: attributes,
    reviewCount: reviewCount,
    averageRating: averageRating,
    rankingScore: rankingScore,
    zoneEndorsements: zoneEndorsements,
    version: version,
    updatedAt: updatedAt,
    submissionStatus: submissionStatus ?? this.submissionStatus,
  );
}

/// Public profile of a neighbor who offers services. It never carries contact data.
class ProviderProfile {
  const ProviderProfile({
    required this.id,
    required this.publicName,
    required this.updatedAt,
    this.description,
    this.submissionStatus = SubmissionStatus.sent,
  });

  final String id;
  final String publicName;
  final String? description;
  final DateTime updatedAt;
  final SubmissionStatus submissionStatus;
}

/// What the provider fills in to publish or edit a service.
class ServiceDraft {
  const ServiceDraft({
    required this.categoryId,
    required this.title,
    required this.location,
    this.description,
    this.showExactLocation = false,
    this.coverageRadiusMeters = 2000,
    this.availableInEmergency = false,
  });

  final String categoryId;
  final String title;
  final String? description;

  /// Exact location: it only goes to the server, which keeps it private (ADR 0010).
  final GeoPoint location;

  /// The provider explicitly agrees to show the exact location of their premises.
  final bool showExactLocation;
  final int coverageRadiusMeters;
  final bool availableInEmergency;

  /// Location shown on the phones: exact only with the provider's consent.
  GeoPoint get publicLocation => showExactLocation ? location : location.approximate();
}

/// Filters of the "Servicios cerca" screen.
class ServiceQuery {
  const ServiceQuery({this.categoryId, this.text, this.emergencyOnly = false});

  final String? categoryId;
  final String? text;
  final bool emergencyOnly;

  @override
  bool operator ==(Object other) =>
      other is ServiceQuery &&
      other.categoryId == categoryId &&
      other.text == text &&
      other.emergencyOnly == emergencyOnly;

  @override
  int get hashCode => Object.hash(categoryId, text, emergencyOnly);
}
