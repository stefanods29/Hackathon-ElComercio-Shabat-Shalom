import 'package:firebase_core/firebase_core.dart';
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
  if (environment.phoneAuthWithFirebase) {
    try {
      await Firebase.initializeApp(options: _firebaseOptions(environment));
    } on Object catch (error) {
      // The app still opens; signing in then shows that the code could not be sent.
      debugPrint('Firebase no inició: ${error.runtimeType}');
    }
  }
  const store = SystemSecureStore();
  runApp(
    kDebugMode && const bool.fromEnvironment('DEV_SYNC')
        ? DevSyncApp(environment: environment, directory: directory, store: store)
        : AuthenticatedApp(environment: environment, directory: directory, store: store),
  );
}

/// Firebase options by `--dart-define`; without them Firebase reads the native project files.
FirebaseOptions? _firebaseOptions(AppEnvironment environment) {
  if (environment.firebaseAppId.isEmpty) return null;
  return FirebaseOptions(
    apiKey: environment.firebaseApiKey,
    appId: environment.firebaseAppId,
    messagingSenderId: environment.firebaseSenderId,
    projectId: environment.firebaseProjectId,
  );
}
