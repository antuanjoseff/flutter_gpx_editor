import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gpx_editor/vars/vars.dart';
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
import 'dart:async';
import 'package:flutter_svg_icons/flutter_svg_icons.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'dart:async' show Future;
import 'package:flutter/services.dart' show rootBundle;
import 'expandedSection.dart';
import './widgets/selectPointFromMapCenter.dart';
import './pages/TrackInfo.dart';
import 'dart:math' as math;

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

class _MyMaplibreState extends State<MyMapLibre>
    with SingleTickerProviderStateMixin {
  Track? track;
  Map<String, bool> editTools = {
    'move': false,
    'add': false,
    'delete': false,
    'addWayPoint': false
  };

  // var to know average distance between track nodes
  double nodesRatio = 0;
  bool showBottomPanel = false;

  late TextEditingController textcontroller;

  ButtonStyle styleElevatedButtons = ElevatedButton.styleFrom(
    minimumSize: Size.zero, // Set this
    padding:
        EdgeInsets.only(left: 20, right: 20, top: 15, bottom: 15), // and this
    backgroundColor: primaryColor,
    foregroundColor: white,
  );

  ButtonStyle buttonNoPadding = ElevatedButton.styleFrom(
    minimumSize: Size.zero, // Set this
    padding: EdgeInsets.only(left: 2, right: 2, top: 2, bottom: 2), // and this
    backgroundColor: primaryColor,
    foregroundColor: white,
  );

  // INFO TRACK VARIABLES
  int startSegmentPoint = -1;
  int endSegmentPoint = -1;

  double trackWidth = 4;
  Color trackColor = primaryColor; // Selects a mid-range green.
  Color defaultColorIcon1 = inactiveColor; // Selects a mid-range green.
  Color defaultColorIcon2 = inactiveColor; // Selects a mid-range green.

  Color activeColor1 = inactiveColor; // Selects a mid-range green.
  Color activeColor2 = white; // Selects a mid-range green.

  Color? backgroundActive;
  Color backgroundInactive = white;

  Color? colorIcon1;
  Color? colorIcon2;
  Color? backgroundColor;

  MapLibreMapController? mapController;

  Line? trackLine;
  Line? queryLine;
  Symbol? startpoint;
  Symbol? endpoint;
  Symbol? shownode;
  List<Wpt> queryWpts = [];
  Track? queryTrack;
  List<Symbol> nodeSymbols =
      []; //Symbols on map to allow dragging the existing NODES of the gpx track
  List<Symbol> manipulatedSymbols = [];
  Map<String, Symbol> dictSymbols = {};
  Map<String, Symbol> dictManipulatedSymbols = {};
  List<int> manipulatedIndexes =
      []; //indexes of nodes in track coordinates that have been manipulated.

  List<Symbol> wptSymbols = [];
  List<Wpt> mapWayPoints = []; //Gpx WPTS

  bool infoMode = false;
  bool showChart = true;
  double arrowRotation = 0;
  bool editMode = false;
  bool disableMapChanged = false;

  List<(int, Wpt, String)> edits = [];

  String? filename;
  String? fileName;

  late Stopwatch stopwatch;
  String mapStyle = 'assets/styles/orto_style.json';

  bool trackLoaded = false;
  bool ortoVisible = true;
  bool clickPaused = false;
  bool gpxLoaded = false;
  bool showTools = false;
  int prevZoom = 0;
  Symbol? selectedSymbol;

  int selectedNode = -1;
  String selectedNodeType = '';

  // Chart Variables
  late double minY2;
  late double maxY2;
  late double minY;
  late double maxY;

  final thr = Throttling<void>(duration: const Duration(milliseconds: 100));
  final deb = Debouncing<void>(duration: const Duration(milliseconds: 200));

  _MyMaplibreState(Controller controller) {
    controller.loadTrack = loadTrack;
    controller.removeTrackLine = removeTrackLine;
    controller.addNodeSymbols = addNodeSymbols;
    controller.removeNodeSymbols = removeNodeSymbols;
    controller.updateTrack = updateTrack;
    controller.setEditMode = setEditMode;
    controller.setBaseLayer = setBaseLayer;
    controller.getCenter = getCenter;
    controller.getZoom = getZoom;
    controller.showNode = showNode;
    controller.showDialogSaveFile = showDialogSaveFile;
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

    trackWidth = UserSimplePreferences.getTrackWidth() ?? trackWidth;
    trackColor = UserSimplePreferences.getTrackColor() ?? trackColor;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      backgroundActive = Theme.of(context).canvasColor;
    });
    textcontroller = TextEditingController();
    super.initState();
  }

  void deactivateTools() {
    for (String tool in editTools.keys) {
      editTools[tool] = false;
      removeNodeSymbols();
    }
  }

  void activateTool(tool) {
    deactivateTools();
    editTools[tool] = true;
  }

  bool isAnyNodesToolActive() {
    for (String kTool in editTools.keys) {
      if (editTools[kTool] == true && kTool != 'addWayPoint') {
        return true;
      }
    }
    return false;
  }

  void toggleTool(tool) async {
    clickPaused = true;
    for (String ktool in editTools.keys) {
      if (ktool == tool) {
        editTools[tool] = !editTools[tool]!;
      } else {
        editTools[ktool] = false;
      }
    }
    await mapController!.setSymbolIconAllowOverlap(true);

    var timer = Timer(Duration(seconds: 1), () {
      clickPaused = false;
    });
  }

  void setEditMode(bool editmode) async {
    showTools = editmode;
    if (!editmode) {
      await removeNodeSymbols();
    }
    setState(() {});
  }

  void _onMapCreated(MapLibreMapController contrl) async {
    mapController = contrl;
    mapController!.addListener(_onMapChanged);
    mapController!.onSymbolTapped.add(_onSymbolTapped);
    mapController!.onFeatureDrag.add(_onNodeDrag);
    await mapController!.setSymbolIconAllowOverlap(true);
    // if (!kIsWeb) {
    //   await mapController!.setSymbolIconAllowOverlap(false);
    // }
  }

  LatLng getCenter() {
    return mapController!.cameraPosition!.target;
  }

  double getZoom() {
    return mapController!.cameraPosition!.zoom;
  }

  void showNode(location) async {
    if (shownode == null) {
      shownode = await mapController!.addSymbol(SymbolOptions(
          draggable: false,
          iconImage: 'current-selection',
          geometry: location,
          iconOffset: kIsWeb ? Offset(0, 0) : Offset(0, 0)));
    } else {
      _updateSelectedSymbol(
          shownode!,
          SymbolOptions(
              geometry: location,
              iconImage: 'current-selection',
              draggable: false));
    }
  }

  void _onMapChanged() async {
    if (disableMapChanged) return;

    int zoom = mapController!.cameraPosition!.zoom.floor();

    if (isAnyNodesToolActive()) {
      // after last map changed, wait 300ms and redraw nodes
      deb.debounce(() async {
        disableMapChanged = true;
        await redrawNodeSymbols();
        disableMapChanged = false;
      });
    }
  }

  bool isMoveNodeActive() {
    return editTools['move']!;
  }

  bool isDeleteActive() {
    return editTools['delete']!;
  }

  bool isAddWayPointActive() {
    return editTools['addWayPoint']!;
  }

  void _onSymbolTapped(Symbol symbol) async {
    var (type, nodeAndSymbolPosition) = await searchSymbol(symbol.id);

    if (type == 'waypoint') {
      // then user tapped on a wpt
      tappedOnWpt(symbol, nodeAndSymbolPosition['symbol']!);
      return;
    }

    // Only when these tools are activated
    if (!isDeleteActive() && !isAddWayPointActive()) {
      return;
    }

    edits.add(
        (selectedNode, cloneWpt(track!.trackSegment[selectedNode]), 'delete'));

    track!.removeNode(selectedNode);
    await mapController!
        .removeSymbol(nodeSymbols[nodeAndSymbolPosition['symbol']!]);
    nodeSymbols.removeAt(nodeAndSymbolPosition['node']!);

    // todo increase all manipulatedindexes greatar than just deleted node
    manipulatedIndexes =
        updateManipulatedIndexes('delete', selectedNode, manipulatedIndexes);
    redrawNodeSymbols();
    updateTrackLine();
    setState(() {});
  }

  List<int> updateManipulatedIndexes(
      String action, int updatedIdx, List<int> indexes) {
    for (int i = 0; i < indexes.length; i++) {
      int val = indexes[i];
      if (val == updatedIdx && action == 'delete') {
        indexes.removeAt(val);
      } else {
        if (updatedIdx < val && action == 'delete') {
          indexes[i] -= 1;
        } else {
          if (action == 'add' && val > updatedIdx) {
            indexes[i] += 1;
          }
        }
      }
    }
    return indexes;
  }

  void tappedOnWpt(Symbol search, int idx) async {
    if (idx != -1) {
      var (action, wptName) = await openDialogEditWpt(mapWayPoints[idx]);
      if (action == 'edit' && wptName != mapWayPoints[idx].name) {
        edits.add((idx, cloneWpt(mapWayPoints[idx]), 'editWaypoint'));
        mapWayPoints[idx].name = wptName;
      } else {
        if (action == 'delete') {
          edits.add((idx, cloneWpt(mapWayPoints[idx]), 'deleteWaypoint'));
          mapWayPoints.removeAt(idx);
          mapController!.removeSymbol(wptSymbols[idx]);
          wptSymbols.removeAt(idx);
          track!.removeWpt(idx);
        }
      }
    }

    setState(() {});
  }

  void setBaseLayer(layer) {
    if (layer == 'orto') {
      ortoVisible = true;
    } else {
      ortoVisible = false;
    }
    mapController!.setLayerProperties(
        "osm",
        LineLayerProperties.fromJson(
            {"visibility": !ortoVisible ? "visible" : "none"}));
    mapController!.setLayerProperties(
        "ortoEsri",
        LineLayerProperties.fromJson(
            {"visibility": ortoVisible ? "visible" : "none"}));
    mapController!.setLayerProperties(
        "ortoICGC",
        LineLayerProperties.fromJson(
            {"visibility": ortoVisible ? "visible" : "none"}));
  }

  void handleClick(point, clickedPoint) async {
    if (clickPaused) {
      return;
    }
    // if (editTools['add']! && track!.getCoordsList().isNotEmpty) {
    //   addNode(clickedPoint);
    //   return;
    // }

    if (editTools['addWayPoint']! && track!.getCoordsList().isNotEmpty) {
      addWayPoint(point, clickedPoint);
      return;
    }
  }

  Future<(String?, String?)> showDialogSaveFile(String value) async {
    return await openDialogInputText(value);
  }

  Future<(String?, String?)> openDialogInputText(String value) async {
    textcontroller.text = value;
    clickPaused = true;
    return await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
                title: Text(AppLocalizations.of(context)!.wptName),
                content: TextField(
                  onTap: () => textcontroller.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: textcontroller.value.text.length),
                  autofocus: true,
                  // decoration: InputDecoration(hintText: 'Nom del track'),
                  controller: textcontroller,
                  onSubmitted: (_) => submit('add'),
                ),
                actions: [
                  ElevatedButton(
                      style: styleElevatedButtons,
                      onPressed: () {
                        submit('add');
                      },
                      child: Text(AppLocalizations.of(context)!.accept)),
                  ElevatedButton(
                      style: styleElevatedButtons,
                      onPressed: cancel,
                      child: Text(AppLocalizations.of(context)!.cancel)),
                ]));
  }

  Future<(String?, String?)> openDialogEditWpt(Wpt wpt) async {
    textcontroller.text = "${wpt.name}";
    clickPaused = true;
    return await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(AppLocalizations.of(context)!.editWpt),
                    GestureDetector(
                      onTap: () async {
                        bool confirm = await openDialogConfirmWpt();
                        if (confirm) {
                          deleteWpt(wpt);
                        }
                        editMode = !editMode;
                        setEditMode(editMode);
                      },
                      child: Icon(Icons.delete,
                          size: 35, color: Theme.of(context).canvasColor),
                    ),
                  ],
                ),
                content: TextField(
                  onTap: () => textcontroller.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: textcontroller.value.text.length),
                  autofocus: true,
                  // decoration: InputDecoration(hintText: 'Nom del track'),
                  controller: textcontroller,
                  onSubmitted: (_) => submit('edit'),
                ),
                actions: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                          style: styleElevatedButtons,
                          onPressed: () {
                            submit('edit');
                          },
                          child: Icon(Icons.check)),
                      // child: Text(AppLocalizations.of(context)!.accept)),
                      SizedBox(width: 20),
                      ElevatedButton(
                          style: styleElevatedButtons,
                          onPressed: cancel,
                          child: Icon(Icons.cancel)
                          // child: Text(AppLocalizations.of(context)!.cancel)
                          ),
                    ],
                  )
                ]));
  }

  Future<bool> openDialogConfirmWpt() async {
    clickPaused = true;
    return await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
                title: Text(AppLocalizations.of(context)!.confirmDeleteWpt),
                actions: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                          style: styleElevatedButtons,
                          onPressed: () {
                            var timer = Timer(Duration(milliseconds: 300), () {
                              Navigator.of(context).pop(true);
                              setState(() {});
                            });
                          },
                          child: Text(AppLocalizations.of(context)!.yes)),
                      SizedBox(width: 20),
                      ElevatedButton(
                          style: styleElevatedButtons,
                          onPressed: () {
                            var timer = Timer(Duration(milliseconds: 300), () {
                              Navigator.of(context).pop(false);
                              setState(() {});
                            });
                          },
                          child: Text(AppLocalizations.of(context)!.no)),
                    ],
                  )
                ]));
  }

  void deleteWpt(Wpt wpt) {
    var timer = Timer(Duration(milliseconds: 300), () {
      clickPaused = false;
      Navigator.of(context).pop((
        'delete',
        wpt.extensions['id'],
      ));
      textcontroller.clear();
    });
  }

  void submit(String action) {
    var timer = Timer(Duration(milliseconds: 300), () {
      clickPaused = false;
      Navigator.of(context).pop((
        action,
        textcontroller.text,
      ));
      textcontroller.clear();
    });
  }

  void cancel() {
    var timer = Timer(Duration(milliseconds: 300), () {
      clickPaused = false;
      Navigator.of(context).pop((
        'cancel',
        null,
      ));
      textcontroller.clear();
    });
  }

  void addWayPoint(point, clickedPoint) async {
    Symbol wptSymbol = await mapController!.addSymbol(SymbolOptions(
        draggable: false,
        iconImage: 'waypoint',
        geometry: clickedPoint,
        iconOffset: kIsWeb ? Offset(5, -28) : Offset(0, -25)));

    var (action, wptName) =
        await openDialogInputText("Waypoint ${mapWayPoints.length}");

    if (wptName != null) {
      Wpt wpt = Wpt(
          lat: clickedPoint.latitude,
          lon: clickedPoint.longitude,
          name: wptName,
          extensions: {"id": wptSymbol.id});

      mapWayPoints.add(wpt);
      track!.addWpt(wpt);

      wptSymbols.add(wptSymbol);
      edits.add((mapWayPoints.length - 1, wpt, 'addWaypoint'));

      // await resetMapWayPoints();
      setState(() {});
    } else {
      mapController!.removeSymbol(wptSymbol);
    }

    // // Show snalbar message
    // showSnackBar(context, AppLocalizations.of(context)!.nodeToAddIsTooFar);
  }

  Future<bool> addNode(distance, nodeIdx, candidate) async {
    // var (dist, nodeIdx, P) = track!.getCandidateNode(candidate);

    if (distance < 50) {
      Symbol added = await mapController!.addSymbol(SymbolOptions(
          draggable: false, iconImage: 'node-plain', geometry: candidate));

      nodeSymbols.insert(nodeIdx + 1, added);

      Wpt newWpt = cloneWpt(halfSegmentWpt(
          track!.trackSegment[nodeIdx], track!.trackSegment[nodeIdx + 1]));
      newWpt.lat = candidate.latitude;
      newWpt.lon = candidate.longitude;
      edits.add((nodeIdx + 1, newWpt, 'add'));

      track!.addNode(nodeIdx, newWpt);
      manipulatedIndexes.add(nodeIdx);
      manipulatedIndexes =
          updateManipulatedIndexes('add', nodeIdx, manipulatedIndexes);

      updateTrackLine();
      await redrawNodeSymbols();
      // setState(() {});
      return true;
    } else {
      // Show snackbar message
      snackbar(
          context,
          Icon(Icons.warning),
          secondColor,
          Text(
            AppLocalizations.of(context)!.nodeToAddIsTooFar,
            style: TextStyle(color: white),
          ),
          Duration(seconds: 2));
      return false;
    }
  }

  void snackbar(
      context, Icon icon, Color color, Text myText, Duration duration) {
    // Close previous snackbar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Flexible(child: myText)],
            ),
            const SizedBox(
              height: 10,
            ),
          ],
        ),
        backgroundColor: color,
        duration: duration,
      ),
    );
  }

  void _onNodeDrag(id,
      {required current,
      required delta,
      required origin,
      required point,
      required eventType}) async {
    // if (!isMoveNodeActive()) return;

    switch (eventType) {
      case DragEventType.start:
        var (type, nodeAndSymbolPosition) = await searchSymbol(id);

        selectedNode = nodeAndSymbolPosition['node']!;
        if (type != 'node') return;

        selectedSymbol = nodeSymbols[nodeAndSymbolPosition['symbol']!];

        break;
      case DragEventType.drag:
        thr.throttle(() {
          track!.changeNodeAt(
              selectedNode, LatLng(current.latitude, current.longitude));
          updateTrackLine();
        });

        break;
      case DragEventType.end:
        edits.add((
          selectedNode,
          cloneWpt(track!.trackSegment[selectedNode]),
          'moved'
        ));
        LatLng coordinate = LatLng(current.latitude, current.longitude);
        track!.changeNodeAt(selectedNode, coordinate);
        Wpt dragged = track!.getWptAt(selectedNode);
        dragged.lat = coordinate.latitude;
        dragged.lon = coordinate.longitude;
        track!.setWptAt(selectedNode, dragged);
        if (!manipulatedIndexes.contains(selectedNode)) {
          manipulatedIndexes.add(selectedNode);
        }
        updateTrackLine();
        await redrawNodeSymbols();
        setState(() {});

        break;
    }
  }

  void _onSegmentMarkerDrag(id,
      {required current,
      required delta,
      required origin,
      required point,
      required eventType}) async {
    // if (!isMoveNodeActive()) return;

    switch (eventType) {
      case DragEventType.end:
        newSegmentPoint(id, current);
        break;
    }
  }

  void newSegmentPoint(String id, LatLng location) async {
    int idx = await track!.getClosestNodeFrom(location);

    if (startpoint!.id == id) {
      startSegmentPoint = idx;
      _updateSelectedSymbol(
        startpoint!,
        SymbolOptions(
            geometry: track!.getNode(idx),
            iconImage: 'startpoint-marker',
            draggable: true),
      );
    } else {
      endSegmentPoint = idx;
      _updateSelectedSymbol(
        endpoint!,
        SymbolOptions(
            geometry: track!.getNode(idx),
            iconImage: 'endpoint-marker',
            draggable: true),
      );
    }

    if (startSegmentPoint != -1 && endSegmentPoint != -1) {
      if (startSegmentPoint > endSegmentPoint) {
        int tmp = startSegmentPoint;
        startSegmentPoint = endSegmentPoint;
        endSegmentPoint = tmp;
      }
      addQueryLine(startSegmentPoint, endSegmentPoint);
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

  // Returns the symbol type (waypoint symbol or node symbol)
  // and the symbold idx position among symbols
  // if the found symbol is a node symbol, then also returns
  // the idx position of the track coordinate associated to the symbol

  Future<(String, Map<String, int>)> searchSymbol(String search) async {
    late LatLng geom;

    int idx = -1;
    for (var i = 0; idx == -1 && i < wptSymbols.length; i++) {
      if (search == wptSymbols[i].id) {
        idx = i;
        return ('waypoint', {'waypoint': idx, 'node': -1});
      }
    }
    //If not found, then search in nodeSymbols
    for (var i = 0; i < nodeSymbols.length; i++) {
      if (nodeSymbols[i].id == search) {
        geom = LatLng(nodeSymbols[i].options.geometry!.latitude,
            nodeSymbols[i].options.geometry!.longitude);

        List<LatLng> coords = track!.getCoordsList();
        late LatLng coord;

        for (var y = 0; y < coords.length; y++) {
          coord = coords[y];
          if (coord.latitude == geom.latitude &&
              coord.longitude == geom.longitude) {
            return ('node', {'node': y, 'symbol': i});
          }
        }
      }
    }
    return ('', {'node': -1, 'symbol': -1});
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

  bool nodeInManipulatedIndexes(int searchIdx) {
    for (int i = 0; i < manipulatedIndexes.length; i++) {
      if (manipulatedIndexes.contains(searchIdx)) {
        return true;
      }
    }
    return false;
  }

  Future<List<SymbolOptions>> makeSymbolOptions(List<LatLng> nodes) async {
    String image = getNodesImage(editTools);
    bool draggable = editTools['move']! ? true : false;

    // var used to calculate number of pixels between track nodes
    int symbolsPadding = 0;

    // if (kIsWeb) {
    if (mapController!.cameraPosition!.zoom.floor() > 17) {
      symbolsPadding = 1;
    } else {
      double resolution = await mapController!.getMetersPerPixelAtLatitude(
          mapController!.cameraPosition!.target.latitude);

      symbolsPadding = ((40 * resolution) / nodesRatio).floor();
    }

    final symbolOptions = <SymbolOptions>[];
    for (var idx = 0; idx < nodes.length; idx++) {
      LatLng coord = nodes[idx];

      if (idx % symbolsPadding != 0 && !nodeInManipulatedIndexes(idx)) {
        continue;
      }

      // if (!await coordInMapControllerView(coord, mapController)) {
      //   continue;
      // }

      symbolOptions.add(SymbolOptions(
          draggable: draggable,
          iconImage: image,
          geometry: coord,
          zIndex: idx,
          textAnchor: idx.toString()));
    }

    return symbolOptions;
  }

  Future<List<Symbol>> addNodeSymbols() async {
    List<LatLng> coords = track!.getCoordsList();
    nodeSymbols =
        await mapController!.addSymbols(await makeSymbolOptions(coords));

    for (int i = 0; i < nodeSymbols.length; i++) {
      dictSymbols[nodeSymbols[i].id] = nodeSymbols[i];
    }
    List<LatLng> manipulatedCoords = [
      for (var idx in manipulatedIndexes) coords[idx]
    ];

    manipulatedSymbols = await mapController!
        .addSymbols(await makeSymbolOptions(manipulatedCoords));

    for (int i = 0; i < manipulatedSymbols.length; i++) {
      dictManipulatedSymbols[manipulatedSymbols[i].id] = manipulatedSymbols[i];
    }

    return [...nodeSymbols, ...manipulatedSymbols];
  }

  Future<void> removeNodeSymbols() async {
    if (nodeSymbols.isNotEmpty) {
      await mapController!.removeSymbols(nodeSymbols);
      await mapController!.removeSymbols(manipulatedSymbols);
      nodeSymbols = [];
      manipulatedSymbols = [];
    }
  }

  Future<void> redrawNodeSymbols() async {
    await removeNodeSymbols();
    if (isAnyNodesToolActive()) {
      nodeSymbols = await addNodeSymbols();
    }
  }

  @override
  void dispose() {
    textcontroller.dispose();
    if (mapController!.onFeatureDrag.isNotEmpty) {
      mapController!.onFeatureDrag.remove(_onNodeDrag);
    }
    mapController?.onSymbolTapped.remove(_onSymbolTapped);
    mapController!.onFeatureDrag.remove(_onNodeDrag);
    super.dispose();
  }

  Future<void> updateTrack(color, width, changes) async {
    trackColor = color;
    trackWidth = width;
    await mapController!.updateLine(trackLine!, changes);
  }

  Future<Line?> loadTrack(
      List<Wpt> trackSegment, List<Wpt> gpxWaypoints) async {
    deactivateTools();
    showTools = false;

    if (trackLine != null) {
      removeTrackLine();
      await removeNodeSymbols();
      edits = [];
      track!.reset();
    }
    if (queryLine != null) {
      removeQueryLine();
    }

    track = Track(trackSegment);
    await track!.init();
    nodesRatio = track!.getLength() / track!.getCoordsList().length;

    if (infoMode) {
      startSegmentPoint = 0;
      endSegmentPoint = track!.getCoordsList().length - 1;
      addQueryLine(0, track!.getCoordsList().length - 1);
    }

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

    // Add track waypoints to map
    for (int i = 0; i < gpxWaypoints.length; i++) {
      Wpt newWpt = gpxWaypoints[i];
      mapWayPoints.add(newWpt);
      track!.addWpt(newWpt);
      Symbol wptSymbol = await mapController!.addSymbol(SymbolOptions(
          draggable: false,
          iconImage: 'waypoint',
          geometry: LatLng(newWpt.lat!, newWpt.lon!)));

      wptSymbols.add(wptSymbol);
    }

    setState(() {
      trackLoaded = true;
    });
    return trackLine;
  }

  Future<void> removeTrackLine() async {
    if (trackLine != null) {
      mapController!.removeLine(trackLine!);
      if (editMode) {
        editMode = false;
      }
    }
    removeNodeSymbols();
    editMode = false;

    nodeSymbols = [];
    edits = [];
  }

  Future<void> undoDelete(idx, wpt) async {
    track!.addTrkpt(idx, wpt);

    updateTrackLine();
    redrawNodeSymbols();
  }

  Future<void> undoAdd(idx, wpt) async {
    track!.removeTrkpt(idx, wpt);
    updateTrackLine();
    redrawNodeSymbols();
  }

  Future<void> undoMove(idx, wpt) async {
    track!.moveWpt(idx, wpt);

    updateTrackLine();
    redrawNodeSymbols();
  }

  Future<void> undoAddWaypoint(idx, wpt) async {
    track!.removeWpt(idx);
    mapController!.removeSymbol(wptSymbols[idx]);
    wptSymbols.removeAt(idx);
  }

  Future<void> undoEditWaypoint(idx, wpt) async {
    mapWayPoints[idx].name = wpt.name;
    track!.updateWpt(idx, wpt);
  }

  Future<void> undoDeleteWaypoint(idx, wpt) async {
    Symbol wptSymbol = await mapController!.addSymbol(SymbolOptions(
        draggable: false,
        iconImage: 'waypoint',
        geometry: LatLng(wpt.lat, wpt.lon)));

    wpt.extensions['id'] = wptSymbol.id;
    mapWayPoints.insert(idx, cloneWpt(wpt));
    wptSymbols.insert(idx, wptSymbol);

    track!.insertWpt(idx, wpt);
    setState(() {});
  }

  void undo() async {
    if (edits.isEmpty) {
      return;
    }

    var (idx, wpt, type) = edits.removeLast();

    switch (type) {
      case 'moved':
        await undoMove(idx, wpt);
        snackbar(
            context,
            Icon(Icons.drag_handle),
            secondColor,
            Text(AppLocalizations.of(context)!.moveNodeUndone,
                style: textWhite),
            Duration(seconds: 1));
        break;
      case 'delete':
        await undoDelete(idx, wpt);
        snackbar(
            context,
            Icon(Icons.drag_handle, color: white),
            secondColor,
            Text(AppLocalizations.of(context)!.deleteNodeUndone,
                style: textWhite),
            Duration(seconds: 1));
        break;
      case 'add':
        await undoAdd(idx, wpt);
        snackbar(
            context,
            Icon(Icons.drag_handle, color: white),
            secondColor,
            Text(AppLocalizations.of(context)!.addNodeUndone, style: textWhite),
            Duration(seconds: 1));
        break;
      case 'addWaypoint':
        await undoAddWaypoint(idx, wpt);
        snackbar(
            context,
            Icon(Icons.drag_handle, color: white),
            secondColor,
            Text(AppLocalizations.of(context)!.addWaypointUndone,
                style: textWhite),
            Duration(seconds: 1));
        break;
      case 'editWaypoint':
        await undoEditWaypoint(idx, wpt);
        snackbar(
            context,
            Icon(Icons.drag_handle, color: white),
            secondColor,
            Text(AppLocalizations.of(context)!.editWaypointUndone,
                style: textWhite),
            Duration(seconds: 1));
        break;
      case 'deleteWaypoint':
        await undoDeleteWaypoint(idx, wpt);
        snackbar(
            context,
            Icon(Icons.drag_handle, color: white),
            secondColor,
            Text(AppLocalizations.of(context)!.deleteWaypointUndone,
                style: textWhite),
            Duration(seconds: 1));
        break;
    }

    if (edits.isEmpty) {
      setState(() {});
    }
  }

  void removeQueryLine() {
    if (queryLine != null) {
      mapController!.removeLine(queryLine!);
    }
    if (startpoint != null) {
      mapController!.removeSymbol(startpoint!);
    }

    if (endpoint != null) {
      mapController!.removeSymbol(endpoint!);
    }
  }

  enableNodeDragging() {
    mapController!.onFeatureDrag.add(_onNodeDrag);
  }

  disableNodeDragging() {
    mapController!.onFeatureDrag.remove(_onNodeDrag);
  }

  enableSegmentMarkersDragging() async {
    await mapController!.setSymbolIconAllowOverlap(true);
    mapController!.onFeatureDrag.add(_onSegmentMarkerDrag);
  }

  disableSegmentMarkersDragging() {
    mapController!.onFeatureDrag.remove(_onSegmentMarkerDrag);
    if (startpoint != null) {
      mapController!.removeSymbol(startpoint!);
      startpoint = null;
    }
    if (endpoint != null) {
      mapController!.removeSymbol(endpoint!);
      endpoint = null;
    }
    if (shownode != null) {
      mapController!.removeSymbol(shownode!);
      shownode = null;
    }
  }

  void addQueryLine(start, end) async {
    removeQueryLine();

    if (end < start) {
      int tmp = start;
      start = end;
      end = tmp;
    }
    if (end < track!.getCoordsList().length - 1) {
      end += 1;
    }

    List<LatLng> queryCoords = track!.getCoordsList().sublist(start, end + 1);
    queryWpts = track!.getTrack().sublist(start, end);

    queryTrack = Track(queryWpts);
    await queryTrack!.init();
    minY2 = queryTrack!.getMinSpeed();
    maxY2 = queryTrack!.getMaxSpeed();
    minY = queryTrack!.getMinElevation();
    maxY = queryTrack!.getMaxElevation();

    queryLine = await mapController!.addLine(
      LineOptions(
        geometry: queryCoords,
        lineColor: Colors.yellow.toHexStringRGB(),
        lineWidth: trackWidth * 2,
        lineOpacity: 0.9,
      ),
    );
    removeTrackLine();
    trackLine = await mapController!.addLine(
      LineOptions(
        geometry: track!.getCoordsList(),
        lineColor: trackColor.toHexStringRGB(),
        lineWidth: trackWidth,
        lineOpacity: 0.9,
      ),
    );

    startpoint = await mapController!.addSymbol(SymbolOptions(
        draggable: true,
        iconImage: 'startpoint-marker',
        geometry: track!.getCoordsList()[start],
        zIndex: 20,
        iconOffset: kIsWeb ? Offset(5, -28) : Offset(0, -6)));

    endpoint = await mapController!.addSymbol(SymbolOptions(
        draggable: true,
        iconImage: 'endpoint-marker',
        geometry: track!.getCoordsList()[end],
        zIndex: 10,
        iconOffset: kIsWeb ? Offset(5, -28) : Offset(0, -6)));

    showBottomPanel = true;
    setState(() {});
  }

  void resetInfoMode() {
    if (queryLine != null) {
      mapController!.removeLine(queryLine!);
      queryLine = null;
    }
    startSegmentPoint = -1;
    endSegmentPoint = -1;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;

    return LayoutBuilder(builder: (context, constraints) {
      return Stack(children: [
        MapLibreMap(
            minMaxZoomPreference: MinMaxZoomPreference(0, 20),
            compassEnabled: false,
            trackCameraPosition: true,
            onMapCreated: _onMapCreated,
            onMapClick: handleClick,
            onStyleLoadedCallback: () {
              if (kIsWeb) {
                addImageFromAsset(mapController!, "node-plain",
                    "assets/symbols/node-plain-web.png");
                addImageFromAsset(mapController!, "node-drag",
                    "assets/symbols/node-drag-web.png");
                addImageFromAsset(mapController!, "node-delete",
                    "assets/symbols/node-delete-web.png");
                addImageFromAsset(
                    mapController!, "waypoint", "assets/symbols/waypoint.png");
                addImageFromAsset(mapController!, "startpoint-marker",
                    "assets/symbols/startpoint.png");

                addImageFromAsset(mapController!, "endpoint-marker",
                    "assets/symbols/endpoint.png");

                addImageFromAsset(mapController!, "current-selection",
                    "assets/symbols/current-selection.png");
              } else {
                addImageFromAsset(mapController!, "node-plain",
                    "assets/symbols/node-plain.png");
                addImageFromAsset(mapController!, "node-drag",
                    "assets/symbols/node-drag.png");
                addImageFromAsset(mapController!, "node-delete",
                    "assets/symbols/node-delete.png");
                addImageFromAsset(mapController!, "waypoint",
                    "assets/symbols/waypoint-mobile.png");

                addImageFromAsset(mapController!, "startpoint-marker",
                    "assets/symbols/startpointmobile.png");

                addImageFromAsset(mapController!, "endpoint-marker",
                    "assets/symbols/endpointmobile.png");
                addImageFromAsset(mapController!, "current-selection",
                    "assets/symbols/current-selection.png");
              }
            },
            initialCameraPosition: const CameraPosition(
              target: LatLng(42.0, 3.0),
              zoom: 0,
            ),
            styleString: 'assets/styles/mainmap_style.json'
            // styleString: mapStyle
            ),

        if (editTools['add']!) ...[
          GestureDetector(
            onTap: () async {
              // pan map to closest node and show dialog box
              LatLng center = mapController!.cameraPosition!.target;
              var (distance, nodeIdx, P) = track!.getCandidateNode(center);
              await mapController!
                  .animateCamera(
                CameraUpdate.newLatLng(P),
                duration: const Duration(milliseconds: 200),
              )
                  .then((_) {
                showModalBottomSheet(
                    barrierColor: Colors.transparent,
                    context: context,
                    builder: (BuildContext context) {
                      return Container(
                        height: 100,
                        color: secondColor,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Flexible(
                                child: Text(
                                    AppLocalizations.of(context)!
                                        .addNodeConfirm,
                                    style: TextStyle(color: white)),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  ElevatedButton(
                                    child: Text(
                                        AppLocalizations.of(context)!.cancel),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  SizedBox(width: 20),
                                  ElevatedButton(
                                    child: Text(
                                        AppLocalizations.of(context)!.apply),
                                    onPressed: () {
                                      addNode(distance, nodeIdx, P)
                                          .then((status) {
                                        if (status) {
                                          Navigator.pop(context);
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    });
              });
            },
            child: SelectPointFromMapCenter(
              constraints: constraints,
            ),
          ),
        ],
        // TRACK EDITION TOOLS
        Positioned(
          left: 10,
          top: 10,
          child: Column(children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: primaryColor,
              child: CircleAvatar(
                radius: 25,
                backgroundColor: Scaffold.of(context).isEndDrawerOpen
                    ? primaryColor
                    : Colors.white,
                child: IconButton(
                  tooltip: AppLocalizations.of(context)!.baseLayers,
                  icon: Icon(Icons.layers_rounded),
                  color: Scaffold.of(context).isEndDrawerOpen
                      ? Colors.white
                      : primaryColor,
                  onPressed: () {
                    clickPaused = true;
                    var timer = Timer(Duration(seconds: 1), () {
                      clickPaused = false;
                    });
                    setState(() {
                      Scaffold.of(context).openEndDrawer();
                    });
                  },
                ),
              ),
            ),
            const SizedBox(
              height: 4,
            ),
            ...[
              trackLoaded
                  ? GestureDetector(
                      onTap: () {
                        if (editMode) return;
                        setState(() {
                          infoMode = !infoMode;
                          if (infoMode) {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            disableNodeDragging();
                            enableSegmentMarkersDragging();
                            startSegmentPoint = 0;
                            endSegmentPoint = track!.getCoordsList().length - 1;
                            addQueryLine(0, track!.getCoordsList().length - 1);
                          } else {
                            disableSegmentMarkersDragging();
                            enableNodeDragging();
                            showBottomPanel = false;
                            resetInfoMode();
                          }
                        });
                      },
                      child: CircleAvatar(
                        radius: 27,
                        backgroundColor: !editMode ? primaryColor : thirthcolor,
                        child: CircleAvatar(
                            radius: 25,
                            backgroundColor: !editMode
                                ? (infoMode ? primaryColor : white)
                                : thirthcolor,
                            child: Text('i',
                                style: TextStyle(
                                    fontSize: 30,
                                    color: editMode
                                        ? white
                                        : infoMode
                                            ? white
                                            : primaryColor))),
                      ),
                    )
                  : Container()
            ],
            ...[
              trackLoaded
                  ? CircleAvatar(
                      radius: 27,
                      backgroundColor: infoMode
                          ? thirthcolor
                          : editMode
                              ? thirthcolor
                              : primaryColor,
                      child: CircleAvatar(
                        radius: 25,
                        // backgroundColor: !editMode ? Colors.white : thirthcolor,
                        backgroundColor: infoMode
                            ? thirthcolor
                            : (editMode ? thirthcolor : white),
                        child: IconButton(
                          icon: Icon(Icons.edit,
                              color: (infoMode || editMode)
                                  ? white
                                  : primaryColor),
                          tooltip:
                              AppLocalizations.of(context)!.tooltipEditTrack,
                          onPressed: () async {
                            if (infoMode) return;
                            editMode = !editMode;
                            infoMode = false;
                            if (!editMode) {
                              deactivateTools();
                            }
                            setState(() {});
                          },
                        ),
                      ),
                    )
                  : Container()
            ],
            AnimatedSize(
              duration: Duration(milliseconds: 600),
              child: Column(children: [
                const SizedBox(
                  height: 4,
                ),
                CircleAvatar(
                  radius: editMode ? 27 : 0,
                  backgroundColor: primaryColor,
                  child: CircleAvatar(
                    radius: editMode ? 25 : 0,
                    backgroundColor:
                        editTools['move']! ? backgroundActive : white,
                    child: IconButton(
                      tooltip: AppLocalizations.of(context)!.tooltipMoveIcon,
                      icon: MoveIcon(
                        color: editTools['move']! ? white : primaryColor,
                        size: editMode ? 35 : 0,
                      ),
                      onPressed: () async {
                        toggleTool('move');

                        colorIcon1 = defaultColorIcon1;
                        colorIcon2 = defaultColorIcon2;

                        if (editTools['move']!) {
                          colorIcon1 = activeColor1;
                          colorIcon2 = activeColor2;
                        }
                        redrawNodeSymbols();
                        setState(() {});
                      },
                    ),
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                CircleAvatar(
                  radius: editMode ? 27 : 0,
                  backgroundColor: primaryColor,
                  child: CircleAvatar(
                    radius: editMode ? 25 : 0,
                    backgroundColor:
                        editTools['add']! ? backgroundActive : white,
                    child: IconButton(
                      tooltip: AppLocalizations.of(context)!.tooltipoAddIcon,
                      icon: AddIcon(
                        color: editTools['add']! ? white : primaryColor,
                        size: editMode ? 35 : 0,
                      ),
                      onPressed: () async {
                        toggleTool('add');

                        colorIcon1 = defaultColorIcon1;
                        colorIcon2 = defaultColorIcon2;

                        if (editTools['add']!) {
                          colorIcon1 = activeColor1;
                          colorIcon2 = activeColor2;
                        }

                        redrawNodeSymbols();
                        setState(() {});
                      },
                    ),
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                CircleAvatar(
                  radius: editMode ? 27 : 0,
                  backgroundColor: primaryColor,
                  child: CircleAvatar(
                    radius: editMode ? 25 : 0,
                    backgroundColor:
                        editTools['delete']! ? backgroundActive : Colors.white,
                    child: IconButton(
                      tooltip: AppLocalizations.of(context)!.tooltipoDeleteIcon,
                      icon: DeleteIcon(
                        color: editTools['delete']! ? white : primaryColor,
                        size: editMode ? 35 : 0,
                      ),
                      onPressed: () async {
                        toggleTool('delete');
                        await redrawNodeSymbols();
                        setState(() {});
                      },
                    ),
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                CircleAvatar(
                  radius: editMode ? 27 : 0,
                  backgroundColor: primaryColor,
                  child: CircleAvatar(
                      radius: editMode ? 25 : 0,
                      backgroundColor: editTools['addWayPoint']!
                          ? backgroundActive
                          : Colors.white,
                      child: IconButton(
                        tooltip:
                            AppLocalizations.of(context)!.tooltipoAddWaypoint,
                        icon: AnimatedScale(
                          scale: editMode ? 1 : 0,
                          duration: Duration(milliseconds: 300),
                          child: SvgIcon(
                              color: editTools['addWayPoint']!
                                  ? white
                                  : primaryColor,
                              responsiveColor: false,
                              size: 30,
                              icon: SvgIconData('assets/symbols/waypoint.svg')),
                        ),
                        onPressed: () async {
                          await removeNodeSymbols();
                          toggleTool('addWayPoint');
                          setState(() {});
                        },
                      )),
                ),
                const SizedBox(
                  height: 20,
                ),
                CircleAvatar(
                  radius: editMode ? 27 : 0,
                  backgroundColor: edits.isEmpty ? thirthcolor : primaryColor,
                  child: CircleAvatar(
                    radius: editMode ? 25 : 0,
                    backgroundColor: edits.isEmpty ? thirthcolor : white,
                    child: IconButton(
                      tooltip: AppLocalizations.of(context)!.tooltipoUndo,
                      icon: UndoIcon(
                        color: edits.isEmpty ? white : primaryColor,
                        size: editMode ? 35 : 0,
                      ),
                      onPressed: () {
                        if (edits.isNotEmpty) {
                          clickPaused = true;
                          var timer = Timer(Duration(seconds: 1), () {
                            clickPaused = false;
                          });

                          undo();
                        } else {}
                      },
                    ),
                  ),
                )
              ]),
            )
          ]),
        ),

        if (infoMode) ...[
          AnimatedPositioned(
              duration: Duration(milliseconds: 500),
              bottom: showBottomPanel && showChart
                  ? kIsWeb
                      ? (height / 3)
                      : (height / 3) + 16
                  : (showBottomPanel && !showChart)
                      ? kIsWeb
                          ? 65
                          : 50
                      : -(height / 2),
              left: 0,
              child: GestureDetector(
                onTap: () async {
                  showChart = !showChart;
                  arrowRotation += 1 / 2;
                  if (!showChart && shownode != null) {
                    await mapController!.removeSymbol(shownode!);
                    shownode = null;
                  }
                  setState(() {});
                },
                child: Container(
                  color: white.withOpacity(0.7),
                  width: width,
                  child: AnimatedRotation(
                      duration: Duration(milliseconds: 500),
                      turns: arrowRotation,
                      child: Padding(
                        padding: const EdgeInsets.all(0.0),
                        child: Icon(Icons.arrow_drop_down,
                            size: 20, color: primaryColor),
                      )),
                ),
              )),
          AnimatedPositioned(
            duration: Duration(milliseconds: 500),
            bottom: showBottomPanel && showChart
                ? 0
                : (!showChart)
                    ? -((height / 5) + 45)
                    : -(height / 2),
            left: 0,
            child: queryTrack != null
                ? Container(
                    color: Colors.white.withOpacity(0.9),
                    height: showChart
                        ? kIsWeb
                            ? height / 3
                            : (height / 3) + 17
                        : null,
                    width: width,
                    child: Column(
                      children: [
                        Container(
                          color: secondColor,
                          height: kIsWeb ? 65 : 50,
                          child: DefaultTextStyle(
                            style: TextStyle(
                                color: white,
                                fontWeight: FontWeight.bold,
                                fontSize: kIsWeb ? 18 : 10),
                            child: Padding(
                              padding: const EdgeInsets.all(5),
                              // padding: const EdgeInsets.all(kIsWeb ? 8.0 : 4),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: const BoxDecoration(
                                          border: Border(
                                        right: BorderSide(
                                          //                   <--- right side
                                          color: Colors.white,
                                          width: 3.0,
                                        ),
                                      )),
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8.0),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.directions_walk_rounded,
                                                color: white,
                                                size: kIsWeb ? 25 : 20),
                                            SizedBox(height: 5),
                                            Text(formatDistance(
                                                queryTrack!.getLength())),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      decoration: const BoxDecoration(
                                          border: Border(
                                        right: BorderSide(
                                          //                   <--- right side
                                          color: Colors.white,
                                          width: 3.0,
                                        ),
                                      )),
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8.0),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.hourglass_bottom_rounded,
                                                color: white,
                                                size: kIsWeb ? 25 : 20),
                                            SizedBox(height: 5),
                                            Text(
                                                '${formatDuration(queryTrack!.getDuration())}')
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      decoration: const BoxDecoration(
                                          border: Border(
                                        right: BorderSide(
                                          //                   <--- right side
                                          color: Colors.white,
                                          width: 3.0,
                                        ),
                                      )),
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(right: 8.0),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.speed,
                                                color: white,
                                                size: kIsWeb ? 25 : 20),
                                            SizedBox(height: 5),
                                            Text(
                                                '${(queryTrack!.getLength() / queryTrack!.getDuration().inSeconds * 3.6).toStringAsFixed(2)}km/h'),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      decoration: const BoxDecoration(
                                          border: Border(
                                        right: BorderSide(
                                          //                   <--- right side
                                          color: Colors.white,
                                          width: 3.0,
                                        ),
                                      )),
                                      child: Padding(
                                        padding: EdgeInsets.only(right: 8.0),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.change_history_rounded,
                                                color: white,
                                                size: kIsWeb ? 25 : 20),
                                            SizedBox(height: 5),
                                            Text(
                                                '${queryTrack!.getElevationGain()}m'),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Transform.rotate(
                                              angle: math.pi,
                                              child: Icon(
                                                  Icons.change_history_rounded,
                                                  color: white,
                                                  size: kIsWeb ? 25 : 20)),
                                          SizedBox(height: 5),
                                          Text(
                                              '${queryTrack!.getElevationLoss()}m'),
                                        ],
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 10, right: 10),
                          child: TrackInfo(
                              controller: widget.controller,
                              track: queryTrack,
                              width: width,
                              height: (height / 5) + 40),
                        )
                      ],
                    ))
                : Container(),
          )
        ]
      ]);
    });
  }
}

class EventFlags {
  bool pointerDownInner = false;
}
