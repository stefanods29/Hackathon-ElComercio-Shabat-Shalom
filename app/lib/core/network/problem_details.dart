/// Standard error returned by the API (RFC 9457), with a stable `codigo`.
class ProblemDetails {
  const ProblemDetails({
    required this.status,
    required this.title,
    required this.code,
    this.type = 'about:blank',
    this.detail,
  });

  /// Reads an `application/problem+json` body; [httpStatus] wins when the body has no `status`.
  /// JSON keys follow the public contract (`codigo` stays in Spanish).
  factory ProblemDetails.fromJson(Map<String, Object?> json, {required int httpStatus}) {
    return ProblemDetails(
      status: switch (json['status']) {
        final int value => value,
        _ => httpStatus,
      },
      title: switch (json['title']) {
        final String value => value,
        _ => 'Error $httpStatus',
      },
      code: switch (json['codigo']) {
        final String value => value,
        _ => 'desconocido',
      },
      type: switch (json['type']) {
        final String value => value,
        _ => 'about:blank',
      },
      detail: switch (json['detail']) {
        final String value => value,
        _ => null,
      },
    );
  }

  final int status;
  final String title;
  final String code;
  final String type;
  final String? detail;

  /// Definitive rejection: retrying the same submission will not change the answer.
  bool get isDefinitiveRejection => isDefinitiveRejectionStatus(status);
}

/// 4xx except 408 (timeout) and 429 (too many requests), the same as on the server.
bool isDefinitiveRejectionStatus(int status) =>
    status >= 400 && status < 500 && status != 408 && status != 429;
