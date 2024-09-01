import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geoxml/geoxml.dart';

/// Adds an asset image to the currently displayed style
Future<void> addImageFromAsset(
    MapLibreMapController controller, String name, String assetName) async {
  final bytes = await rootBundle.load(assetName);
  final list = bytes.buffer.asUint8List();
  return controller.addImage(name, list);
}

Wpt halfSegmentNode(Wpt first, Wpt last){
  Wpt half = first;
  half.ele = (first.ele! + last.ele!)  / 2;
  half.lat = (first.lat! + last.lat!) / 2;
  half.lon = (first.lon! + last.lon!) / 2;

  return half;
}