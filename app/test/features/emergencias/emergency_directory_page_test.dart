import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/app.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/router/router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/theme/accessible_theme.dart';
import 'package:vecinal/features/cuenta/data/in_memory_auth_repository.dart';
import 'package:vecinal/features/cuenta/data/providers.dart';
import 'package:vecinal/features/emergencias/data/emergency_directory_repository.dart';
import 'package:vecinal/features/emergencias/data/emergency_directory_store.dart';
import 'package:vecinal/features/emergencias/data/providers.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_directory_page.dart';
import 'package:vecinal/l10n/app_localizations.dart';

void main() {
  late String backupJson;
  late List<RequestOptions> requests;

  setUpAll(() => backupJson = File('assets/emergencia/respaldo.json').readAsStringSync());

  /// A CDN without signal that records any attempt: the page must not depend on the network.
  EmergencyDirectoryRepository offlineRepository({Uint8List? saved}) {
    final cdn = Dio();
    cdn.interceptors.add(
      InterceptorsWrapper(
        onRequest: (request, handler) {
          requests.add(request);
          handler.reject(
            DioException(requestOptions: request, type: DioExceptionType.connectionError),
          );
        },
      ),
    );
    final repository = EmergencyDirectoryRepository(
      cdn: cdn,
      store: InMemoryEmergencyDirectoryStore(directory: saved),
      loadBackup: () async => backupJson,
    );
    addTearDown(() async {
      await repository.close();
      cdn.close(force: true);
    });
    return repository;
  }

  Future<void> pumpPage(
    WidgetTester tester, {
    Uint8List? saved,
    DateTime Function() clock = DateTime.now,
    double textScale = 2,
  }) async {
    // Phone width; tall enough to build every card at 200 % text.
    tester.view.physicalSize = const Size(412, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          emergencyDirectoryRepositoryProvider.overrideWithValue(offlineRepository(saved: saved)),
          clockProvider.overrideWithValue(clock),
        ],
        child: MaterialApp(
          theme: AccessibleTheme.light(),
          locale: const Locale('es'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const EmergencyDirectoryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  setUp(() => requests = []);

  testWidgets('sin red y sin descarga muestra solo el respaldo, con letra al 200 %', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Números nacionales'), findsOneWidget);
    for (final phone in ['116', '105', '106']) {
      expect(find.text(phone), findsOneWidget);
    }
    expect(find.textContaining('Verificado el 07/11/2026.'), findsNWidgets(3));
    expect(
      find.text('Fuente: Policía Nacional del Perú (gob.pe). Verificado el 07/11/2026.'),
      findsOneWidget,
    );
    expect(find.textContaining('Posiblemente desactualizado'), findsNothing);
    expect(requests, isEmpty);
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('un punto de encuentro con verificación antigua sigue visible y se marca', (
    tester,
  ) async {
    final saved = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'version': 3,
          'distrito': 'Lince (demo)',
          'generadoEn': '2026-11-07T12:00:00Z',
          'entradas': [
            {
              'id': 'parque',
              'tipo': 'punto_de_encuentro',
              'nombre': 'Parque de prueba',
              'ubicacion': {'lat': -12.085, 'lng': -77.035},
              'direccion': 'Av. de prueba 123',
              'fuente': {'nombre': 'Municipalidad de prueba'},
              'verificadoEn': '2026-11-07',
            },
            {
              'id': 'bomberos',
              'tipo': 'numero',
              'nombre': 'Bomberos',
              'telefono': '116',
              'fuente': {'nombre': 'MTC'},
              'verificadoEn': '2026-11-07',
            },
          ],
        }),
      ),
    );
    await pumpPage(tester, saved: saved, clock: () => DateTime.utc(2026, 12, 22, 15));

    expect(find.text('Lince (demo)'), findsOneWidget);
    expect(find.text('Parque de prueba'), findsOneWidget);
    expect(find.text('Punto de encuentro'), findsOneWidget);
    expect(find.text('Fuente: Municipalidad de prueba. Verificado el 07/11/2026.'), findsOneWidget);
    expect(
      find.text('Posiblemente desactualizado: su última verificación es antigua.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('el muro abre el directorio y el directorio se abre sin sesión', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [emergencyDirectoryRepositoryProvider.overrideWithValue(offlineRepository())],
        child: const VecinalApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Números y lugares de emergencia'));
    await tester.pumpAndSettle();
    expect(find.byType(EmergencyDirectoryPage), findsOneWidget);
    expect(find.text('116'), findsOneWidget);

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(InMemoryAuthRepository(startSignedOut: true)),
        emergencyDirectoryRepositoryProvider.overrideWithValue(offlineRepository()),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const VecinalApp()),
    );
    await tester.pumpAndSettle();
    container.read(routerProvider).go(Routes.emergency);
    await tester.pumpAndSettle();
    expect(find.byType(EmergencyDirectoryPage), findsOneWidget);
    expect(requests, isEmpty);
  });
}
