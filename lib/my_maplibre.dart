import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geoxml/geoxml.dart';
import 'controller.dart';
import 'move_icon.dart';
import 'delete_icon.dart';
import 'add_icon.dart';
import 'undo_icon.dart';
import 'package:throttling/throttling.dart';
import 'util.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'classes/track.dart';

class MyMapLibre extends StatefulWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final Controller controller;

  const MyMapLibre({
    Key? key,
    required this.scaffoldKey,
    required this.controller,
  }) : super(key: key);

  @override
  State<MyMapLibre> createState() => _MyMaplibreState(controller);
}

class _MyMaplibreState extends State<MyMapLibre> {
  Track? track;
  Map<String, bool> mapTools = {
    'move': false,
    'add': false,
    'delete': false,
  };

  double trackWidth = 3;
  Color trackColor = Colors.pink; // Selects a mid-range green.
  Color defaultColorIcon1 = Colors.grey; // Selects a mid-range green.
  Color defaultColorIcon2 = Colors.grey; // Selects a mid-range green.

  Color activeColor1 = Colors.grey; // Selects a mid-range green.
  Color activeColor2 = Colors.white; // Selects a mid-range green.

  Color? backgroundActive;
  Color backgroundInactive = Colors.white;

  Color? colorIcon1;
  Color? colorIcon2;
  Color? backgroundColor;

  MapLibreMapController? mapController;

  Line? trackLine;
  List<Symbol> mapSymbols =
      []; //Symbols on map to allow dragging the existing NODES of the gpx track

  bool editMode = true;

  List<(int, Wpt, String)> edits = [];

  String? filename;
  String? fileName;

  bool gpxLoaded = false;
  bool showTools = false;
  // bool draggableMode = false;
  // bool addMode = false;
  // bool deleteMode = false;

  Symbol? selectedSymbol;

  int selectedNode = -1;
  String selectedNodeType = '';

  final thr = Throttling<void>(duration: const Duration(milliseconds: 200));
  final deb = Debouncing<void>(duration: const Duration(milliseconds: 200));

  _MyMaplibreState(Controller controller) {
    controller.loadTrack = loadTrack;
    controller.removeTrackLine = removeTrackLine;
    controller.addMapSymbols = addMapSymbols;
    controller.removeMapSymbols = removeMapSymbols;
    controller.showEditIcons = showEditIcons;
    controller.hideEditIcons = hideEditIcons;
    controller.updateTrack = updateTrack;
    controller.getEditMode = getEditMode;
    controller.getGpx = () {
      return track!.getTrack();
    };
  }

  @override
  void initState() {
    colorIcon1 = defaultColorIcon1;
    colorIcon2 = defaultColorIcon2;
    backgroundColor = backgroundInactive;
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      backgroundActive = Theme.of(context).canvasColor;
    });
  }

  void deactivateTools() {
    for (String tool in mapTools.keys) {
      mapTools[tool] = false;
    }
  }

  void activateTool(tool) {
    deactivateTools();
    mapTools[tool] = true;
  }

  void toggleTool(tool) {
    for (String ktool in mapTools.keys) {
      if (ktool == tool) {
        mapTools[tool] = !mapTools[tool]!;
      } else {
        mapTools[ktool] = false;
      }
    }
  }

  bool getEditMode() {
    return editMode;
  }

  void _onMapCreated(MapLibreMapController contrl) async {
    mapController = contrl;
    // mapController!.onSymbolTapped.add(_onSymbolTapped);
    // mapController!.onFeatureDrag.add(_onNodeDrag);
  }

  void addNode(point, clickedPoint) async {
    if (track!.getCoordsList().isEmpty || !mapTools['add']!) return;
    var (dist, position, P) = track!.getCandidateNode(clickedPoint);

    if (dist < 20) {
      Symbol added = await mapController!.addSymbol(SymbolOptions(
          draggable: false, iconImage: 'node-plain', geometry: P));

      mapSymbols.insert(position + 1, added);

      Wpt newWpt = cloneWpt(halfSegmentWpt(
          track!.trackSegment[position], track!.trackSegment[position + 1]));
      newWpt.lat = P.latitude;
      newWpt.lon = P.longitude;
      edits.add((position + 1, newWpt, 'add'));

      track!.addNode(position, newWpt);

      updateTrackLine();
      resetMapSymbols();
      setState(() {});
    } else {
      // Show snalbar message
      showSnackBar(context, AppLocalizations.of(context)!.nodeToAddIsToFar);
    }
  }

  void _onSymbolTapped(Symbol symbol) async {
    selectedNode = await searchSymbol(symbol.id);

    if (selectedNode == -1) return;

    edits.add(
        (selectedNode, cloneWpt(track!.trackSegment[selectedNode]), 'delete'));

    track!.removeNode(selectedNode);

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
        edits.add((
          selectedNode,
          cloneWpt(track!.trackSegment[selectedNode]),
          'moved'
        ));
        break;
      case DragEventType.drag:
        thr.throttle(() {
          track!.changeNodeAt(
              selectedNode, LatLng(current.latitude, current.longitude));
          updateTrackLine();
        });
        break;
      case DragEventType.end:
        LatLng coordinate = LatLng(current.latitude, current.longitude);
        track!.changeNodeAt(selectedNode, coordinate);

        Wpt dragged = track!.getWptAt(selectedNode);
        dragged.lat = coordinate.latitude;
        dragged.lon = coordinate.longitude;
        track!.setWptAt(selectedNode, dragged);

        updateTrackLine();
        resetMapSymbols();
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
        .updateLine(trackLine!, LineOptions(geometry: track!.getCoordsList()));
    // setState(() {});
  }

  String getNodesImage(tools) {
    if (tools['move']) return 'node-drag';
    if (tools['add']) return 'node-plain';
    if (tools['delete']) return 'node-delete';
    return 'node-plain';
  }

  List<SymbolOptions> makeSymbolOptions() {
    final symbolOptions = <SymbolOptions>[];
    String image = getNodesImage(mapTools);
    bool draggable = mapTools['move']! ? true : false;
    List<LatLng> nodes = track!.getCoordsList();

    for (var idx = 0; idx < nodes.length; idx++) {
      LatLng coord = nodes[idx];
      symbolOptions.add(SymbolOptions(
          draggable: draggable,
          iconImage: image,
          geometry: coord,
          textAnchor: idx.toString()));
    }

    return symbolOptions;
  }

  Future<List<Symbol>> addMapSymbols() async {
    mapSymbols = await mapController!.addSymbols(makeSymbolOptions());
    return mapSymbols;
  }

  Future<List> removeMapSymbols() async {
    await mapController!.removeSymbols(mapSymbols);
    mapSymbols = [];
    return mapSymbols;
  }

  void resetMapSymbols() async {
    await removeMapSymbols();
    await addMapSymbols();
  }

  @override
  void dispose() {
    if (mapController!.onFeatureDrag.isNotEmpty) {
      mapController!.onFeatureDrag.remove(_onNodeDrag);
    }
    super.dispose();
  }

  Future<void> updateTrack(changes) async {
    await mapController!.updateLine(trackLine!, changes);
  }

  Future<Line?> loadTrack(trackSegment) async {
    deactivateTools();
    showTools = false;
    if (trackLine != null) {
      removeTrackLine();
      removeMapSymbols();
      mapSymbols = [];
      edits = [];
      track!.reset();
      setState(() {});
    }
    track = Track(trackSegment);

    await track!.init();

    mapController!.moveCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: track!.getBounds().southEast,
          northeast: track!.getBounds().northWest,
        ),
        left: 10,
        top: 5,
        bottom: 25,
      ),
    );

    trackLine = await mapController!.addLine(
      LineOptions(
        geometry: track!.getCoordsList(),
        lineColor: trackColor.toHexStringRGB(),
        lineWidth: trackWidth,
        lineOpacity: 0.9,
      ),
    );

    return trackLine;
  }

  Future<void> removeTrackLine() async {
    print('*' * 60);
    if (trackLine != null) {
      print('remove TRACKLINE');
      mapController!.removeLine(trackLine!);
      if (editMode) {
        editMode = false;
      }
    }
    removeMapSymbols();
    editMode = false;

    mapSymbols = [];
    edits = [];
  }

  void showEditIcons() {
    showTools = true;
    setState(() {});
  }

  void hideEditIcons() {
    showTools = false;
    setState(() {});
  }

  void undoDelete(idx, wpt) async {
    track!.addWpt(idx, wpt);

    updateTrackLine();
    resetMapSymbols();
  }

  void undoAdd(idx, wpt) async {
    track!.removeWpt(idx, wpt);
    updateTrackLine();
    resetMapSymbols();
  }

  void undoMove(idx, wpt) async {
    track!.moveWpt(idx, wpt);

    updateTrackLine();
    resetMapSymbols();
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
      case 'add':
        undoAdd(idx, wpt);
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
        onMapClick: addNode,
        onStyleLoadedCallback: () {
          addImageFromAsset(
              mapController!, "node-plain", "assets/symbols/node-plain.png");
          addImageFromAsset(
              mapController!, "node-drag", "assets/symbols/node-drag.png");
          addImageFromAsset(
              mapController!, "node-delete", "assets/symbols/node-delete.png");
        },
        initialCameraPosition: const CameraPosition(
          target: LatLng(42.0, 3.0),
          zoom: 0,
        ),
        styleString:
            'https://geoserveis.icgc.cat/contextmaps/icgc_orto_hibrida.json',
      ),
      ...[
        showTools
            ? Positioned(
                right: 10,
                top: 10,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () async {
                        toggleTool('move');

                        colorIcon1 = defaultColorIcon1;
                        colorIcon2 = defaultColorIcon2;

                        if (mapTools['move']!) {
                          colorIcon1 = activeColor1;
                          colorIcon2 = activeColor2;
                          mapController!.onFeatureDrag.add(_onNodeDrag);
                        } else {
                          mapController!.onFeatureDrag.remove(_onNodeDrag);
                        }
                        resetMapSymbols();

                        setState(() {});
                      },
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor:
                            mapTools['move']! ? backgroundActive : Colors.white,
                        child: MoveIcon(
                          color1:
                              mapTools['move']! ? Colors.white : Colors.grey,
                          color2: const Color(0xffc5dd16),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(2.0),
                    ),
                    GestureDetector(
                      onTap: () async {
                        toggleTool('add');

                        colorIcon1 = defaultColorIcon1;
                        colorIcon2 = defaultColorIcon2;

                        if (mapTools['add']!) {
                          colorIcon1 = activeColor1;
                          colorIcon2 = activeColor2;
                        }

                        removeMapSymbols();
                        await addMapSymbols();
                        setState(() {});
                      },
                      child: CircleAvatar(
                        backgroundColor:
                            mapTools['add']! ? backgroundActive : Colors.white,
                        child: AddIcon(
                          color1: mapTools['add']! ? Colors.white : Colors.grey,
                          color2: const Color(0xffc5dd16),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(2.0),
                    ),
                    GestureDetector(
                      onTap: () {
                        removeMapSymbols();
                        toggleTool('delete');
                        if (mapTools['delete']!) {
                          mapController!.onSymbolTapped.add(_onSymbolTapped);
                        } else {
                          mapController?.onSymbolTapped.remove(_onSymbolTapped);
                        }
                        addMapSymbols();
                        setState(() {});
                      },
                      child: CircleAvatar(
                        backgroundColor: mapTools['delete']!
                            ? backgroundActive
                            : Colors.white,
                        child: DeleteIcon(
                          color1:
                              mapTools['delete']! ? Colors.white : Colors.grey,
                          color2: const Color(0xffc5dd16),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(4.0),
                    ),
                    ...[
                      edits.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                undo();
                              },
                              child: const CircleAvatar(
                                backgroundColor: Colors.white,
                                child: UndoIcon(),
                              ),
                            )
                          : Container()
                    ],
                  ],
                ),
              )
            : Container(),
      ],
    ]);
  }
}
