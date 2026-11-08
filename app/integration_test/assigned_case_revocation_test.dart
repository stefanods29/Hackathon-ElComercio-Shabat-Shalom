import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/network/api_client.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/sync/local_sync_database.dart';
import 'package:vecinal/core/sync/vecinal_connector.dart';
import 'package:vecinal/features/emergencias/assigned_case_cache.dart';
import 'package:vecinal/features/emergencias/data/http_assigned_case_access.dart';

class OfflineConnector extends PowerSyncBackendConnector {
  int requests = 0;

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    requests++;
    return null;
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const caseId = String.fromEnvironment('TEST_ASSIGNED_CASE_ID');
  const otp = String.fromEnvironment('TEST_OTP');

  testWidgets(
    'en Android se borra el caso de prueba al vencer sin señal y al reasignarlo',
    (_) async {
      final environment = AppEnvironment.fromDefines();
      final publicApi = createApiClient(environment, getToken: () async => null);
      addTearDown(publicApi.close);
      final login = await publicApi.post<Map<String, Object?>>(
        '/v1/auth/otp/verificar',
        data: {'telefono': '+51900000003', 'codigo': otp, 'dispositivo': 'prueba de asignación'},
      );
      expect(login.statusCode, 200);
      final token = login.data!['tokenDeAcceso'] as String;
      final api = createApiClient(environment, getToken: () async => token);
      addTearDown(api.close);
      final connector = VecinalConnector(
        api,
        endpointOverride: environment.powersyncUrl.isEmpty ? null : environment.powersyncUrl,
      );
      final root = await getTemporaryDirectory();
      final directory = await root.createTemp('vecinal-cases-android-');
      final dbPath = path.join(directory.path, 'assigned.db');
      const store = SystemSecureStore();
      final account = 'android-test-$caseId';
      final key = 'powersync.database.cases.$account';
      addTearDown(() async {
        await LocalSyncDatabase.discard(path: dbPath, store: store, accountId: 'cases.$account');
        await directory.delete(recursive: true);
      });

      AssignedCaseCache newCache(PowerSyncBackendConnector source, DateTime Function() clock) {
        final cache = AssignedCaseCache(
          path: dbPath,
          store: store,
          accountId: account,
          connector: source,
          clock: clock,
          authorize: HttpAssignedCaseAccess(api).open,
        );
        addTearDown(cache.close);
        return cache;
      }

      Future<AssignedCase> receive(AssignedCaseCache cache) async {
        await cache.request(caseId);
        final received = await cache
            .watch()
            .firstWhere((value) => value != null)
            .timeout(const Duration(seconds: 45));
        expect(received!.id, caseId);
        expect(received.cell, isNotEmpty);
        expect(received.location, isNull);
        await cache.requestExact(caseId);
        final exact = await cache
            .watch()
            .firstWhere((value) => value?.location != null)
            .timeout(const Duration(seconds: 45));
        expect(exact!.location!.description, 'Detalle sintético para prueba Android');
        expect(await File(dbPath).exists(), isTrue);
        expect(await store.read(key), isNotNull);
        return received;
      }

      final initial = newCache(connector, DateTime.now);
      final received = await receive(initial);
      await initial.close();
      final disconnected = OfflineConnector();
      final expired = newCache(disconnected, () => received.expiresAt);
      await expired.restore();
      expect(await expired.watch().first, isNull);
      expect(await File(dbPath).exists(), isFalse);
      expect(await store.read(key), isNull);
      expect(disconnected.requests, 0);
      await expired.close();
      debugPrint('VECINAL_TEST_CASE_EXPIRED');

      final current = newCache(connector, DateTime.now);
      await receive(current);
      final removed = current.watch().firstWhere((value) => value == null);
      debugPrint('VECINAL_TEST_CASE_READY');
      await removed.timeout(const Duration(seconds: 80));
      await current.review();
      expect(await File(dbPath).exists(), isFalse);
      expect(await store.read(key), isNull);
    },
    skip: caseId.isEmpty || otp.isEmpty,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
