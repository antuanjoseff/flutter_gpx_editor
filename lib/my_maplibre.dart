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
  Map<String, bool> editTools = {
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
    controller.addNodeSymbols = addNodeSymbols;
    controller.removeNodeSymbols = removeNodeSymbols;
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
    for (String tool in editTools.keys) {
      editTools[tool] = false;
    }
  }

  void activateTool(tool) {
    deactivateTools();
    editTools[tool] = true;
  }

  bool isAnyToolActive() {
    for (String kTool in editTools.keys) {
      if (editTools[kTool] == true) {
        return true;
      }
    }
    return false;
  }

  void toggleTool(tool) {
    for (String ktool in editTools.keys) {
      if (ktool == tool) {
        editTools[tool] = !editTools[tool]!;
      } else {
        editTools[ktool] = false;
      }
    }
  }

  void setEditMode(bool editmode) async {
    showTools = editmode;
    if (editmode) {
      // nodeSymbols = await addNodeSymbols();
    } else {
      print('remove map symbols');
      nodeSymbols = await removeNodeSymbols();
    }
    setState(() {});
  }

  void _onMapCreated(MapLibreMapController contrl) async {
    mapController = contrl;
    // mapController!.onFeatureDrag.add(_onNodeDrag);
  }

  void _onFeatureTapped(Symbol symbol) async {
    selectedNode = await searchSymbol(symbol.id);
    if (selectedNode == -1) {
      // then user tapped on a wpt
      debugPrint('TAPPED ON WPT');
      _tappedOnWpt(symbol);
      return;
    }

    edits.add(
        (selectedNode, cloneWpt(track!.trackSegment[selectedNode]), 'delete'));

    track!.removeNode(selectedNode);

    await mapController!.removeSymbol(nodeSymbols[selectedNode]);
    nodeSymbols.removeAt(selectedNode);
    redrawNodeSymbols();
    updateTrackLine();
    setState(() {});
  }

  void _tappedOnWpt(Symbol search) async {
    debugPrint('SEARCH SYMBOL ID: ${search.id}');
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

  void handleClick(point, clickedPoint) {
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

    return await showDialog(
        context: context,
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
    return await showDialog(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(AppLocalizations.of(context)!.confirmDeleteWpt),
                actions: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                          style: styleElevatedButtons,
                          onPressed: () {
                            Navigator.of(context).pop(true);
                          },
                          child: Text(AppLocalizations.of(context)!.yes)),
                      SizedBox(width: 20),
                      ElevatedButton(
                          style: styleElevatedButtons,
                          onPressed: () {
                            Navigator.of(context).pop(false);
                          },
                          child: Text(AppLocalizations.of(context)!.no)),
                    ],
                  )
                ]));
  }

  void deleteWpt(Wpt wpt) {
    Navigator.of(context).pop((
      'delete',
      wpt.extensions['id'],
    ));
    controller.clear();
  }

  void submit(String action) {
    Navigator.of(context).pop((
      action,
      controller.text,
    ));
    controller.clear();
  }

  void cancel() {
    Navigator.of(context).pop((
      'cancel',
      null,
    ));
  }

  void addWayPoint(point, clickedPoint) async {
    Symbol wptSymbol = await mapController!.addSymbol(SymbolOptions(
        draggable: false, iconImage: 'waypoint', geometry: clickedPoint));

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
      );
    }
  }

  void snackbar(context, Icon icon, Color color, Text myText) {
    // Close previous snackbar
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          children: [
            Row(
              children: [const SizedBox(width: 10), myText],
            ),
            const SizedBox(
              height: 10,
            ),
          ],
        ),
        backgroundColor: color,
        duration: Duration(seconds: 1),
      ),
    );
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
        selectedSymbol = nodeSymbols[selectedNode];
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

  Future<int> searchSymbol(String search) async {
    for (var i = 0; i < nodeSymbols.length; i++) {
      if (nodeSymbols[i].id == search) {
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
    String image = getNodesImage(editTools);
    bool draggable = editTools['move']! ? true : false;
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

  Future<List<Symbol>> addNodeSymbols() async {
    nodeSymbols = await mapController!.addSymbols(makeSymbolOptions());
    return nodeSymbols;
  }

  Future<List<Symbol>> removeNodeSymbols() async {
    print('---------------REMOVE MAP SYMBOLS');
    await mapController!.removeSymbols(nodeSymbols);
    nodeSymbols = [];
    return nodeSymbols;
  }

  Future<void> redrawNodeSymbols() async {
    nodeSymbols = await removeNodeSymbols();
    // Only draw nodes if some key is activated
    if (isAnyToolActive()) {
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
    debugPrint('UNDO EDIT WAYPOINT    $idx');
    mapWayPoints[idx].name = wpt.name;
    track!.updateWpt(idx, wpt);
  }

  Future<void> undoDeleteWaypoint(idx, wpt) async {
    Symbol wptSymbol = await mapController!.addSymbol(SymbolOptions(
        draggable: false,
        iconImage: 'waypoint',
        geometry: LatLng(wpt.lat, wpt.lon)));

    debugPrint('id of new symbol ${wptSymbol.id}');
    wpt.extensions['id'] = wptSymbol.id;
    mapWayPoints.insert(idx, cloneWpt(wpt));
    debugPrint('id of recovered wpt ${wpt.extensions['id']}');

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
        snackbar(context, Icon(Icons.drag_handle), secondColor,
            Text('Node moved back', style: textPrimary));
        break;
      case 'delete':
        await undoDelete(idx, wpt);
        snackbar(context, Icon(Icons.drag_handle, color: primaryColor),
            secondColor, Text('Node recovered', style: textPrimary));
        break;
      case 'add':
        await undoAdd(idx, wpt);
        snackbar(context, Icon(Icons.drag_handle, color: primaryColor),
            secondColor, Text('Node recovered', style: textPrimary));
        break;
      case 'addWaypoint':
        await undoAddWaypoint(idx, wpt);
        snackbar(context, Icon(Icons.drag_handle, color: primaryColor),
            secondColor, Text('Undo waypoint', style: textPrimary));
        break;
      case 'editWaypoint':
        await undoEditWaypoint(idx, wpt);
        snackbar(context, Icon(Icons.drag_handle, color: primaryColor),
            secondColor, Text('Waypoint edited back', style: textPrimary));
        break;
      case 'deleteWaypoint':
        await undoDeleteWaypoint(idx, wpt);
        snackbar(context, Icon(Icons.drag_handle, color: primaryColor),
            secondColor, Text('Waypoint recovered', style: textPrimary));
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
          minMaxZoomPreference: MinMaxZoomPreference(0, 19),
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
                left: 10,
                top: 10,
                child: GestureDetector(
                  onTap: () {
                    if (edits.isNotEmpty) {
                      undo();
                    } else {}
                  },
                  child: CircleAvatar(
                    radius: 25,
                    backgroundColor: edits.isNotEmpty ? primaryColor : white,
                    child:
                        UndoIcon(color: edits.isEmpty ? inactiveColor : white),
                  ),
                ),
              )
            : Container()
      ],
      ...[
        showTools
            ? Positioned(
                right: 10,
                top: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        toggleTool('move');

                        colorIcon1 = defaultColorIcon1;
                        colorIcon2 = defaultColorIcon2;

                        if (editTools['move']!) {
                          colorIcon1 = activeColor1;
                          colorIcon2 = activeColor2;
                          mapController!.onFeatureDrag.add(_onNodeDrag);
                        } else {
                          mapController!.onFeatureDrag.remove(_onNodeDrag);
                        }
                        redrawNodeSymbols();

                        setState(() {});
                      },
                      child: CircleAvatar(
                        radius: 25,
                        backgroundColor:
                            editTools['move']! ? backgroundActive : white,
                        child: MoveIcon(
                          color1: editTools['move']! ? white : inactiveColor,
                          color2: const Color(0xffc5dd16),
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 4,
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
                        radius: 25,
                        backgroundColor:
                            editTools['add']! ? backgroundActive : white,
                        child: AddIcon(
                          color1: editTools['add']! ? white : inactiveColor,
                          color2: const Color(0xffc5dd16),
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 4,
                    ),
                    GestureDetector(
                      onTap: () async {
                        toggleTool('delete');
                        if (editTools['delete']!) {
                          mapController!.onSymbolTapped.add(_onFeatureTapped);
                        } else {
                          mapController?.onSymbolTapped
                              .remove(_onFeatureTapped);
                        }
                        await redrawNodeSymbols();
                        setState(() {});
                      },
                      child: CircleAvatar(
                        radius: 25,
                        backgroundColor: editTools['delete']!
                            ? backgroundActive
                            : Colors.white,
                        child: DeleteIcon(
                          color1: editTools['delete']! ? white : inactiveColor,
                          color2: const Color(0xffc5dd16),
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 4,
                    ),
                    GestureDetector(
                      onTap: () async {
                        toggleTool('addWayPoint');

                        if (editTools['addWayPoint']!) {
                          mapController!.onSymbolTapped.add(_onFeatureTapped);
                        } else {
                          mapController?.onSymbolTapped
                              .remove(_onFeatureTapped);
                        }

                        await removeNodeSymbols();
                        setState(() {});
                      },
                      child: CircleAvatar(
                        radius: 25,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.flag,
                          color: editTools['addWayPoint']!
                              ? Theme.of(context).canvasColor
                              : inactiveColor,
                          size: 35,
                        ),
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
