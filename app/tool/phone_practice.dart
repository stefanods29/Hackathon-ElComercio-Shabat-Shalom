import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vecinal/app.dart';
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/sync/sync_service.dart';

/// Device rehearsal with the existing practice screens and in-memory repositories.
/// No real session, synchronization, Firebase or native protection is replaced here.
Future<void> main() async {
  if (!kDebugMode) throw UnsupportedError('Phone practice is available only in debug builds');
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
