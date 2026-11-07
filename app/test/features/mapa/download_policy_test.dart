import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/geo/map_bounds.dart';
import 'package:vecinal/features/mapa/data/connectivity_map_monitor.dart';
import 'package:vecinal/features/mapa/domain/download_policy.dart';
import 'package:vecinal/features/mapa/domain/offline_region.dart';

import 'support/fakes.dart';

void main() {
  test(
    'solo permite Wi-Fi por defecto; la autorización no convierte la falta de red en conexión',
    () {
      for (final connection in MapConnection.values) {
        expect(
          permitsMapDownload(connection, allowMobileData: false),
          connection == MapConnection.wifi,
        );
        expect(
          permitsMapDownload(connection, allowMobileData: true),
          connection == MapConnection.wifi || connection == MapConnection.other,
        );
      }
      expect(canDownload(onWifi: false, allowMobileData: false), isFalse);
    },
  );

  test('clasifica Wi-Fi, datos y desconexión sin confundir VPN con Wi-Fi', () {
    expect(
      classifyMapConnection([ConnectivityResult.wifi, ConnectivityResult.vpn]),
      MapConnection.wifi,
    );
    expect(classifyMapConnection([ConnectivityResult.mobile]), MapConnection.other);
    expect(classifyMapConnection([ConnectivityResult.vpn]), MapConnection.other);
    expect(classifyMapConnection([ConnectivityResult.none]), MapConnection.unavailable);
    expect(classifyMapConnection([]), MapConnection.unavailable);
  });

  test('rechaza límites inválidos y evita claves o protocolos locales en la URL del estilo', () {
    for (final url in [
      'file:///map.json',
      'https://user:secret@example.test/map.json',
      '/style.json',
    ]) {
      expect(() => testRegion(styleUrl: url), throwsArgumentError);
    }
    expect(
      () => MapRegionDefinition(
        id: 'invalid',
        styleUrl: 'https://example.test/map.json',
        bounds: const MapBounds(west: 1, south: 0, east: 0, north: 1),
      ),
      throwsArgumentError,
    );
  });

  test('una configuración diferente no reutiliza la identidad de una descarga anterior', () {
    expect(testRegion().cacheKey, testRegion().cacheKey);
    expect(
      testRegion(styleUrl: 'https://other.example.test/map.json').cacheKey,
      isNot(testRegion().cacheKey),
    );
  });
}
