import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class MapLayers extends StatefulWidget {
  const MapLayers({super.key});

  @override
  State<MapLayers> createState() => _MapLayersState();
}

MapLibreMapController? mapController;

String osmStyle = 'assets/styles/only_osm.json';
String ortoStyle = 'assets/styles/only_orto.json';
AttributionButtonPosition? attributionButtonPosition;

_onMapCreated(MapLibreMapController controller) {
  mapController = controller;
}

class _MapLayersState extends State<MapLayers> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      // height: 500,
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: MapLibreMap(
              compassEnabled: false,
              onMapCreated: _onMapCreated,
              styleString: ortoStyle,
              attributionButtonPosition: attributionButtonPosition,
              initialCameraPosition: const CameraPosition(
                target: LatLng(0.0, 0.0),
                zoom: 0.01,
              ),
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: MapLibreMap(
              compassEnabled: false,
              styleString: osmStyle,
              onMapCreated: _onMapCreated,
              initialCameraPosition: const CameraPosition(
                target: LatLng(0.0, 0.0),
                zoom: 0.01,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
