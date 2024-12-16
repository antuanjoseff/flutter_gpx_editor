import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:gpx_editor/vars/vars.dart';
import 'controller.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class LeffDrawer extends StatefulWidget {
  final Controller controller;

  const LeffDrawer({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  State<LeffDrawer> createState() => _LeffDrawerState();
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

class _LeffDrawerState extends State<LeffDrawer> {
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
            const SizedBox(
              height: 50,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_forward),
                  color: Colors.white,
                  iconSize: 30,
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            Text(AppLocalizations.of(context)!.leftDrawerTitle,
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
                    // Navigator.of(context).pop();
                  },
                  child: AbsorbPointer(
                    child: MapLibreMap(
                      compassEnabled: false,
                      onMapCreated: _onMapCreated,
                      minMaxZoomPreference: MinMaxZoomPreference(0, 16),
                      styleString: 'assets/styles/only_orto_style.json',
                      attributionButtonPosition: attributionButtonPosition,
                      initialCameraPosition: CameraPosition(
                        target: widget.controller.getCenter!(),
                        zoom: widget.controller.getZoom!() - 2,
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
                    // Navigator.of(context).pop();
                  },
                  child: AbsorbPointer(
                    child: MapLibreMap(
                      compassEnabled: false,
                      styleString: 'assets/styles/only_osm_style.json',
                      onMapCreated: _onMapCreated,
                      minMaxZoomPreference: MinMaxZoomPreference(0, 16),
                      initialCameraPosition: CameraPosition(
                        target: widget.controller.getCenter!(),
                        zoom: widget.controller.getZoom!() - 2,
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
