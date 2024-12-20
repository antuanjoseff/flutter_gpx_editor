import 'package:geoxml/geoxml.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class Controller {
  Future<Line?> Function(List<Wpt> lineSegment)? loadTrack;
  Future<void> Function()? removeTrackLine;
  Future<List<Symbol>> Function()? addNodeSymbols;
  void Function()? removeNodeSymbols;
  List<Wpt> Function()? getGpx;
  List<Wpt> Function()? getWpts;
  Future<void> Function(LineOptions changes)? updateTrack;
  void Function(bool value)? setEditMode;
  void Function(String)? setBaseLayer;
  LatLng Function()? getCenter;
  double Function()? getZoom;
}
