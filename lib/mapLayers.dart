import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:gpx_editor/vars/vars.dart';
import 'controller.dart';

class MapLayers extends StatefulWidget {
  final Controller controller;

  const MapLayers({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  State<MapLayers> createState() => _MapLayersState();
}

MapLibreMapController? mapController;

late Controller controller;
late double zoom;
late LatLng center;

String osmStyle = 'assets/styles/only_osm.json';
String ortoStyle = 'assets/styles/only_orto.json';
AttributionButtonPosition? attributionButtonPosition;

_onMapCreated(MapLibreMapController controller) {
  mapController = controller;
}

class _MapLayersState extends State<MapLayers> {
  @override
  void initState() {
    // TODO: implement initState
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      // height: 500,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            const Text('CAPA BASE',
                style: TextStyle(color: Colors.white, fontSize: 20)),
            SizedBox(
              height: 200,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: primaryColor,
                  ),
                ),
                child: GestureDetector(
                  onTap: () {
                    widget.controller.setBaseLayer!('orto');
                    Navigator.of(context).pop();
                  },
                  child: AbsorbPointer(
                    child: MapLibreMap(
                      compassEnabled: false,
                      onMapCreated: _onMapCreated,
                      styleString: ortoStyle,
                      attributionButtonPosition: attributionButtonPosition,
                      initialCameraPosition: CameraPosition(
                        target: widget.controller.getCenter!(),
                        zoom: widget.controller.getZoom!(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: primaryColor,
                  ),
                ),
                child: GestureDetector(
                  onTap: () {
                    widget.controller.setBaseLayer!('osm');
                    Navigator.of(context).pop();
                  },
                  child: AbsorbPointer(
                    child: MapLibreMap(
                      compassEnabled: false,
                      styleString: osmStyle,
                      onMapCreated: _onMapCreated,
                      initialCameraPosition: CameraPosition(
                        target: widget.controller.getCenter!(),
                        zoom: widget.controller.getZoom!(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
