import 'package:maplibre_gl/maplibre_gl.dart';

class Bounds {
  LatLng southEast = const LatLng(90, 179.9);
  LatLng northWest = const LatLng(-90, -180);
  // Constructor
  Bounds(LatLng southEast, LatLng northWest);

  expand(LatLng coord) {
    if (coord.latitude < southEast.latitude) {
      southEast = LatLng(coord.latitude, southEast.longitude);
    }

    if (coord.longitude < southEast.longitude) {
      southEast = LatLng(southEast.latitude, coord.longitude);
    }

    if (coord.latitude > northWest.latitude) {
      northWest = LatLng(coord.latitude, northWest.longitude);
    }

    if (coord.longitude > northWest.longitude) {
      northWest = LatLng(northWest.latitude, coord.longitude);
    }
  }
}
