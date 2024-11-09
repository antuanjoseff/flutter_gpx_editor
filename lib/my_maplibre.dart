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
import 'utils/user_simple_preferences.dart';

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
    'addWayPoint': false
  };

  late TextEditingController controller;

  ButtonStyle styleElevatedButtons = ElevatedButton.styleFrom(
    minimumSize: Size.zero, // Set this
    padding:
        EdgeInsets.only(left: 20, right: 20, top: 5, bottom: 5), // and this
    backgroundColor: Colors.pink,
    foregroundColor: Colors.white,
  );

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
  List<Wpt> mapWayPoints = []; //Symbols to show track Way Points

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
    controller.updateTrack = updateTrack;
    controller.setEditMode = setEditMode;
    controller.getWpts = () {
      return track!.getWpts();
    };
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
    trackWidth = UserSimplePreferences.getTrackWidth() ?? trackWidth;
    trackColor = UserSimplePreferences.getTrackColor() ?? trackColor;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      backgroundActive = Theme.of(context).canvasColor;
    });
    controller = TextEditingController();
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

  void setEditMode(bool editmode) async {
    showTools = editmode;
    if (editmode) {
      mapSymbols = await addMapSymbols();
    } else {
      print('remove map symbols');
      mapSymbols = await removeMapSymbols();
    }
    setState(() {});
  }

  void _onMapCreated(MapLibreMapController contrl) async {
    mapController = contrl;
    // mapController!.onSymbolTapped.add(_onSymbolTapped);
    // mapController!.onFeatureDrag.add(_onNodeDrag);
  }

  void handleClick(point, clickedPoint) {
    if (mapTools['add']! && track!.getCoordsList().isNotEmpty) {
      addNode(point, clickedPoint);
      return;
    }

    if (mapTools['addWayPoint']! && track!.getCoordsList().isNotEmpty) {
      addWayPoint(point, clickedPoint);
      return;
    }
  }

  Future<String?> opentDialog() async {
    controller.text = "Waypoint ${mapWayPoints.length}";

    return await showDialog(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(AppLocalizations.of(context)!.wptName),
                content: TextField(
                  onTap: () => controller.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: controller.value.text.length),
                  autofocus: true,
                  // decoration: InputDecoration(hintText: 'Nom del track'),
                  controller: controller,
                  onSubmitted: (_) => submit(),
                ),
                actions: [
                  ElevatedButton(
                      style: styleElevatedButtons,
                      onPressed: submit,
                      child: Text(AppLocalizations.of(context)!.accept)),
                  ElevatedButton(
                      style: styleElevatedButtons,
                      onPressed: cancel,
                      child: Text(AppLocalizations.of(context)!.cancel)),
                ]));
  }

  void submit() {
    Navigator.of(context).pop(controller.text);
    controller.clear();
  }

  void cancel() {
    Navigator.of(context).pop();
  }

  void addWayPoint(point, clickedPoint) async {
    Symbol waypoint = await mapController!.addSymbol(SymbolOptions(
        draggable: false, iconImage: 'waypoint', geometry: clickedPoint));

    String? wptName = await opentDialog();

    if (wptName != null) {
      Wpt wpt = Wpt(
          lat: clickedPoint.latitude,
          lon: clickedPoint.longitude,
          name: wptName);
      mapWayPoints.add(wpt);
      track!.addWpt(wpt);

      edits.add((mapWayPoints.length - 1, wpt, 'addWaypoint'));

      // await resetMapWayPoints();
      setState(() {});
    } else {
      mapController!.removeSymbol(waypoint);
    }

    // // Show snalbar message
    // showSnackBar(context, AppLocalizations.of(context)!.nodeToAddIsToFar);
  }

  void addNode(point, clickedPoint) async {
    var (dist, position, P) = track!.getCandidateNode(clickedPoint);
    print(
        '############################################################3adding node ????');

    if (dist < 50) {
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
      await resetMapSymbols();
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
        await resetMapSymbols();
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
    print('................ADD MAP SYMBOLS');
    mapSymbols = await mapController!.addSymbols(makeSymbolOptions());
    return mapSymbols;
  }

  Future<List<Symbol>> removeMapSymbols() async {
    print('---------------REMOVE MAP SYMBOLS');
    await mapController!.removeSymbols(mapSymbols);
    mapSymbols = [];
    return mapSymbols;
  }

  Future<void> resetMapSymbols() async {
    mapSymbols = await removeMapSymbols();
    mapSymbols = await addMapSymbols();
  }

  @override
  void dispose() {
    controller.dispose();
    if (mapController!.onFeatureDrag.isNotEmpty) {
      mapController!.onFeatureDrag.remove(_onNodeDrag);
    }
    super.dispose();
  }

  Future<void> updateTrack(changes) async {
    await mapController!.updateLine(trackLine!, changes);
  }

  Future<Line?> loadTrack(List<Wpt> trackSegment) async {
    deactivateTools();
    showTools = false;
    if (trackLine != null) {
      removeTrackLine();
      mapSymbols = await removeMapSymbols();
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

  void undoDelete(idx, wpt) async {
    track!.addTrkpt(idx, wpt);

    updateTrackLine();
    resetMapSymbols();
  }

  void undoAdd(idx, wpt) async {
    track!.removeTrkpt(idx, wpt);
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
          onMapClick: handleClick,
          onStyleLoadedCallback: () {
            addImageFromAsset(
                mapController!, "node-plain", "assets/symbols/node-plain.png");
            addImageFromAsset(
                mapController!, "node-drag", "assets/symbols/node-drag.png");
            addImageFromAsset(mapController!, "node-delete",
                "assets/symbols/node-delete.png");
            addImageFromAsset(
                mapController!, "waypoint", "assets/symbols/waypoint.png");
          },
          initialCameraPosition: const CameraPosition(
            target: LatLng(42.0, 3.0),
            zoom: 0,
          ),
          styleString:
              'https://geoserveis.icgc.cat/contextmaps/icgc_orto_hibrida.json'),
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
                        radius: 25,
                        backgroundColor:
                            mapTools['move']! ? backgroundActive : Colors.white,
                        child: MoveIcon(
                          color1:
                              mapTools['move']! ? Colors.white : Colors.grey,
                          color2: const Color(0xffc5dd16),
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 4,
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

                        resetMapSymbols();
                        setState(() {});
                      },
                      child: CircleAvatar(
                        radius: 25,
                        backgroundColor:
                            mapTools['add']! ? backgroundActive : Colors.white,
                        child: AddIcon(
                          color1: mapTools['add']! ? Colors.white : Colors.grey,
                          color2: const Color(0xffc5dd16),
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    GestureDetector(
                      onTap: () async {
                        toggleTool('delete');
                        if (mapTools['delete']!) {
                          mapController!.onSymbolTapped.add(_onSymbolTapped);
                        } else {
                          mapController?.onSymbolTapped.remove(_onSymbolTapped);
                        }
                        await resetMapSymbols();
                        setState(() {});
                      },
                      child: CircleAvatar(
                        radius: 25,
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
                    const SizedBox(
                      height: 4,
                    ),
                    GestureDetector(
                      onTap: () {
                        toggleTool('addWayPoint');
                        setState(() {});
                      },
                      child: CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.flag,
                          color: mapTools['addWayPoint']!
                              ? Theme.of(context).canvasColor
                              : Colors.grey,
                          size: 35,
                        ),
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    ...[
                      edits.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                undo();
                              },
                              child: const CircleAvatar(
                                radius: 25,
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
