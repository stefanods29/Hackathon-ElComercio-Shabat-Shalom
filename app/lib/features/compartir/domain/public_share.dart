import 'package:vecinal/core/submissions/submission_status.dart';

enum PublicShareFailure { notSent, unavailable, invalidId }

class PublicShareException implements Exception {
  const PublicShareException(this.reason);
  final PublicShareFailure reason;
}

/// A share contains only a public deep link. Titles, contacts and exact locations stay in the app.
String publicPostLink({
  required String postId,
  required SubmissionStatus status,
  required String publicBaseUrl,
}) {
  if (status != SubmissionStatus.sent) throw const PublicShareException(PublicShareFailure.notSent);
  if (!RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  ).hasMatch(postId)) {
    throw const PublicShareException(PublicShareFailure.invalidId);
  }
  final base = Uri.tryParse(publicBaseUrl);
  if (base == null ||
      base.scheme != 'https' ||
      base.host.isEmpty ||
      base.userInfo.isNotEmpty ||
      base.hasQuery ||
      base.hasFragment ||
      (base.path.isNotEmpty && base.path != '/')) {
    throw const PublicShareException(PublicShareFailure.unavailable);
  }
  return base.replace(pathSegments: ['publicaciones', postId]).toString();
}
