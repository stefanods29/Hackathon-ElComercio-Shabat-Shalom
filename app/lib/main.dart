import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry/sentry.dart';
import 'package:vecinal/authenticated_app.dart';
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/observability/private_telemetry.dart';
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
  if (environment.sentryDsn.isNotEmpty) await _startErrorReporting(environment);
  const store = SystemSecureStore();
  runApp(
    kDebugMode && const bool.fromEnvironment('DEV_SYNC')
        ? DevSyncApp(environment: environment, directory: directory, store: store)
        : AuthenticatedApp(environment: environment, directory: directory, store: store),
  );
}

/// Sanitized error reports only (Lot C, part 5): no PII, breadcrumbs or traces.
Future<void> _startErrorReporting(AppEnvironment environment) async {
  await Sentry.init((options) {
    options.dsn = environment.sentryDsn;
    options.environment = environment.environmentName;
    options.sendDefaultPii = false;
    options.maxBreadcrumbs = 0;
    options.tracesSampleRate = 0;
    options.debug = false;
    options.enableDartSymbolication = false;
    options.beforeSend = (event, hint) => privateAppEvent(event);
    options.beforeSendTransaction = (_, _) => null;
  });
  FlutterError.onError = (details) => unawaited(reportAppFailure(details.exception));
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(reportAppFailure(error));
    return true;
  };
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
