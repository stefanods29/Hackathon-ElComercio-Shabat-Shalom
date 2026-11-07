import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vecinal/authenticated_app.dart';
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/router/router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/features/cuenta/data/http_auth_repository.dart';
import 'package:vecinal/features/cuenta/presentation/code_page.dart';
import 'package:vecinal/features/cuenta/presentation/phone_page.dart';
import 'package:vecinal/features/solidaridad/data/powersync_post_repository.dart';
import 'package:vecinal/features/solidaridad/data/providers.dart';
import 'package:vecinal/features/solidaridad/presentation/wall_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('OTP real → muro cifrado → restaurar sin API → publicar → purga desde Mi cuenta', (
    tester,
  ) async {
    const otp = String.fromEnvironment('TEST_OTP');
    expect(
      otp,
      matches(RegExp(r'^\d{6}$')),
      reason: 'Solicitar un OTP fake nuevo antes de ejecutar.',
    );
    final directory = await (await getTemporaryDirectory()).createTemp('auth-flow-');
    final store = _TestStore('test.auth-flow.${DateTime.now().microsecondsSinceEpoch}.');
    addTearDown(() async {
      await store.deleteAll();
      await directory.delete(recursive: true);
    });
    final prefs = await SharedPreferences.getInstance();
    final previousPractice = prefs.getBool('practiceMode');
    await prefs.setBool('practiceMode', false);
    addTearDown(() async {
      if (previousPractice == null) {
        await prefs.remove('practiceMode');
      } else {
        await prefs.setBool('practiceMode', previousPractice);
      }
    });

    Widget app(AppEnvironment environment) =>
        AuthenticatedApp(environment: environment, directory: directory.path, store: store);
    await tester.pumpWidget(
      app(
        const AppEnvironment(
          apiBaseUrl: 'http://127.0.0.1:3000',
          powersyncUrl: 'http://127.0.0.1:8080',
        ),
      ),
    );
    await _wait(tester, find.byType(PhonePage));
    final login = ProviderScope.containerOf(tester.element(find.byType(PhonePage)));
    login
        .read(routerProvider)
        .go(Routes.signInCode, extra: const CodeArguments('+51900000002', retryAfterSeconds: 30));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), otp);
    await tester.tap(find.text('Verificar código'));
    await _wait(tester, find.byType(WallPage));
    final live = ProviderScope.containerOf(tester.element(find.byType(WallPage)));
    expect(live.read(syncedPostRepositoryProvider), isA<PowerSyncPostRepository>());
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (live.read(syncStatusProvider).value?.lastSyncedAt == null) {
      if (DateTime.now().isAfter(deadline)) fail('No llegó la sincronización inicial.');
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(await store.read(HttpAuthRepository.sessionKey), isNotNull);
    final wall = await live.read(postRepositoryProvider).watchWall().first;
    expect(wall, isNotEmpty);
    final cachedTitle = wall.first.title;
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 2));

    // Simulates an unavailable API while retaining real encrypted files and KeyStore entries.
    await tester.pumpWidget(
      app(const AppEnvironment(apiBaseUrl: 'http://127.0.0.1:1', powersyncUrl: '')),
    );
    await _wait(tester, find.byType(WallPage));
    await _wait(tester, find.text(cachedTitle));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'OFREZCO').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Prueba sintética de sesión offline');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final publish = find.widgetWithText(FilledButton, 'Publicar');
    await tester.ensureVisible(publish);
    await tester.tap(publish);
    await _wait(tester, find.byType(WallPage));
    await _wait(tester, find.text('Prueba sintética de sesión offline'));
    await _wait(tester, find.text('Guardado en tu celular').first);
    expect(find.textContaining('Guardado en tu celular'), findsWidgets);
    await tester.tap(find.byTooltip('Mi cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cerrar sesión').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Confirmar'));
    await _wait(tester, find.byType(PhonePage));
    // The redirect can precede the end of deleting the databases.
    final purgeDeadline = DateTime.now().add(const Duration(seconds: 30));
    while (await store.read(HttpAuthRepository.purgeKey) != null) {
      if (DateTime.now().isAfter(purgeDeadline)) fail('La purga no terminó.');
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(await store.read(HttpAuthRepository.sessionKey), isNull);
    expect(await directory.list().toList(), isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}

Future<void> _wait(WidgetTester tester, Finder finder) async {
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(deadline)) fail('No apareció $finder');
    await tester.pump(const Duration(milliseconds: 200));
  }
  await tester.pump(const Duration(milliseconds: 300));
}

/// Uses the platform's secure storage without overwriting the installed user's session.
class _TestStore implements SecureStore {
  _TestStore(this.prefix);
  final String prefix;
  final _delegate = const SystemSecureStore();
  final _keys = <String>{};
  @override
  Future<String?> read(String key) => _delegate.read('$prefix$key');
  @override
  Future<void> write(String key, String value) async {
    _keys.add(key);
    await _delegate.write('$prefix$key', value);
  }

  @override
  Future<void> delete(String key) => _delegate.delete('$prefix$key');
  @override
  Future<void> deleteAll() async {
    for (final key in _keys) {
      await delete(key);
    }
  }
}
