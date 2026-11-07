enum MapConnection { wifi, other, unavailable, unknown }

bool canDownload({required bool onWifi, required bool allowMobileData}) =>
    onWifi || allowMobileData;

bool permitsMapDownload(MapConnection connection, {required bool allowMobileData}) =>
    connection != MapConnection.unavailable &&
    connection != MapConnection.unknown &&
    canDownload(onWifi: connection == MapConnection.wifi, allowMobileData: allowMobileData);

/// Connection type is a download policy signal, not a guarantee of internet access.
abstract interface class MapConnectionMonitor {
  Future<MapConnection> current();
  Stream<MapConnection> watch();
}
