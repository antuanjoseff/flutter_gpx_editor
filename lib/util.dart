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

LatLng halfSegmentSymbol(LatLng first, LatLng last) {
  return LatLng((first.latitude + last.latitude) / 2,
      (first.longitude + last.longitude) / 2);
}

Wpt halfSegmentWpt(Wpt first, Wpt last) {
  Wpt half = Wpt(
      lat: first.lat,
      lon: first.lon,
      ele: first.ele,
      time: first.time,
      magvar: first.magvar,
      geoidheight: first.geoidheight,
      name: first.name,
      cmt: first.cmt,
      desc: first.desc,
      src: first.src,
      links: first.links,
      sym: first.sym,
      type: first.type,
      fix: first.fix,
      sat: first.sat,
      hdop: first.hdop,
      vdop: first.vdop,
      pdop: first.pdop,
      ageofdgpsdata: first.ageofdgpsdata,
      dgpsid: first.dgpsid,
      extensions: first.extensions);

  half.ele = (first.ele! + last.ele!) / 2;
  half.lat = (first.lat! + last.lat!) / 2;
  half.lon = (first.lon! + last.lon!) / 2;

  return half;
}
