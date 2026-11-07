import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:vecinal/app.dart';
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/network/api_client.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/sync/dev_sync_session.dart';
import 'package:vecinal/core/sync/local_sync_database.dart';
import 'package:vecinal/core/sync/powersync_sync_service.dart';
import 'package:vecinal/core/sync/vecinal_connector.dart';
import 'package:vecinal/features/emergencias/assigned_case_cache.dart';
import 'package:vecinal/features/emergencias/assigned_case_provider.dart';
import 'package:vecinal/features/solidaridad/data/powersync_post_repository.dart';
import 'package:vecinal/features/solidaridad/data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode || !const bool.fromEnvironment('DEV_SYNC')) {
    runApp(const ProviderScope(child: VecinalApp()));
    return;
  }

  final environment = AppEnvironment.fromDefines();
  final directory = await getApplicationSupportDirectory();
  const store = SystemSecureStore();
  final local = await LocalSyncDatabase.open(
    path: path.join(directory.path, 'vecinal-demo.db'),
    store: store,
    accountId: LocalSession.demo.neighborId,
  );
  final session = DevSyncSession(createApiClient(environment, getToken: () async => null));
  final api = createApiClient(environment, getToken: session.getToken);
  late final PowerSyncSyncService sync;
  late final AssignedCaseCache cases;
  final connector = VecinalConnector(
    api,
    endpointOverride: environment.powersyncUrl.isEmpty ? null : environment.powersyncUrl,
    onSessionRevoked: () {
      // Let the credentials request return before stopping its PowerSync connection.
      unawaited(
        Future<void>(() async {
          try {
            await Future.wait([sync.disconnectAndWipeLocalData(), cases.wipeForSignOut()]);
          } catch (error, stack) {
            FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
          }
        }),
      );
    },
  );
  sync = PowerSyncSyncService(local, connector);
  cases = AssignedCaseCache(
    path: path.join(directory.path, 'vecinal-demo-cases.db'),
    store: store,
    accountId: LocalSession.demo.neighborId,
    connector: connector,
    clock: DateTime.now,
  );
  await sync.connect();
  await cases.restore();
  AppLifecycleListener(
    onResume: () {
      unawaited(
        cases.review().catchError((Object error, StackTrace stack) {
          FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
        }),
      );
    },
  );
  final posts = PowerSyncPostRepository(
    local.database,
    neighborId: LocalSession.demo.neighborId,
    zoneId: LocalSession.demo.zoneId,
  );
  runApp(
    ProviderScope(
      overrides: [
        syncServiceProvider.overrideWithValue(sync),
        postRepositoryProvider.overrideWithValue(posts),
        assignedCaseCacheProvider.overrideWithValue(cases),
      ],
      child: const VecinalApp(),
    ),
  );
}
