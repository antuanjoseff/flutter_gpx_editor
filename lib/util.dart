import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geoxml/geoxml.dart';
import 'dart:math';
import 'dart:core';
import 'dart:async';
import 'package:flutter/material.dart';

/// Adds an asset image to the currently displayed style
Future<void> addImageFromAsset(
    MapLibreMapController controller, String name, String assetName) async {
  final bytes = await rootBundle.load(assetName);
  final list = bytes.buffer.asUint8List();
  return controller.addImage(name, list);
}

DateTime? avgTime(DateTime? startTime, DateTime? endTime) {
  if (startTime != null && endTime != null) {
    int inc =
        ((endTime.millisecondsSinceEpoch - startTime.millisecondsSinceEpoch) /
                2)
            .round();
    print('INCREMENT  ................. $inc');

    return DateTime.fromMillisecondsSinceEpoch(
        startTime.millisecondsSinceEpoch + inc,
        isUtc: true);
  }
  return null;
}

LatLng halfSegmentCoord(LatLng first, LatLng last) {
  return LatLng((first.latitude + last.latitude) / 2,
      (first.longitude + last.longitude) / 2);
}

Wpt halfSegmentWpt(Wpt first, Wpt last) {
  Wpt half = cloneWpt(first);

  half.ele = (first.ele! + last.ele!) / 2;
  half.lat = (first.lat! + last.lat!) / 2;
  half.lon = (first.lon! + last.lon!) / 2;
  half.time = avgTime(first.time, last.time);
  print('FIRST TIME ................ ${first.time}');
  print('LAST TIME ................ ${last.time}');
  print('AVG TIME ................ ${half.time}');

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

double minDistance(LatLng A, LatLng B, LatLng P) {
  // vector AB
  List<double> AB = [];

  AB.add(B.longitude - A.longitude);
  AB.add(B.latitude - A.latitude);

  // vector BP
  List<double> BP = [];
  BP.add(P.longitude - B.longitude);
  BP.add(P.latitude - B.latitude);

  // vector AP
  List<double> AP = [];
  AP.add(P.longitude - A.longitude);
  AP.add(P.latitude - A.latitude);

  // Variables to store dot product
  double AB_BP, AB_AP;

  // Calculating the dot product
  AB_BP = (AB[0] * BP[0] + AB[1] * BP[1]);
  AB_AP = (AB[0] * AP[0] + AB[1] * AP[1]);

  // Minimum distance from
  // point E to the line segment
  double reqAns = 0;

  // Case 1
  if (AB_BP > 0) {
    // Finding the magnitude
    double y = P.latitude - B.latitude;
    double x = P.longitude - B.longitude;
    reqAns = sqrt(x * x + y * y);
  }

  // Case 2
  else if (AB_AP < 0) {
    double y = P.latitude - A.latitude;
    double x = P.longitude - A.longitude;
    reqAns = sqrt(x * x + y * y);
  }

  // Case 3
  else {
    // Finding the perpendicular distance
    double x1 = AB[0];
    double y1 = AB[1];
    double x2 = AP[0];
    double y2 = AP[1];
    double mod = sqrt(x1 * x1 + y1 * y1);
    reqAns = ((x1 * y2 - y1 * x2) / mod).abs();
  }
  return reqAns;
}

LatLng projectionPoint(LatLng X, LatLng Y, LatLng P) {
  double slope = (Y.latitude - X.latitude) / (Y.longitude - X.longitude);
  double perpendicular = -1 / slope;

  double b = X.latitude - slope * X.longitude;
  double b2 = P.latitude + (P.longitude / slope);

  double intersectionX = (b2 - b) / (slope - perpendicular);
  double intersectionY = (slope * intersectionX) + b;

  return LatLng(intersectionY, intersectionX);
}

double deg2rad(double deg) {
  return deg / 180.0 * pi;
}

double getDistanceFromLatLonInMeters(LatLng origin, LatLng target) {
  double lat1 = origin.latitude;
  double lat2 = target.latitude;
  double lon1 = origin.longitude;
  double lon2 = target.longitude;

  int R = 6371; // Radius of the earth in km
  double dLat = deg2rad(lat2 - lat1); // deg2rad below
  double dLon = deg2rad(lon2 - lon1);
  double a = sin(dLat / 2) * sin(dLat / 2) +
      cos(deg2rad(lat1)) * cos(deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
  double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  double d = R * c; // Distance in km
  return d * 1000; //distance in meters
}

setTimeout(callback, time) {
  Duration timeDelay = Duration(milliseconds: time);
  return Timer(timeDelay, callback);
}

void showSnackBar(context, String txt) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            Icons.warning_rounded,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 20),
          Expanded(
              child: Text(
            txt,
            style: TextStyle(color: Theme.of(context).primaryColor),
          )),
        ],
      ),
      backgroundColor: Theme.of(context).secondaryHeaderColor,
      duration: const Duration(milliseconds: 3000),
    ),
  );
}
