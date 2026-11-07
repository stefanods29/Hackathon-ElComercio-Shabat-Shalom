import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as native;
import 'package:vecinal/features/mapa/domain/offline_region.dart';

typedef MapViewBuilder = Widget Function(BuildContext context, MapRegionDefinition definition);

final mapViewBuilderProvider = Provider<MapViewBuilder>((ref) => buildMapLibreView);

Widget buildMapLibreView(BuildContext context, MapRegionDefinition definition) =>
    native.MapLibreMap(
      key: ValueKey(definition.cacheKey),
      styleString: definition.styleUrl,
      initialCameraPosition: native.CameraPosition(
        target: native.LatLng(definition.bounds.centerLatitude, definition.bounds.centerLongitude),
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
    );
