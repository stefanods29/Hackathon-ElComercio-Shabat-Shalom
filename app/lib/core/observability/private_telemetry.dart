import 'package:sentry/sentry.dart';

const _knownErrors = {
  'StateError',
  'TypeError',
  'FormatException',
  'PlatformException',
  'SocketException',
  'PhotoFailure',
  'DioException',
};

/// Rebuild from an allowlist. Private messages, request data and SDK context cannot pass.
SentryEvent privateAppEvent(SentryEvent event) {
  final type = event.exceptions?.firstOrNull?.type;
  return SentryEvent(
    eventId: event.eventId,
    timestamp: event.timestamp,
    level: SentryLevel.error,
    message: SentryMessage('Error técnico de Wiki'),
    tags: const {'component': 'app'},
    exceptions: [
      SentryException(
        type: _knownErrors.contains(type) ? type : 'ApplicationError',
        value: 'Detalle omitido por privacidad',
      ),
    ],
  );
}

Future<void> reportAppFailure(Object error) async {
  try {
    await Sentry.captureEvent(
      privateAppEvent(
        SentryEvent(
          exceptions: [
            SentryException(
              type: error.runtimeType.toString(),
              value: 'Detalle omitido por privacidad',
            ),
          ],
        ),
      ),
    );
  } catch (_) {
    // Monitoring failures must not trigger another unhandled application error.
  }
}
