import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as native;
import 'package:vecinal_consola/core/config/console_environment.dart';
import 'package:vecinal_consola/features/casos/domain/emergency_case.dart';
import 'package:vecinal_consola/features/celdas/domain/cells.dart';

/// Colors of each level, from light to dark; the legend and the table carry the same information
/// in text, so color is never the only signal.
const cellLevelColors = <CellLevel, Color>{
  CellLevel.belowThreshold: Color(0xFFDCE6F5),
  CellLevel.low: Color(0xFF9DBCE8),
  CellLevel.medium: Color(0xFF4F86CF),
  CellLevel.high: Color(0xFF0B4F8F),
};

String _hex(Color color) =>
    '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

/// MapLibre GL map of the cells: filled polygons by level, never points of people. It is left out
/// of the keyboard order and of the semantics tree; the table below is the accessible equivalent.
class CellsMap extends ConsumerStatefulWidget {
  const CellsMap({super.key, required this.cells, required this.need, required this.label});

  final List<CellAggregate> cells;
  final EmergencyNeed? need;

  /// Read by screen readers instead of the map itself.
  final String label;

  @override
  ConsumerState<CellsMap> createState() => _CellsMapState();
}

class _CellsMapState extends ConsumerState<CellsMap> {
  static const _source = 'celdas';
  static const _fill = 'celdas-relleno';
  static const _line = 'celdas-borde';

  native.MapLibreMapController? _controller;
  bool _styleReady = false;
  bool _layersAdded = false;
  Future<void> _drawing = Future.value();

  @override
  void didUpdateWidget(CellsMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cells != widget.cells || oldWidget.need != widget.need) _scheduleDraw();
  }

  /// One drawing at a time: the source must exist before it is updated.
  void _scheduleDraw() {
    _drawing = _drawing.then((_) => _draw()).catchError((Object error) {
      debugPrint('No se pudo dibujar las celdas: ${error.runtimeType}');
    });
  }

  Future<void> _draw() async {
    final controller = _controller;
    if (controller == null || !_styleReady || !mounted) return;
    final data = cellsGeoJson(widget.cells, widget.need);
    if (_layersAdded) {
      await controller.setGeoJsonSource(_source, data);
      return;
    }
    await controller.addGeoJsonSource(_source, data);
    await controller.addFillLayer(
      _source,
      _fill,
      native.FillLayerProperties(
        fillColor: [
          'match',
          ['get', 'nivel'],
          for (final entry in cellLevelColors.entries) ...[entry.key.name, _hex(entry.value)],
          '#FFFFFF',
        ],
        fillOpacity: 0.6,
      ),
    );
    await controller.addLineLayer(
      _source,
      _line,
      const native.LineLayerProperties(lineColor: '#1B1B1F', lineWidth: 1.5),
    );
    _layersAdded = true;
  }

  @override
  Widget build(BuildContext context) {
    final environment = ref.watch(consoleEnvironmentProvider);
    final bounds = environment.mapBounds;
    return Semantics(
      container: true,
      label: widget.label,
      child: ExcludeSemantics(
        child: ExcludeFocus(
          child: native.MapLibreMap(
            styleString: environment.mapStyleUrl,
            initialCameraPosition: native.CameraPosition(
              target: native.LatLng(bounds.centerLatitude, bounds.centerLongitude),
              zoom: 13,
            ),
            cameraTargetBounds: native.CameraTargetBounds(
              native.LatLngBounds(
                southwest: native.LatLng(bounds.south, bounds.west),
                northeast: native.LatLng(bounds.north, bounds.east),
              ),
            ),
            minMaxZoomPreference: native.MinMaxZoomPreference(
              environment.mapMinZoom,
              environment.mapMaxZoom,
            ),
            myLocationEnabled: false,
            onMapCreated: (controller) => _controller = controller,
            onStyleLoadedCallback: () {
              _styleReady = true;
              _scheduleDraw();
            },
          ),
        ),
      ),
    );
  }
}
