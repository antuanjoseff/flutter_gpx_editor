import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geoxml/geoxml.dart';
import 'controller.dart';
import 'move_icon.dart';
import 'delete_icon.dart';

class MyMapLibre extends StatefulWidget {
  final Controller controller;
  const MyMapLibre({
    Key? key,
    required this.controller,
  }) : super(key: key);

  @override
  State<MyMapLibre> createState() => _MyMaplibreState(controller);
}

class _MyMaplibreState extends State<MyMapLibre> {
  MapLibreMapController? mapController;

  Line? trackLine;
  List<Symbol> mapSymbols =
      []; //Symbols on map to allow dragging the existing NODES of the gpx track

  bool editMode = false;
  List<Wpt> rawGpx = [];
  List<LatLng> realNodes = [];
  List<LatLng> gpxCoords = [];

  String? filename;
  String? fileName;

  GeoXml? gpxOriginal;
  bool gpxLoaded = false;
  bool showTools = true;

  @override
  void initState() {
    super.initState();
  }

  void doSomething(List<Wpt> linesegment) {
    print('--- ---------$linesegment ------DO SOMETHING FUNCTION');
  }

  _MyMaplibreState(Controller controller) {
    controller.loadTrack = loadTrack;
  }

  void _onMapCreated(MapLibreMapController contrl) async {
    mapController = contrl;
  }

  @override
  void dispose() {
    super.dispose();
  }

  void loadTrack(trackSegment) async {
    LatLng cur;

    Bounds bounds = Bounds(
        LatLng(trackSegment.first.lat, trackSegment.first.lon),
        LatLng(trackSegment.first.lat, trackSegment.first.lon));

    for (var i = 0; i < trackSegment.length - 1; i++) {
      cur = LatLng(trackSegment[i].lat, trackSegment[i].lon);
      bounds.expand(cur);
      gpxCoords.add(cur);
      realNodes.add(cur);
      rawGpx.add(trackSegment[i]);
    }

    //Last point. No mid node required
    int last = trackSegment.length - 1;
    cur = LatLng(trackSegment[last].lat, trackSegment[last].lon);
    bounds.expand(cur);
    gpxCoords.add(cur);
    rawGpx.add(trackSegment[last]);
    realNodes.add(cur);

    trackLine = await mapController!.addLine(
      LineOptions(
        geometry: gpxCoords,
        lineColor: "#ffa500",
        lineWidth: 2.5,
        lineOpacity: 0.9,
      ),
    );

    mapController!.moveCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: bounds.southEast,
          northeast: bounds.northWest,
        ),
        left: 10,
        top: 5,
        bottom: 25,
      ),
    );

    setState(() {
      gpxLoaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      MapLibreMap(
        compassEnabled: false,
        trackCameraPosition: true,
        onMapCreated: _onMapCreated,
        initialCameraPosition: const CameraPosition(
          target: LatLng(42.0, 3.0),
          zoom: 13.0,
        ),
        styleString:
            'https://geoserveis.icgc.cat/contextmaps/icgc_orto_hibrida.json',
      ),
      ...[
        showTools
            ? Positioned(
                right: 15,
                top: 15,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        print('ON TAB GESTURE DETECTOR');
                      },
                      child: const CircleAvatar(
                        backgroundColor: Colors.white,
                        child: MoveIcon(),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(4.0),
                    ),
                    GestureDetector(
                      onTap: () {
                        print('ON TAB GESTURE DETECTOR');
                      },
                      child: const CircleAvatar(
                        backgroundColor: Colors.white,
                        child: DeleteIcon(),
                      ),
                    ),
                  ],
                ),
              )
            : Container(),
      ],
    ]);
  }
}

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
