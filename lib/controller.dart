import 'package:geoxml/geoxml.dart';

class Controller {
  void Function(List<Wpt> lineSegment)? loadTrack;
  void Function()? resetTrackLine;
}
