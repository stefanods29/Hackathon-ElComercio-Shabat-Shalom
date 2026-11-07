/// Per-environment configuration, injected at build time with `--dart-define`.
///
/// Example: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000`.
/// Defaults point to the Android emulator with the local infrastructure (`infra/`).
class AppEnvironment {
  const AppEnvironment({required this.apiBaseUrl, required this.powersyncUrl});

  factory AppEnvironment.fromDefines() => const AppEnvironment(
    apiBaseUrl: String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000'),
    powersyncUrl: String.fromEnvironment('POWERSYNC_URL'),
  );

  final String apiBaseUrl;

  /// Debug override for reaching the local service from an emulator or another device.
  final String powersyncUrl;
}
