import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vecinal/features/mapa/data/connectivity_map_monitor.dart';
import 'package:vecinal/features/mapa/domain/download_policy.dart';

class _MockConnectivity extends Mock implements Connectivity {}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  test('volver a primer plano comprueba cambios de red no recibidos en segundo plano', () async {
    final connectivity = _MockConnectivity();
    final listening = Completer<void>();
    final changes = StreamController<List<ConnectivityResult>>.broadcast(
      onListen: listening.complete,
    );
    when(() => connectivity.onConnectivityChanged).thenAnswer((_) => changes.stream);
    when(
      () => connectivity.checkConnectivity(),
    ).thenAnswer((_) async => [ConnectivityResult.mobile]);
    final monitor = ConnectivityMapMonitor(connectivity);
    final resumedConnection = Completer<MapConnection>();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final subscription = monitor.watch().listen(resumedConnection.complete);
    try {
      await listening.future;
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(await resumedConnection.future, MapConnection.other);
      verify(() => connectivity.checkConnectivity()).called(1);
    } finally {
      await subscription.cancel();
      await changes.close();
    }
  });
}
