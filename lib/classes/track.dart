import 'package:flutter/material.dart';
import 'package:geoxml/geoxml.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'bounds.dart' as my;
import '../util.dart';

class Track {
  // Original track
  List<Wpt> trackSegment = [];
  List<Wpt> wpts = [];

  // Array of coordinates to draw a linestring on map
  List<LatLng> gpxCoords = [];

  // Track Length
  double length = 0;

  // Constructor
  Track(this.trackSegment);

  // Bbox del track
  my.Bounds? bounds;

  Future<void> init() async {
    LatLng cur;
    double inc = 0;
    // Init track bounds with first track point
    bounds = my.Bounds(LatLng(trackSegment.first.lat!, trackSegment.first.lon!),
        LatLng(trackSegment.first.lat!, trackSegment.first.lon!));

    for (var i = 0; i < trackSegment.length; i++) {
      cur = LatLng(trackSegment[i].lat!, trackSegment[i].lon!);

      if (gpxCoords.isNotEmpty) {
        LatLng prev = gpxCoords[gpxCoords.length - 1];
        inc = getDistanceFromLatLonInMeters(cur, prev);
      }

      bounds!.expand(cur);
      gpxCoords.add(cur);
      length += inc;
    }
  }

  double getLength() {
    return length;
  }

  List<LatLng> getCoordsList() {
    return gpxCoords;
  }

  List<Wpt> getTrack() {
    return trackSegment;
  }

  List<Wpt> getWpts() {
    return wpts;
  }

  my.Bounds getBounds() {
    return bounds!;
  }

  void reset() {
    gpxCoords = [];
    trackSegment = [];
  }

  void addNode(int position, Wpt wpt) {
    LatLng P = LatLng(wpt.lat!, wpt.lon!);
    gpxCoords.insert(position + 1, P);
    trackSegment.insert(position + 1, wpt);
  }

  void addWpt(Wpt wpt) {
    wpts.add(wpt);
  }

  void insertWpt(int idx, Wpt wpt) {
    wpts.insert(idx, wpt);
  }

  void updateWpt(int idx, Wpt wpt) {
    debugPrint('            $idx        ${wpt.name}');
    wpts.removeAt(idx);
    wpts.insert(idx, wpt);
  }

  void removeWpt(int idx) {
    wpts.removeAt(idx);
  }

  void removeNode(int index) {
    print('delete node 0 .............    $index');
    trackSegment.removeAt(index);
    print('delete node 1.............    $index');
    gpxCoords.removeAt(index);
    print('delete node 2 .............    $index');
  }

  void addTrkpt(int idx, Wpt wpt) {
    trackSegment.insert(idx, wpt);
    LatLng latlon = LatLng(wpt.lat!, wpt.lon!);
    gpxCoords.insert(idx, latlon);
  }

  void removeTrkpt(int idx, Wpt wpt) {
    trackSegment.removeAt(idx);
    gpxCoords.removeAt(idx);
  }

  void moveWpt(int idx, Wpt wpt) {
    trackSegment[idx] = wpt;
    LatLng latlon = LatLng(wpt.lat!, wpt.lon!);
    gpxCoords[idx] = latlon;
  }

  (double, int, LatLng) getCandidateNode(LatLng clickedPoint) {
    Stopwatch stopwatch = new Stopwatch()..start();
    int numSegment = getClosestSegmentToLatLng(gpxCoords, clickedPoint);
    print('Closest at ($numSegment) executed in ${stopwatch.elapsed}');

    LatLng P = projectionPoint(
        gpxCoords[numSegment], gpxCoords[numSegment + 1], clickedPoint);

    double dist = getDistanceFromLatLonInMeters(clickedPoint, P);

    return (dist, numSegment, P);
  }

  int getClosestSegmentToLatLng(gpxCoords, point) {
    if (gpxCoords.length <= 0) return -1;
    int closestSegment = 0;
    double distance = double.infinity;
    double minD = double.infinity;

    // return 0;
    for (var i = 0; i < gpxCoords.length - 1; i++) {
      distance = minDistance(gpxCoords[i], gpxCoords[i + 1], point);

      if (distance < minD) {
        minD = distance;
        closestSegment = i;
      }
    }

    return closestSegment;
  }

  void changeNodeAt(int idx, LatLng coordinate) {
    gpxCoords[idx] = coordinate;
  }

  Wpt getWptAt(int idx) {
    return trackSegment[idx];
  }

  void setWptAt(int idx, Wpt wpt) {
    trackSegment[idx] = wpt;
  }
}
