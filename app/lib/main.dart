import 'dart:async';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry/sentry.dart';
import 'package:vecinal/app.dart';
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/observability/private_telemetry.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final environment = AppEnvironment.fromDefines();
  if (environment.sentryDsn.isEmpty) {
    runApp(const ProviderScope(child: VecinalApp()));
    return;
  }
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
  // Keep Flutter's binding and runApp in the same zone. Report sanitized Dart errors only.
  FlutterError.onError = (details) => unawaited(reportAppFailure(details.exception));
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(reportAppFailure(error));
    return true;
  };
  runApp(const ProviderScope(child: VecinalApp()));
}
