import 'package:geoxml/geoxml.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:flutter/material.dart';

class Controller {
  Future<Line?> Function(List<Wpt> lineSegment, List<Wpt> wpts)? loadTrack;
  Future<void> Function()? removeTrackLine;
  Future<List<Symbol>> Function()? addNodeSymbols;
  void Function()? removeNodeSymbols;
  List<Wpt> Function()? getGpx;
  List<Wpt> Function()? getWpts;
  Future<void> Function(Color color, double width, LineOptions changes)?
      updateTrack;
  void Function(bool value)? setEditMode;
  void Function(String)? setBaseLayer;
  LatLng Function()? getCenter;
  double Function()? getZoom;
  Future<(String?, String?)> Function(String)? showDialogSaveFile;
  void Function(LatLng location)? showNode;
}
