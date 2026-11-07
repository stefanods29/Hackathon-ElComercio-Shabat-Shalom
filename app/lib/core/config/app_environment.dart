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
    this.phoneAuth = 'api',
    this.firebaseApiKey = '',
    this.firebaseAppId = '',
    this.firebaseSenderId = '',
    this.firebaseProjectId = '',
  });

  // Same demonstration rectangle as infra/cdn/district.config.json; not an administrative boundary.
  static const pilotMapBounds = MapBounds(west: -77.07, south: -12.10, east: -77.01, north: -12.06);

  factory AppEnvironment.fromDefines() => const AppEnvironment(
    apiBaseUrl: String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000'),
    powersyncUrl: String.fromEnvironment('POWERSYNC_URL'),
    enablePush: bool.fromEnvironment('ENABLE_PUSH'),
    phoneAuth: String.fromEnvironment('PHONE_AUTH', defaultValue: 'api'),
    firebaseApiKey: String.fromEnvironment('FIREBASE_API_KEY'),
    firebaseAppId: String.fromEnvironment('FIREBASE_APP_ID'),
    firebaseSenderId: String.fromEnvironment('FIREBASE_SENDER_ID'),
    firebaseProjectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
    mapStyleUrl: String.fromEnvironment(
      'MAP_STYLE_URL',
      defaultValue: 'http://10.0.2.2:8090/estilos/vecinal.json',
    ),
  );

  final String apiBaseUrl;

  /// Debug override for reaching the local service from an emulator or another device.
  final String powersyncUrl;
  final String mapStyleUrl;
  final MapBounds mapBounds;
  final bool enablePush;

  /// `firebase`: Firebase Authentication sends the SMS code; `api`: the API sends it.
  final String phoneAuth;

  /// Firebase options by `--dart-define`, so no project file is committed. Empty: Firebase off.
  final String firebaseApiKey;
  final String firebaseAppId;
  final String firebaseSenderId;
  final String firebaseProjectId;

  bool get phoneAuthWithFirebase => phoneAuth == 'firebase';
}
