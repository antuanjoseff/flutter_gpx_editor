import 'package:flutter/material.dart';
import 'package:geoxml/geoxml.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'bounds.dart' as my;
import '../util.dart';

class Track {
  // Original track
  List<Wpt> trackSegment = [];

  // Accumulated distance of each track point. Used in chart
  List<int> xChartLabels = [];
  List<int> elevations = [];
  List<double> speeds = [];
  late double minElevation;
  late double maxElevation;
  int elevationGain = 0;
  int elevationLoss = 0;
  double minSpeed = 0;
  double maxSpeed = 0;

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

    minElevation = trackSegment[0].ele!;
    maxElevation = minElevation;

    for (var i = 0; i < trackSegment.length; i++) {
      cur = LatLng(trackSegment[i].lat!, trackSegment[i].lon!);

      if (gpxCoords.isNotEmpty) {
        LatLng prev = gpxCoords[gpxCoords.length - 1];
        inc = getDistanceFromLatLonInMeters(cur, prev);
        if (trackSegment[i].time != null && trackSegment[i - 1].time != null) {
          double sp = 3600 *
              (inc /
                  (trackSegment[i].time!)
                      .difference(trackSegment[i - 1].time!)
                      .inMilliseconds);
          if (sp == double.infinity) {
            sp = speeds[speeds.length - 1];
          }
          maxSpeed = sp > maxSpeed ? sp : maxSpeed;
          speeds.add(sp);
        }
        if (trackSegment[i].ele != null && trackSegment[i - 1].ele != null) {
          double e = trackSegment[i].ele!;
          minElevation = (e < minElevation) ? e : minElevation;
          maxElevation = (e > maxElevation) ? e : maxElevation;
          if (trackSegment[i].ele!.floor() > trackSegment[i - 1].ele!.floor()) {
            elevationGain +=
                trackSegment[i].ele!.floor() - trackSegment[i - 1].ele!.floor();
          } else {
            elevationLoss +=
                trackSegment[i - 1].ele!.floor() - trackSegment[i].ele!.floor();
          }
        }
      }

      bounds!.expand(cur);
      gpxCoords.add(cur);
      length += inc;
      xChartLabels.add(length.floor());
      trackSegment[i].ele ??= 0;
      double e = trackSegment[i].ele!;
      elevations.add(e.floor());
    }
  }

  int getElevationGain() {
    return elevationGain;
  }

  int getElevationLoss() {
    return elevationLoss;
  }

  double getLength() {
    return length;
  }

  double getMinElevation() {
    return minElevation;
  }

  double getMaxElevation() {
    return maxElevation;
  }

  List<int> getElevations() {
    return elevations;
  }

  List<int> getXChartLabels() {
    return xChartLabels;
  }

  double getMinSpeed() {
    return minSpeed;
  }

  double getMaxSpeed() {
    return maxSpeed;
  }

  List<double> getSpeeds() {
    return speeds;
  }

  Duration getDuration() {
    DateTime? start = trackSegment[0].time;
    DateTime? end = trackSegment[trackSegment.length - 1].time;

    if (start != null && end != null) {
      return end.difference(start);
    } else {
      return Duration(seconds: 0);
    }
  }

  void showNode(int idx) {
    print(gpxCoords[idx]);
  }

  LatLng getNode(int idx) {
    return gpxCoords[idx];
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
    wpts.removeAt(idx);
    wpts.insert(idx, wpt);
  }

  void removeWpt(int idx) {
    wpts.removeAt(idx);
  }

  void removeNode(int index) {
    trackSegment.removeAt(index);
    gpxCoords.removeAt(index);
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
    int numSegment = getClosestSegmentToLatLng(gpxCoords, clickedPoint);

    LatLng P = projectionPoint(
        gpxCoords[numSegment], gpxCoords[numSegment + 1], clickedPoint);

    double dist = getDistanceFromLatLonInMeters(clickedPoint, P);

    return (dist, numSegment, P);
  }

  int getClosestNodeFrom(LatLng location) {
    double minD = double.infinity;
    int closestNodeIdx = 0;
    for (var i = 0; i < gpxCoords.length; i++) {
      LatLng candidate = gpxCoords[i];
      double distance = getDistanceFromLatLonInMeters(candidate, location);

      if (distance < minD) {
        minD = distance;
        closestNodeIdx = i;
      }
    }

    return closestNodeIdx;
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
