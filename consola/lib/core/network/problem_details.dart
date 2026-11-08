/// Standard error returned by the API (RFC 9457), with a stable `codigo`.
class ProblemDetails {
  const ProblemDetails({
    required this.status,
    required this.title,
    required this.code,
    this.detail,
    this.fieldErrors = const [],
    this.retryAfterSeconds,
  });

  /// Reads an `application/problem+json` body; [status] wins when the body has no `status`.
  /// JSON keys follow the public contract (`codigo`, `errores` stay in Spanish).
  factory ProblemDetails.fromResponse(int status, Object? body, {String? retryAfterHeader}) {
    final json = body is Map ? Map<String, Object?>.from(body) : const <String, Object?>{};
    final retryAfter = switch (json['reintentarEnSegundos']) {
      final num value => value.ceil(),
      _ => int.tryParse(retryAfterHeader ?? ''),
    };
    return ProblemDetails(
      status: switch (json['status']) {
        final int value => value,
        _ => status,
      },
      title: switch (json['title']) {
        final String value => value,
        _ => 'Error $status',
      },
      code: switch (json['codigo']) {
        final String value => value,
        _ => 'desconocido',
      },
      detail: switch (json['detail']) {
        final String value => value,
        _ => null,
      },
      fieldErrors: switch (json['errores']) {
        final List<Object?> rows => [
          for (final row in rows)
            if (row case {'campo': final String field, 'mensaje': final String message})
              FieldError(field, message),
        ],
        _ => const [],
      },
      retryAfterSeconds: retryAfter,
    );
  }

  final int status;
  final String title;
  final String code;
  final String? detail;
  final List<FieldError> fieldErrors;
  final int? retryAfterSeconds;
}

/// A field the API rejected: `campo` is a dotted path such as `entradas.3.telefono`.
class FieldError {
  const FieldError(this.field, this.message);

  final String field;
  final String message;
}
