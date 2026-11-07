import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:vecinal/features/mapa/domain/download_policy.dart';

class ConnectivityMapMonitor implements MapConnectionMonitor {
  ConnectivityMapMonitor(this._connectivity);
  final Connectivity _connectivity;

  @override
  Future<MapConnection> current() async {
    try {
      return classifyMapConnection(await _connectivity.checkConnectivity());
    } on PlatformException {
      return MapConnection.unknown;
    } on MissingPluginException {
      return MapConnection.unknown;
    }
  }

  @override
  Stream<MapConnection> watch() => Stream.multi((listener) {
    var active = true;
    final subscription = _connectivity.onConnectivityChanged
        .map(classifyMapConnection)
        .distinct()
        .listen(listener.add, onError: listener.addError);
    // Android may not report a change while the app is suspended. Recheck on resume,
    // including when the user left the map screen with a download still running.
    final lifecycle = AppLifecycleListener(
      onResume: () {
        unawaited(
          current().then((connection) {
            if (active) listener.add(connection);
          }),
        );
      },
    );
    listener.onCancel = () async {
      active = false;
      lifecycle.dispose();
      await subscription.cancel();
    };
  });
}

MapConnection classifyMapConnection(List<ConnectivityResult> connections) {
  if (connections.contains(ConnectivityResult.wifi)) return MapConnection.wifi;
  if (connections.isEmpty ||
      connections.every((connection) => connection == ConnectivityResult.none)) {
    return MapConnection.unavailable;
  }
  return MapConnection.other;
}
