import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Per-environment configuration, injected at build time with `--dart-define`.
///
/// Example: `flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000`.
/// Nothing here is secret: the build is a public static site.
class ConsoleEnvironment {
  const ConsoleEnvironment({
    required this.apiBaseUrl,
    this.name = 'local',
    this.mapStyleUrl = 'http://localhost:8090/estilos/vecinal.json',
    this.phoneAuth = 'api',
    this.firebaseApiKey = '',
    this.firebaseAppId = '',
    this.firebaseSenderId = '',
    this.firebaseProjectId = '',
    this.firebaseAuthDomain = '',
    this.inactivity = const Duration(minutes: 10),
    this.demoData = false,
    this.mapBounds = pilotBounds,
    this.mapMinZoom = 12,
    this.mapMaxZoom = 17,
  });

  factory ConsoleEnvironment.fromDefines() {
    const name = String.fromEnvironment('CONSOLE_ENV', defaultValue: 'local');
    const minutes = int.fromEnvironment('INACTIVITY_MINUTES', defaultValue: 10);
    return ConsoleEnvironment(
      name: name,
      apiBaseUrl: const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:3000',
      ),
      mapStyleUrl: const String.fromEnvironment(
        'MAP_STYLE_URL',
        defaultValue: 'http://localhost:8090/estilos/vecinal.json',
      ),
      phoneAuth: const String.fromEnvironment('PHONE_AUTH', defaultValue: 'api'),
      firebaseApiKey: const String.fromEnvironment('FIREBASE_API_KEY'),
      firebaseAppId: const String.fromEnvironment('FIREBASE_APP_ID'),
      firebaseSenderId: const String.fromEnvironment('FIREBASE_SENDER_ID'),
      firebaseProjectId: const String.fromEnvironment('FIREBASE_PROJECT_ID'),
      firebaseAuthDomain: const String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
      // Between 2 and 30 minutes: shorter blocks the work, longer leaves an open desk behind.
      inactivity: Duration(minutes: minutes < 2 ? 2 : (minutes > 30 ? 30 : minutes)),
      // Seeded data never reaches production, even with a wrong define.
      demoData: name != 'produccion' && const String.fromEnvironment('CONSOLE_DATA') == 'demo',
    );
  }

  /// `local`, `staging` or `produccion`.
  final String name;
  final String apiBaseUrl;
  final String mapStyleUrl;

  /// `firebase`: Firebase Authentication sends the SMS code; `api`: the API sends it.
  final String phoneAuth;

  /// Firebase web options by `--dart-define`, so no project file is committed.
  final String firebaseApiKey;
  final String firebaseAppId;
  final String firebaseSenderId;
  final String firebaseProjectId;
  final String firebaseAuthDomain;

  /// Time without keyboard or pointer activity before the console signs out.
  final Duration inactivity;

  /// `CONSOLE_DATA=demo`: every port uses seeded doubles and a fixed strip says so.
  final bool demoData;

  /// Area the cells map may show; the camera cannot leave it.
  final MapRect mapBounds;
  final double mapMinZoom;
  final double mapMaxZoom;

  bool get phoneAuthWithFirebase => phoneAuth == 'firebase';

  // Same demonstration rectangle as infra/cdn/district.config.json and the app; not an
  // administrative boundary.
  static const pilotSouth = -12.10;
  static const pilotWest = -77.07;
  static const pilotNorth = -12.06;
  static const pilotEast = -77.01;
  static const pilotBounds = MapRect(
    south: pilotSouth,
    west: pilotWest,
    north: pilotNorth,
    east: pilotEast,
  );
}

/// A latitude and longitude rectangle.
class MapRect {
  const MapRect({required this.south, required this.west, required this.north, required this.east});

  final double south;
  final double west;
  final double north;
  final double east;

  double get centerLatitude => (south + north) / 2;

  double get centerLongitude => (west + east) / 2;
}

/// Overridden in `main.dart` with [ConsoleEnvironment.fromDefines].
final consoleEnvironmentProvider = Provider<ConsoleEnvironment>(
  (ref) => throw UnimplementedError('consoleEnvironmentProvider se configura en main.dart'),
);

/// Whether the screens show seeded data instead of the API.
final demoDataProvider = Provider<bool>((ref) => ref.watch(consoleEnvironmentProvider).demoData);
