import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as native;
import 'package:vecinal/features/directorio/domain/directory.dart';
import 'package:vecinal/features/mapa/domain/offline_region.dart';

class MapMarker {
  const MapMarker({required this.label, required this.location, this.detail});
  final String label;
  final GeoPoint location;
  final String? detail;
}

class MapFocus {
  const MapFocus(this.markers);
  final List<MapMarker> markers;
}

/// Keeps the original injectable map builder signature compatible.
class MapFocusScope extends InheritedWidget {
  const MapFocusScope({super.key, required this.focus, required super.child});
  final MapFocus? focus;
  static MapFocus? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MapFocusScope>()?.focus;
  @override
  bool updateShouldNotify(MapFocusScope oldWidget) => oldWidget.focus != focus;
}

typedef MapViewBuilder = Widget Function(BuildContext context, MapRegionDefinition definition);

final mapViewBuilderProvider = Provider<MapViewBuilder>((ref) => buildMapLibreView);

Widget buildMapLibreView(BuildContext context, MapRegionDefinition definition) =>
    _FocusedMap(definition: definition, focus: MapFocusScope.of(context));

class _FocusedMap extends StatefulWidget {
  const _FocusedMap({required this.definition, this.focus});
  final MapRegionDefinition definition;
  final MapFocus? focus;
  @override
  State<_FocusedMap> createState() => _FocusedMapState();
}

class _FocusedMapState extends State<_FocusedMap> {
  native.MapLibreMapController? _controller;
  @override
  Widget build(BuildContext context) {
    final definition = widget.definition;
    final point = widget.focus?.markers.firstOrNull?.location;
    return native.MapLibreMap(
      key: ValueKey(definition.cacheKey),
      styleString: definition.styleUrl,
      initialCameraPosition: native.CameraPosition(
        target: native.LatLng(
          point?.lat ?? definition.bounds.centerLatitude,
          point?.lng ?? definition.bounds.centerLongitude,
        ),
        zoom: 13,
      ),
      cameraTargetBounds: native.CameraTargetBounds(
        native.LatLngBounds(
          southwest: native.LatLng(definition.bounds.south, definition.bounds.west),
          northeast: native.LatLng(definition.bounds.north, definition.bounds.east),
        ),
      ),
      minMaxZoomPreference: native.MinMaxZoomPreference(definition.minZoom, definition.maxZoom),
      // Panning the map must not scroll its enclosing download page instead.
      gestureRecognizers: const {Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new)},
      myLocationEnabled: false,
      // The native information control retains clickable data licences; the page also shows
      // a permanently visible, scalable text attribution outside the platform view.
      attributionEnabled: true,
      onMapCreated: (controller) => _controller = controller,
      onStyleLoadedCallback: () async {
        final controller = _controller;
        if (controller == null) return;
        for (final marker in widget.focus?.markers ?? <MapMarker>[]) {
          await controller.addCircle(
            native.CircleOptions(
              geometry: native.LatLng(marker.location.lat, marker.location.lng),
              circleRadius: 10,
              circleColor: '#005A45',
              circleStrokeColor: '#FFFFFF',
              circleStrokeWidth: 3,
            ),
          );
        }
      },
    );
  }
}
