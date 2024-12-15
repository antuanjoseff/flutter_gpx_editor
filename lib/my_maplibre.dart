import 'package:flutter/material.dart';
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

  // var used to calculate number of pixels between track nodes
  int imagesPadding = 0;

  late TextEditingController controller;

  ButtonStyle styleElevatedButtons = ElevatedButton.styleFrom(
    minimumSize: Size.zero, // Set this
    padding:
        EdgeInsets.only(left: 20, right: 20, top: 5, bottom: 5), // and this
    backgroundColor: primaryColor,
    foregroundColor: white,
  );

  ButtonStyle buttonNoPadding = ElevatedButton.styleFrom(
    minimumSize: Size.zero, // Set this
    padding: EdgeInsets.only(left: 2, right: 2, top: 2, bottom: 2), // and this
    backgroundColor: primaryColor,
    foregroundColor: white,
  );

  double trackWidth = 3;
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
  List<Symbol> nodeSymbols =
      []; //Symbols on map to allow dragging the existing NODES of the gpx track

  List<Symbol> wptSymbols = [];
  List<Wpt> mapWayPoints = []; //Gpx WPTS

  bool editMode = false;

  List<(int, Wpt, String)> edits = [];

  String? filename;
  String? fileName;

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

  final thr = Throttling<void>(duration: const Duration(milliseconds: 200));
  final deb = Debouncing<void>(duration: const Duration(milliseconds: 300));

  late AnimationController _animationController;
  late Animation<double> _animation;

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
    controller = TextEditingController();
    super.initState();
    _animationController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 500));
    _animation =
        CurvedAnimation(parent: _animationController, curve: Curves.ease);
  }

  void deactivateTools() {
    for (String tool in editTools.keys) {
      editTools[tool] = false;
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
    if (editTools['addWayPoint'] == true) {
      await mapController!.setSymbolIconAllowOverlap(true);
    } else {
      await mapController!.setSymbolIconAllowOverlap(false);
    }

    var timer = Timer(Duration(seconds: 1), () {
      clickPaused = false;
    });
    // timer.cancel();
  }

  void setEditMode(bool editmode) async {
    showTools = editmode;
    if (editmode) {
      // nodeSymbols = await addNodeSymbols();
      _animationController.forward();
    } else {
      nodeSymbols = await removeNodeSymbols();
    }
    setState(() {});
  }

  void _onMapCreated(MapLibreMapController contrl) async {
    mapController = contrl;
    mapController!.addListener(_onMapChanged);
    mapController!.onSymbolTapped.add(_onFeatureTapped);
    mapController!.onFeatureDrag.add(_onNodeDrag);
    if (!kIsWeb) {
      await mapController!.setSymbolIconAllowOverlap(false);
    }
  }

  LatLng getCenter() {
    return mapController!.cameraPosition!.target;
  }

  double getZoom() {
    return mapController!.cameraPosition!.zoom;
  }

  void _onMapChanged() async {
    int zoom = mapController!.cameraPosition!.zoom.floor();
    if (isAnyNodesToolActive() && kIsWeb) {
      // after last map changed, wait 300ms and redraw nodes
      deb.debounce(() {
        redrawNodeSymbols();
      });
    }
    if (zoom == 19) {
      prevZoom = 19;
      await mapController!.setSymbolIconAllowOverlap(true);
    } else {
      if (prevZoom == 19) {
        await mapController!.setSymbolIconAllowOverlap(false);
        prevZoom = zoom;
      }
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

  void _onFeatureTapped(Symbol symbol) async {
    // Only when these tools are activated
    if (!isDeleteActive() && !isAddWayPointActive()) {
      return;
    }
    var (symbolIdx, nodeIdx) = await searchSymbol(symbol.id);
    selectedNode = nodeIdx;
    if (selectedNode == -1) {
      // then user tapped on a wpt
      _tappedOnWpt(symbol);
      return;
    }

    edits.add(
        (selectedNode, cloneWpt(track!.trackSegment[selectedNode]), 'delete'));

    track!.removeNode(selectedNode);
    await mapController!.removeSymbol(nodeSymbols[symbolIdx]);
    nodeSymbols.removeAt(symbolIdx);
    redrawNodeSymbols();
    updateTrackLine();
    setState(() {});
  }

  void _tappedOnWpt(Symbol search) async {
    int idx = -1;
    for (var i = 0; idx == -1 && i < mapWayPoints.length; i++) {
      if (search.id == mapWayPoints[i].extensions['id']) {
        idx = i;
      }
    }
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

    // edits.add(
    //     (selectedNode, cloneWpt(track!.trackSegment[selectedNode]), 'delete'));

    // track!.removeNode(selectedNode);

    // await mapController!.removeSymbol(nodeSymbols[selectedNode]);
    // nodeSymbols.removeAt(selectedNode);

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

  void handleClick(point, clickedPoint) {
    if (clickPaused) {
      return;
    }
    if (editTools['add']! && track!.getCoordsList().isNotEmpty) {
      addNode(point, clickedPoint);
      return;
    }

    if (editTools['addWayPoint']! && track!.getCoordsList().isNotEmpty) {
      addWayPoint(point, clickedPoint);
      return;
    }
  }

  Future<(String?, String?)> openDialogNewWpt() async {
    controller.text = "Waypoint ${mapWayPoints.length}";
    clickPaused = true;
    return await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
                title: Text(AppLocalizations.of(context)!.wptName),
                content: TextField(
                  onTap: () => controller.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: controller.value.text.length),
                  autofocus: true,
                  // decoration: InputDecoration(hintText: 'Nom del track'),
                  controller: controller,
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
    controller.text = "${wpt.name}";
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
                  onTap: () => controller.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: controller.value.text.length),
                  autofocus: true,
                  // decoration: InputDecoration(hintText: 'Nom del track'),
                  controller: controller,
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
      controller.clear();
    });
  }

  void submit(String action) {
    var timer = Timer(Duration(milliseconds: 300), () {
      clickPaused = false;
      Navigator.of(context).pop((
        action,
        controller.text,
      ));
      controller.clear();
    });
  }

  void cancel() {
    var timer = Timer(Duration(milliseconds: 300), () {
      clickPaused = false;
      Navigator.of(context).pop((
        'cancel',
        null,
      ));
      controller.clear();
    });
  }

  void addWayPoint(point, clickedPoint) async {
    Symbol wptSymbol = await mapController!.addSymbol(SymbolOptions(
        draggable: false,
        iconImage: 'waypoint',
        geometry: clickedPoint,
        iconOffset: kIsWeb ? Offset(5, -28) : Offset(0, -25)));

    var (action, wptName) = await openDialogNewWpt();

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

  void addNode(point, clickedPoint) async {
    var (dist, position, P) = track!.getCandidateNode(clickedPoint);

    if (dist < 50) {
      Symbol added = await mapController!.addSymbol(SymbolOptions(
          draggable: false, iconImage: 'node-plain', geometry: P));

      nodeSymbols.insert(position + 1, added);

      Wpt newWpt = cloneWpt(halfSegmentWpt(
          track!.trackSegment[position], track!.trackSegment[position + 1]));
      newWpt.lat = P.latitude;
      newWpt.lon = P.longitude;
      edits.add((position + 1, newWpt, 'add'));

      track!.addNode(position, newWpt);

      updateTrackLine();
      await redrawNodeSymbols();
      setState(() {});
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
    if (!isMoveNodeActive()) return;

    switch (eventType) {
      case DragEventType.start:
        var (symbolIdx, nodeIdx) = await searchSymbol(id);
        selectedNode = nodeIdx;
        if (selectedNode == -1) return;
        selectedSymbol = nodeSymbols[symbolIdx];
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

        updateTrackLine();
        await redrawNodeSymbols();
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

  Future<(int, int)> searchSymbol(String search) async {
    late LatLng geom;
    for (var i = 0; i < nodeSymbols.length; i++) {
      if (nodeSymbols[i].id == search) {
        geom = LatLng(nodeSymbols[i].options.geometry!.latitude,
            nodeSymbols[i].options.geometry!.longitude);
        // debugPrint(
        //     '-------------${nodeSymbols[i].options.geometry!.latitude} ------${nodeSymbols[i].options.geometry!.longitude}');
        List<LatLng> coords = track!.getCoordsList();
        late LatLng coord;

        for (var y = 0; y < coords.length; y++) {
          coord = coords[y];
          if (coord.latitude == geom.latitude &&
              coord.longitude == geom.longitude) {
            // debugPrint(
            //     '  AQUEST     ${coord.latitude} xxxxxx   ${coord.longitude}');
            return (i, y);
          }
        }
      }
    }
    return (-1, -1);
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

  Future<List<SymbolOptions>> makeSymbolOptions() async {
    final symbolOptions = <SymbolOptions>[];
    String image = getNodesImage(editTools);
    bool draggable = editTools['move']! ? true : false;
    List<LatLng> nodes = track!.getCoordsList();

    if (kIsWeb) {
      double resolution = await mapController!.getMetersPerPixelAtLatitude(
          mapController!.cameraPosition!.target.latitude);

      imagesPadding = ((80 * resolution) / nodesRatio).floor();
    } else {
      imagesPadding = 1; // show all
    }

    for (var idx = 0; idx < nodes.length; idx++) {
      if (idx % imagesPadding != 0) {
        continue;
      }
      LatLng coord = nodes[idx];
      symbolOptions.add(SymbolOptions(
          draggable: draggable,
          iconImage: image,
          geometry: coord,
          textAnchor: idx.toString()));
    }

    return symbolOptions;
  }

  Future<List<Symbol>> addNodeSymbols() async {
    nodeSymbols = await mapController!.addSymbols(await makeSymbolOptions());
    return nodeSymbols;
  }

  Future<List<Symbol>> removeNodeSymbols() async {
    await mapController!.removeSymbols(nodeSymbols);
    nodeSymbols = [];
    return nodeSymbols;
  }

  Future<void> redrawNodeSymbols() async {
    nodeSymbols = await removeNodeSymbols();
    // Only draw nodes if some key is activated
    if (isAnyNodesToolActive()) {
      nodeSymbols = await addNodeSymbols();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    if (mapController!.onFeatureDrag.isNotEmpty) {
      mapController!.onFeatureDrag.remove(_onNodeDrag);
    }
    mapController?.onSymbolTapped.remove(_onFeatureTapped);
    mapController!.onFeatureDrag.remove(_onNodeDrag);
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
      nodeSymbols = await removeNodeSymbols();
      edits = [];
      track!.reset();
    }

    track = Track(trackSegment);
    await track!.init();
    nodesRatio = track!.getLength() / track!.getCoordsList().length;

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
    setState(() {
      trackLoaded = true;
    });
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

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      MapLibreMap(
          minMaxZoomPreference: MinMaxZoomPreference(0, 18),
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
            if (kIsWeb) {
              addImageFromAsset(
                  mapController!, "waypoint", "assets/symbols/waypoint.png");
            } else {
              addImageFromAsset(mapController!, "waypoint",
                  "assets/symbols/waypoint-mobile.png");
            }
          },
          initialCameraPosition: const CameraPosition(
            target: LatLng(42.0, 3.0),
            zoom: 0,
          ),
          styleString: 'assets/styles/mainmap_style.json'
          // styleString: mapStyle
          ),
      Positioned(
        left: 10,
        top: 10,
        child: Column(children: [
          GestureDetector(
            onTap: () {
              clickPaused = true;
              var timer = Timer(Duration(seconds: 1), () {
                clickPaused = false;
              });
              setState(() {
                Scaffold.of(context).openEndDrawer();
              });
            },
            child: CircleAvatar(
              radius: 25,
              backgroundColor: Scaffold.of(context).isEndDrawerOpen
                  ? primaryColor
                  : Colors.white,
              child: Icon(
                Icons.layers_rounded,
                color: Scaffold.of(context).isEndDrawerOpen
                    ? Colors.white
                    : primaryColor,
              ),
            ),
          ),
          SizedBox(
            height: 4,
          ),
          ...[
            trackLoaded
                ? CircleAvatar(
                    radius: 25,
                    backgroundColor: !editMode ? Colors.white : thirthcolor,
                    child: IconButton(
                      icon: Icon(Icons.edit,
                          color: !editMode ? primaryColor : white),
                      tooltip: 'Show Snackbar',
                      onPressed: () async {
                        editMode = !editMode;
                        setState(() {});
                      },
                    ),
                  )
                : Container()
          ],
          AnimatedSize(
            duration: Duration(milliseconds: 600),
            child: Column(children: [
              SizedBox(
                height: 4,
              ),
              GestureDetector(
                onTap: () async {
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
                child: CircleAvatar(
                  radius: editMode ? 25 : 0,
                  backgroundColor:
                      editTools['move']! ? backgroundActive : white,
                  child: MoveIcon(
                    color1: editTools['move']! ? white : inactiveColor,
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

                  if (editTools['add']!) {
                    colorIcon1 = activeColor1;
                    colorIcon2 = activeColor2;
                  }

                  redrawNodeSymbols();
                  setState(() {});
                },
                child: CircleAvatar(
                  radius: editMode ? 25 : 0,
                  backgroundColor: editTools['add']! ? backgroundActive : white,
                  child: AddIcon(
                    color1: editTools['add']! ? white : inactiveColor,
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
                  await redrawNodeSymbols();
                  setState(() {});
                },
                child: CircleAvatar(
                  radius: editMode ? 25 : 0,
                  backgroundColor:
                      editTools['delete']! ? backgroundActive : Colors.white,
                  child: DeleteIcon(
                    color1: editTools['delete']! ? white : inactiveColor,
                    color2: const Color(0xffc5dd16),
                  ),
                ),
              ),
              const SizedBox(
                height: 4,
              ),
              GestureDetector(
                onTap: () async {
                  await removeNodeSymbols();
                  toggleTool('addWayPoint');
                  setState(() {});
                },
                child: CircleAvatar(
                    radius: editMode ? 25 : 0,
                    backgroundColor: Colors.white,
                    child: SvgIcon(
                        color: editTools['addWayPoint']!
                            ? Theme.of(context).canvasColor
                            : inactiveColor,
                        responsiveColor: false,
                        size: 30,
                        icon: SvgIconData('assets/symbols/waypoint.svg'))),
              ),
              const SizedBox(
                height: 20,
              ),
              ...[
                edits.isNotEmpty
                    ? Positioned(
                        child: GestureDetector(
                          onTap: () {
                            if (edits.isNotEmpty) {
                              clickPaused = true;
                              var timer = Timer(Duration(seconds: 1), () {
                                clickPaused = false;
                              });

                              undo();
                            } else {}
                          },
                          child: CircleAvatar(
                            radius: editMode ? 25 : 0,
                            backgroundColor:
                                edits.isNotEmpty ? primaryColor : white,
                            child: UndoIcon(
                                color: edits.isEmpty ? inactiveColor : white),
                          ),
                        ),
                      )
                    : Container()
              ],
            ]),
          )
        ]),
      ),
    ]);
  }
}

class EventFlags {
  bool pointerDownInner = false;
}
