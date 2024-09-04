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

LatLng halfSegmentCoord(LatLng first, LatLng last) {
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

Wpt cloneWpt(Wpt wpt) {
  return Wpt(
      lat: wpt.lat,
      lon: wpt.lon,
      ele: wpt.ele,
      time: wpt.time,
      magvar: wpt.magvar,
      geoidheight: wpt.geoidheight,
      name: wpt.name,
      cmt: wpt.cmt,
      desc: wpt.desc,
      src: wpt.src,
      links: wpt.links,
      sym: wpt.sym,
      type: wpt.type,
      fix: wpt.fix,
      sat: wpt.sat,
      hdop: wpt.hdop,
      vdop: wpt.vdop,
      pdop: wpt.pdop,
      ageofdgpsdata: wpt.ageofdgpsdata,
      dgpsid: wpt.dgpsid,
      extensions: wpt.extensions);
}
