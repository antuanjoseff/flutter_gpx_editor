import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geoxml/geoxml.dart';
import 'controller.dart';
import 'move_icon.dart';
import 'delete_icon.dart';
import 'undo_icon.dart';
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
  Color defaultColor1 = Colors.green; // Selects a mid-range green.
  Color defaultColor2 = Colors.black; // Selects a mid-range green.
  Color activeColor1 = Colors.black; // Selects a mid-range green.
  Color activeColor2 = Colors.red; // Selects a mid-range green.
  Color backgroundColor1 = Colors.white;
  Color backgroundColor2 = Colors.white;
  Color? currentColor1;
  Color? currentColor2;
  Color? backgroundColor;

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
  bool showTools = false;
  bool draggableMode = false;
  bool deleteMode = false;

  Symbol? selectedSymbol;

  int selectedNode = -1;
  String selectedNodeType = '';

  final thr = Throttling<void>(duration: const Duration(milliseconds: 200));
  final deb = Debouncing<void>(duration: const Duration(milliseconds: 200));

  _MyMaplibreState(Controller controller) {
    controller.loadTrack = loadTrack;
    controller.resetTrackLine = resetTrackLine;
    controller.addMapSymbols = addMapSymbols;
    controller.removeMapSymbols = removeMapSymbols;
    controller.showEditIcons = showEditIcons;
    controller.hideEditIcons = hideEditIcons;
    controller.getGpx = (){
      return rawGpx;
    };
  }

  @override
  void initState() {
    currentColor1 = defaultColor1;
    currentColor2 = defaultColor2;
    backgroundColor = backgroundColor1;
    super.initState();
  }

  void _onMapCreated(MapLibreMapController contrl) async {
    mapController = contrl;
    // mapController!.onSymbolTapped.add(_onSymbolTapped);
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
    selectedNode = await searchSymbol(symbol.id);
    if (selectedNode == -1) return;
    edits.add((selectedNode, cloneWpt(rawGpx[selectedNode]), 'delete'));
    nodes.removeAt(selectedNode);
    gpxCoords.removeAt(selectedNode);
    rawGpx.removeAt(selectedNode);
    await mapController!.removeSymbol(mapSymbols[selectedNode]);
    mapSymbols.removeAt(selectedNode);
    updateTrackLine();
    setState(() {});
  }

  void _onNodeDrag(id,
      {required current,
      required delta,
      required origin,
      required point,
      required eventType}) async {
    // if (selectedNode == -1) return;

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
        String image = 'nodes-box';
        if (draggableMode) {
          image = 'draggable-box';
        }
        _updateSelectedSymbol(
          selectedSymbol!,
          SymbolOptions(
              geometry: coord, draggable: draggableMode, iconImage: image),
        );

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

  List<SymbolOptions> makeSymbolOptions(nodes, image, draggable) {
    final symbolOptions = <SymbolOptions>[];
    
    for (var idx = 0; idx < nodes.length; idx++) {
      LatLng coord = nodes[idx];
      symbolOptions.add(SymbolOptions(
          draggable: draggable, iconImage: image, geometry: coord, textAnchor: idx.toString()));
    }

    return symbolOptions;
  }

  Future<List<Symbol>> addMapSymbols(draggable, image) async {
    mapSymbols =
        await mapController!.addSymbols(makeSymbolOptions(nodes, image, draggable));
    return mapSymbols;
  }

  Future <List> removeMapSymbols() async {
    await mapController!.removeSymbols(mapSymbols);
    mapSymbols = [];
    return mapSymbols;
  }

  void resetMapSymbols() {
    removeMapSymbols();
    addMapSymbols(draggableMode, 'plain-node');
  }

  @override
  void dispose() {
    mapController!.onFeatureDrag.remove(_onNodeDrag);
    super.dispose();
  }

  Future<Line?> loadTrack(trackSegment) async {
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

    return trackLine;
  }

  void resetTrackLine() {
    if (trackLine != null) {
      mapController!.removeLine(trackLine!);
      if (editMode) {
        editMode = false;
        removeMapSymbols();
      }
    }
    editMode = false;
    nodes = [];
    mapSymbols = [];
    gpxCoords = [];
    rawGpx = [];
    edits = [];
  }

  void showEditIcons(){
    showTools = true;
    setState(() {});
  }

  void hideEditIcons(){
    showTools = false;
    setState(() {});
  }


  void undoDelete(idx, wpt) async {
    rawGpx.insert(idx, wpt);

    LatLng latlon = LatLng(wpt.lat, wpt.lon);
    gpxCoords.insert(idx, latlon);
    nodes.insert(idx, latlon);
    updateTrackLine();
    resetMapSymbols();
  }

  void undoMove(idx, wpt) async {
    rawGpx[idx] = wpt;
    LatLng latlon = LatLng(wpt.lat, wpt.lon);
    nodes[idx] = latlon;
    gpxCoords[idx] = latlon;
    updateTrackLine();
    String image = 'node-box';
    if (draggableMode) {
      image = 'draggable-box';
    }
    _updateSelectedSymbol(
      mapSymbols[idx]!,
      SymbolOptions(draggable: draggableMode, iconImage: image, geometry: latlon),
    );
  }

  void undo() async {
    if (edits.isEmpty) {
      return;
    }

    var (idx, wpt, type) = edits.removeLast();
    
    switch (type) {
      case 'moved':
        undoMove(idx, wpt);
        break;
      case 'delete':
        undoDelete(idx, wpt);
        break;
    }

    if (edits.isEmpty) {
      setState(() {});
    }    
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
              mapController!, "node-plain", "assets/symbols/node-plain.png");
          addImageFromAsset(
              mapController!, "node-drag", "assets/symbols/node-drag.png");
          addImageFromAsset(
              mapController!, "node-delete", "assets/symbols/node-delete.png");
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
                      onTap: () async {
                        await removeMapSymbols();
                        deleteMode = false;
                        draggableMode = !draggableMode;
                        currentColor1 = defaultColor1;
                        currentColor2 = defaultColor2;
                        backgroundColor = backgroundColor1;

                        if(draggableMode){
                          currentColor1 = activeColor1;
                          currentColor2 = activeColor2;
                          backgroundColor = backgroundColor2;
                          await addMapSymbols(draggableMode, 'node-drag');
                        } else{
                          await addMapSymbols(draggableMode, 'node-plain');
                        }
                        
                        setState(() {});
                      },
                      child: CircleAvatar(
                        backgroundColor: backgroundColor,
                        child: MoveIcon(color1: currentColor1!, color2: currentColor2!),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(4.0),
                    ),
                    GestureDetector(
                      onTap: () {
                        draggableMode = false;
                        removeMapSymbols();
                        deleteMode = !deleteMode;
                        if (deleteMode){
                          addMapSymbols(draggableMode, 'node-delete');
                          mapController!.onSymbolTapped.add(_onSymbolTapped);
                        } else {
                          addMapSymbols(draggableMode, 'node-plain');
                          mapController?.onSymbolTapped.remove(_onSymbolTapped);
                        }
                      },
                      child: const CircleAvatar(
                        backgroundColor: Colors.white,
                        child: DeleteIcon(),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(4.0),
                    ),
                    ...[edits.isNotEmpty ? GestureDetector(
                      onTap: () {
                        undo();
                      },
                      child: const CircleAvatar(
                        backgroundColor: Colors.white,
                        child: UndoIcon(),
                      ),
                    ) : Container()],
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
