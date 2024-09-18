import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geoxml/geoxml.dart';
import 'controller.dart';
import 'move_icon.dart';
import 'delete_icon.dart';
import 'package:throttling/throttling.dart';
import 'util.dart';

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

  bool editMode = true;
  List<Wpt> rawGpx = [];
  List<LatLng> nodes = [];
  List<LatLng> gpxCoords = [];
  List<(int, Wpt, String)> edits = [];

  String? filename;
  String? fileName;

  GeoXml? gpxOriginal;
  bool gpxLoaded = false;
  bool showTools = true;

  Symbol? selectedSymbol;

  int selectedNode = -1;
  String selectedNodeType = '';

  final thr = Throttling<void>(duration: const Duration(milliseconds: 200));
  final deb = Debouncing<void>(duration: const Duration(milliseconds: 200));

  @override
  void initState() {
    super.initState();
  }

  _MyMaplibreState(Controller controller) {
    controller.loadTrack = loadTrack;
    controller.resetTrackLine = resetTrackLine;
  }

  void _onMapCreated(MapLibreMapController contrl) async {
    mapController = contrl;
    mapController!.onSymbolTapped.add(_onSymbolTapped);
    mapController!.onFeatureDrag.add(_onNodeDrag);
  }

  void deleteNode() async {
    if (selectedNode == -1) return;
    edits.add((selectedNode, cloneWpt(rawGpx[selectedNode]), 'delete'));
    nodes.removeAt(selectedNode);
    gpxCoords.removeAt(selectedNode);
    rawGpx.removeAt(selectedNode);
    await mapController!.removeSymbol(mapSymbols[selectedNode]);
    mapSymbols.removeAt(selectedNode);
    updateTrackLine();
    selectedNode = -1;
    selectedSymbol = null;
    setState(() {});
  }

  void _onSymbolTapped(Symbol symbol) async {
    thr.throttle(() async {
      if (selectedSymbol != null) {
        String symbolId = await deactivateSymbol(selectedSymbol!, selectedNode);
        if (symbolId != symbol.id) {
          selectedSymbol = symbol;
          selectedNode = await searchSymbol(symbol.id);
          await activateSymbol(selectedSymbol!, selectedNode);
        } else {
          await deactivateSymbol(selectedSymbol!, selectedNode);
        }
        // setState(() {});
        return;
      }

      selectedSymbol = symbol;
      selectedNode = await searchSymbol(symbol.id);

      activateSymbol(selectedSymbol!, selectedNode);
    });
  }

  void _onNodeDrag(id,
      {required current,
      required delta,
      required origin,
      required point,
      required eventType}) async {
    if (selectedNode == -1) return;

    switch (eventType) {
      case DragEventType.start:
        selectedNode = await searchSymbol(id);
        selectedSymbol = mapSymbols[selectedNode];
        edits.add((selectedNode, cloneWpt(rawGpx[selectedNode]), 'moved'));
        break;
      case DragEventType.drag:
        thr.throttle(() {
          gpxCoords[selectedNode] = LatLng(current.latitude, current.longitude);
          updateTrackLine();
        });
        break;
      case DragEventType.end:
        LatLng coord = LatLng(current.latitude, current.longitude);
        gpxCoords[selectedNode] = coord;
        nodes[selectedNode] = coord;

        Wpt dragged = rawGpx[selectedNode];
        dragged.lat = coord.latitude;
        dragged.lon = coord.longitude;
        rawGpx[selectedNode] = dragged;

        updateTrackLine();
        _updateSelectedSymbol(
          selectedSymbol!,
          SymbolOptions(
              geometry: coord, draggable: false, iconImage: 'node-box'),
        );

        await deactivateSymbol(selectedSymbol!, selectedNode);
        selectedNode = -1;
        setState(() {});
        break;
    }
  }

  Future<String> activateSymbol(Symbol symbol, int idx) async {
    await redrawSymbol(symbol, idx, 'activate');
    return symbol.id;
  }

  Future<String> deactivateSymbol(Symbol symbol, int idx) async {
    await redrawSymbol(symbol, idx, 'deactivate');
    selectedSymbol = null;
    return symbol.id;
  }

  Future<void> redrawSymbol(Symbol symbol, int idx, String mode) async {
    String image = 'node-box';
    bool draggable = false;
    if (mode == 'activate') {
      image = 'selected-box';
      draggable = true;
    }

    LatLng coords = LatLng(
        symbol.options.geometry!.latitude, symbol.options.geometry!.longitude);

    // Change icon, then wait and change draggable prop
    _updateSelectedSymbol(
      selectedSymbol!,
      SymbolOptions(geometry: coords, iconImage: image, draggable: draggable),
    );

    setState(() {});
  }

  Future<int> searchSymbol(String search) async {
    for (var i = 0; i < mapSymbols.length; i++) {
      if (mapSymbols[i].id == search) {
        return i;
      }
    }
    return -1;
  }

  void _updateSelectedSymbol(Symbol symbol, SymbolOptions changes) async {
    await mapController!.updateSymbol(symbol, changes);
    setState(() {});
  }

  void updateTrackLine() async {
    await mapController!
        .updateLine(trackLine!, LineOptions(geometry: gpxCoords));
    // setState(() {});
  }

  List<SymbolOptions> makeSymbolOptions(nodes, symbolIcon) {
    final symbolOptions = <SymbolOptions>[];

    for (var idx = 0; idx < nodes.length; idx++) {
      LatLng coord = nodes[idx];
      symbolOptions.add(SymbolOptions(
          iconImage: symbolIcon, geometry: coord, textAnchor: idx.toString()));
    }

    return symbolOptions;
  }

  void addMapSymbols() async {
    print('ADD MAP SYMBOLS');
    mapSymbols =
        await mapController!.addSymbols(makeSymbolOptions(nodes, 'node-box'));
  }

  void removeSymbols() async {
    await mapController!.removeSymbols(mapSymbols);
    mapSymbols = [];
  }

  void resetSymbols() {
    removeSymbols();
    addMapSymbols();
  }

  @override
  void dispose() {
    mapController?.onSymbolTapped.remove(_onSymbolTapped);
    mapController!.onFeatureDrag.remove(_onNodeDrag);
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
      nodes.add(cur);
      rawGpx.add(trackSegment[i]);
    }

    //Last point. No mid node required
    int last = trackSegment.length - 1;
    cur = LatLng(trackSegment[last].lat, trackSegment[last].lon);
    bounds.expand(cur);
    gpxCoords.add(cur);
    rawGpx.add(trackSegment[last]);
    nodes.add(cur);

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

    if (editMode || !editMode) {
      addMapSymbols();
    }
  }

  void resetTrackLine() {
    if (trackLine != null) {
      mapController!.removeLine(trackLine!);
      if (editMode) {
        editMode = false;
        removeSymbols();
      }
    }
    editMode = false;
    nodes = [];
    mapSymbols = [];
    gpxCoords = [];
    rawGpx = [];
    edits = [];
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      MapLibreMap(
        compassEnabled: false,
        trackCameraPosition: true,
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: () {
          addImageFromAsset(
              mapController!, "node-box", "assets/symbols/box.png");
          addImageFromAsset(mapController!, "selected-box",
              "assets/symbols/selected-box.png");
          addImageFromAsset(
              mapController!, "virtual-box", "assets/symbols/virtual-box.png");
          addImageFromAsset(
              mapController!, "marker", "assets/symbols/custom-marker.png");
        },
        onMapClick: (point, clickedPoint) async {
          print('ON MAP CLICKED $editMode');
          if (gpxCoords.isEmpty || !editMode) return;
          print('.....................$selectedSymbol');
          if (selectedSymbol != null) {
            deactivateSymbol(selectedSymbol!, selectedNode);
            print('...............RESET SYMBOL');
          }
          Stopwatch stopwatch = new Stopwatch()..start();
          int segment = getClosestSegmentToLatLng(gpxCoords, clickedPoint);
          print('Closest at ($segment) executed in ${stopwatch.elapsed}');

          LatLng P = projectionPoint(
              gpxCoords[segment], gpxCoords[segment + 1], clickedPoint);

          double dist = getDistanceFromLatLonInMeters(clickedPoint, P);
          print('....................$dist');
          // if (dist < 20) {
          //   Symbol added = await controller!.addSymbol(SymbolOptions(
          //       draggable: false, iconImage: 'node-box', geometry: P));

          //   mapSymbols.insert(segment + 1, added);

          //   gpxCoords.insert(segment + 1, P);
          //   Wpt newWpt =
          //       cloneWpt(halfSegmentWpt(rawGpx[segment], rawGpx[segment + 1]));
          //   newWpt.lat = P.latitude;
          //   newWpt.lon = P.longitude;
          //   rawGpx.insert(segment + 1, newWpt);

          //   updateTrackLine();
          // }
        },
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
                        deleteNode();
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
