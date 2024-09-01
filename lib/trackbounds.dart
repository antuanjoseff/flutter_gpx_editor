import 'package:maplibre_gl/maplibre_gl.dart';


class Trackbounds {
  LatLng? southEast;
  LatLng? northWest;
  // Constructor
  Trackbounds(LatLng southEast, LatLng northWest);

  expand(LatLng coord){
     if (coord.latitude < southEast!.latitude) {
        southEast = LatLng(coord.latitude, southEast!.longitude);
     }
       
     if (coord.longitude < southEast!.longitude) {
        southEast = LatLng(southEast!.latitude, coord.longitude);
      }

     if (coord.latitude > northWest!.latitude) {
        northWest = LatLng(coord.latitude, northWest!.longitude);
      }  
       
     if (coord.longitude > northWest!.longitude) {
        northWest = LatLng(northWest!.latitude, coord.longitude);
      }
     
  }

}