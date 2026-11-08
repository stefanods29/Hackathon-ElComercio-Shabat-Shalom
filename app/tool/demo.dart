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
          const AppEnvironment(apiBaseUrl: 'http://127.0.0.1:9', powersyncUrl: ''),
        ),
        syncServiceProvider.overrideWith((ref) {
          final sync = FakeSyncService();
          ref.onDispose(sync.close);
          return sync;
        }),
      ],
      child: const VecinalApp(),
    ),
  );
}
