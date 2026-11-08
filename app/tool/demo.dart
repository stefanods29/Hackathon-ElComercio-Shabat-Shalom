import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vecinal/app.dart';
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/sync/sync_service.dart';

/// Demo variant: the app in practice mode, with fictitious data in memory and no server, account,
/// OTP, Firebase or synchronization. Unlike `phone_practice.dart` it also runs in release builds,
/// so it opens from the phone's icon. It is built only on purpose (`-t tool/demo.dart`), never as
/// the published app, and nothing it does reaches a real neighbor.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  await preferences.setBool('practiceMode', true);
  runApp(
    ProviderScope(
      overrides: [
        environmentProvider.overrideWithValue(
          const AppEnvironment(
            apiBaseUrl: 'http://127.0.0.1:9',
            powersyncUrl: '',
            // Public style without a key, so the map shows streets on a phone with internet.
            mapStyleUrl: 'https://tiles.openfreemap.org/styles/liberty',
            // Photos stay encrypted on the phone: without a session there is no upload.
            enablePhotos: true,
          ),
        ),
        syncServiceProvider.overrideWith((ref) {
          // Practice data lives in memory, so the demo shows it as up to date.
          final sync = FakeSyncService(SyncStatus(connected: true, lastSyncedAt: DateTime.now()));
          ref.onDispose(sync.close);
          return sync;
        }),
      ],
      child: const VecinalApp(),
    ),
  );
}
