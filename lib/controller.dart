import 'package:geoxml/geoxml.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class Controller {
  Future<Line?> Function(List<Wpt> lineSegment)? loadTrack;
  Future<void> Function()? removeTrackLine;
  Future<List<Symbol>> Function()? addMapSymbols;
  void Function()? removeMapSymbols;
  List<Wpt> Function()? getGpx;
  void Function()? showEditIcons;
  void Function()? hideEditIcons;
  Future<void> Function(LineOptions changes)? updateTrack;
  bool Function()? getEditMode;
}
