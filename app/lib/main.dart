import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vecinal/authenticated_app.dart';
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/dev_sync_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = (await getApplicationSupportDirectory()).path;
  final environment = AppEnvironment.fromDefines();
  const store = SystemSecureStore();
  runApp(
    kDebugMode && const bool.fromEnvironment('DEV_SYNC')
        ? DevSyncApp(environment: environment, directory: directory, store: store)
        : AuthenticatedApp(environment: environment, directory: directory, store: store),
  );
}
