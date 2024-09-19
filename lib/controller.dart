import 'package:geoxml/geoxml.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class Controller {
  Future<Line?> Function(List<Wpt> lineSegment)? loadTrack;
  void Function()? resetTrackLine;
  Future<List<Symbol>> Function(bool, String)? addMapSymbols;
  void Function()? removeMapSymbols;
  List<Wpt> Function()? getGpx;
  void Function()? showEditIcons;
  void Function()? hideEditIcons;
}
