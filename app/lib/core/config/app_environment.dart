import 'package:vecinal/core/geo/map_bounds.dart';

/// Per-environment configuration, injected at build time with `--dart-define`.
///
/// Example: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000`.
/// Defaults point to the Android emulator with the local infrastructure (`infra/`).
class AppEnvironment {
  const AppEnvironment({
    required this.apiBaseUrl,
    required this.powersyncUrl,
    this.mapStyleUrl = 'http://10.0.2.2:8090/estilos/vecinal.json',
    this.mapBounds = pilotMapBounds,
    this.enablePush = false,
    this.enablePhotos = false,
    this.mediaStorageOrigin = 'http://10.0.2.2:9000',
    this.publicAppUrl = '',
    this.sentryDsn = '',
    this.environmentName = 'dev',
  });

  // Same demonstration rectangle as infra/cdn/district.config.json; not an administrative boundary.
  static const pilotMapBounds = MapBounds(west: -77.07, south: -12.10, east: -77.01, north: -12.06);

  factory AppEnvironment.fromDefines() => const AppEnvironment(
    apiBaseUrl: String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000'),
    powersyncUrl: String.fromEnvironment('POWERSYNC_URL', defaultValue: 'http://10.0.2.2:8080'),
    enablePush: bool.fromEnvironment('ENABLE_PUSH'),
    enablePhotos: bool.fromEnvironment('ENABLE_PHOTOS'),
    mediaStorageOrigin: String.fromEnvironment(
      'MEDIA_STORAGE_ORIGIN',
      defaultValue: 'http://10.0.2.2:9000',
    ),
    publicAppUrl: String.fromEnvironment('PUBLIC_APP_URL'),
    sentryDsn: String.fromEnvironment('SENTRY_DSN'),
    environmentName: String.fromEnvironment('APP_ENVIRONMENT', defaultValue: 'dev'),
    mapStyleUrl: String.fromEnvironment(
      'MAP_STYLE_URL',
      defaultValue: 'http://10.0.2.2:8090/estilos/vecinal.json',
    ),
  );

  final String apiBaseUrl;
  final String powersyncUrl;
  final String mapStyleUrl;
  final MapBounds mapBounds;
  final bool enablePush;
  final bool enablePhotos;
  final String mediaStorageOrigin;
  final String publicAppUrl;
  final String sentryDsn;
  final String environmentName;
}
