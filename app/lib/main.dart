import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vecinal/app.dart';
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/dev_sync_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode || !const bool.fromEnvironment('DEV_SYNC')) {
    runApp(const ProviderScope(child: VecinalApp()));
    return;
  }

  runApp(
    DevSyncApp(
      environment: AppEnvironment.fromDefines(),
      directory: (await getApplicationSupportDirectory()).path,
      store: const SystemSecureStore(),
    ),
  );
}
