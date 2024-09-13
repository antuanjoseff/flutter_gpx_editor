import 'dart:convert';
import 'dart:ui';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:flutter/material.dart';
import 'package:geoxml/geoxml.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'util.dart';
import 'dart:convert' show utf8;
import 'package:double_back_to_close/double_back_to_close.dart';
import 'package:throttling/throttling.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool allowClose = false;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: DoubleBack(
        condition: allowClose,
        onConditionFail: () {
          setState(() {
            allowClose = true;
          });
        },
        // message: "Press back again to exit",
        child: const MyHomePage(title: 'GPX'),
        // onFirstBackPress: (context) {
        //   // change this with your custom action
        //   final snackBar = SnackBar(content: Text('Press back again to exit'));
        //   ScaffoldMessenger.of(context).showSnackBar(snackBar);
        //   // ---
        // },
        waitForSecondBackPress: 2, // default 2
        textStyle: const TextStyle(
          fontSize: 13,
          color: Colors.white,
        ),
        background: Colors.red,
        backgroundRadius: 30,
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  MapLibreMapController? controller;
  List<LatLng> gpxCoords = [];
  Line? mapLine;
  List<Symbol> mapSymbols =
      []; //Symbols on map to allow dragging the existing NODES of the gpx track

  bool editMode = false;
  List<CircleOptions> circleOptions = [];
  List<Wpt> rawGpx = [];
  List<LatLng> realNodes = [];

  String? filename;
  String? fileName;
  List<(int, Wpt, String)> edits = [];
  Circle? _selectedCircle;
  Symbol? selectedSymbol;
  Symbol? previousSelectedSymbol;
  int selectedNode = -1;
  String selectedNodeType = '';

  final thr = Throttling<void>(duration: const Duration(milliseconds: 200));
  final deb = Debouncing<void>(duration: const Duration(milliseconds: 200));

  var lineSegment;
  GeoXml? gpxOriginal;
  bool gpxLoaded = false;

  @override
  void initState() {
    super.initState();
  }

  void _onMapCreated(MapLibreMapController mapController) async {
    controller = mapController;
    controller!.onSymbolTapped.add(_onSymbolTapped);
    controller!.onFeatureDrag.add(_onNodeDrag);
  }

  void undoMove(idx, wpt) async {
    rawGpx[idx] = wpt;
    LatLng latlon = LatLng(wpt.lat, wpt.lon);
    gpxCoords[idx] = latlon;
    updateTrackLine();
    _updateSelectedSymbol(
      mapSymbols[idx]!,
      SymbolOptions(draggable: false, iconImage: 'node-box', geometry: latlon),
    );
  }

  void undo() async {
    if (edits.isEmpty) return;

    var (idx, wpt, type) = edits.removeLast();
    switch (type) {
      case 'moved':
        undoMove(idx, wpt);
        break;
    }
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
    await controller!.updateSymbol(symbol, changes);
    setState(() {});
  }

  void updateTrackLine() async {
    await controller!.updateLine(mapLine!, LineOptions(geometry: gpxCoords));
    // setState(() {});
  }

  @override
  void dispose() {
    // controller?.onFillTapped.remove(_onFillTapped);
    // controller?.onCircleTapped.remove(_onCircleTapped);
    // controller?.onLineTapped.remove(_onLineTapped);
    controller?.onSymbolTapped.remove(_onSymbolTapped);
    super.dispose();
  }

  void _onSymbolTapped(Symbol symbol) async {
    thr.throttle(() async{
      print('ON SYMBOL TAPPED');
      if (selectedSymbol != null) {
        print('DEACTIVATE.......selectedNode....$selectedNode');
        
        String symbolId = await deactivateSymbol(selectedSymbol!, selectedNode);
        if (symbolId != symbol.id) {
          print('SELECTED ANOTHER SYMBOL DIFFERENT FROM PREVIOUSLY SELECTED ONE');
          selectedSymbol = symbol;
          selectedNode = await searchSymbol(symbol.id);
          print('SELECTED NODE $selectedNode');
          await activateSymbol(selectedSymbol!, selectedNode);       
        }
        return;
      } 

      selectedSymbol = symbol;
      selectedNode = await searchSymbol(symbol.id);
      print('ACTIVATE.......selectedNode....$selectedNode');

      activateSymbol(selectedSymbol!, selectedNode);              
    });
         
  
  }

  Future<String> activateSymbol(Symbol symbol, int idx) async{
    print('ACTIVATE SYMBOL');
    await redrawSymbol(symbol, idx, 'activate');
    return symbol.id;
  }

  Future<String> deactivateSymbol(Symbol symbol, int idx) async {
    print('DEACTIVATE SYMBOL ${symbol.id}');
    await redrawSymbol(symbol, idx, 'deactivate');
    return symbol.id;
  }

  Future<void> redrawSymbol(Symbol symbol, int idx, String mode) async{
    String image = 'node-box';
    bool draggable = false;
    if (mode == 'activate') {
      image = 'selected-box';
      draggable = true;
    }
    LatLng coords = LatLng(symbol.options.geometry!.latitude, symbol.options.geometry!.longitude);
    _updateSelectedSymbol(
      selectedSymbol!,
      SymbolOptions(
          geometry: coords, draggable: draggable, iconImage: image),
    );
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
        print('.............SELECTED NODE         $selectedNode');
        selectedSymbol = mapSymbols[selectedNode];
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
        realNodes[selectedNode] = coord;

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
        selectedSymbol = null;
        selectedNode = -1;
        break;
    }
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
    mapSymbols =
        await controller!.addSymbols(makeSymbolOptions(realNodes, 'node-box'));
  }

  void addSymbols() async {
    addMapSymbols();
  }

  void removeSymbols() async {
    await controller!.removeSymbols(mapSymbols);
    mapSymbols = [];
  }

  void resetSymbols() {
    removeSymbols();
    addSymbols();
  }

  void addLine(trackSegment) async {
    LatLng cur;
    LatLng next;

    Bounds bounds = Bounds(
        LatLng(trackSegment.first.lat, trackSegment.first.lon),
        LatLng(trackSegment.first.lat, trackSegment.first.lon));

    for (var i = 0; i < trackSegment.length - 1; i++) {
      cur = LatLng(trackSegment[i].lat, trackSegment[i].lon);
      next = LatLng(trackSegment[i + 1].lat, trackSegment[i + 1].lon);
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

    mapLine = await controller!.addLine(
      LineOptions(
        geometry: gpxCoords,
        lineColor: "#ffa500",
        lineWidth: 2.5,
        lineOpacity: 0.9,
      ),
    );

    controller!.moveCamera(
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

  void cleanScreen() {
    if (mapLine != null) {
      controller!.removeLine(mapLine!);
      if (editMode) {
        editMode = false;
        removeSymbols();
      }
    }
    editMode = false;
    realNodes = [];
    mapSymbols = [];
    gpxCoords = [];
    rawGpx = [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          ...[
            edits.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.undo),
                    tooltip: 'Show Snackbar',
                    onPressed: () async {
                      undo();
                    },
                  )
                : Container()
          ],
          ...[
            gpxOriginal != null
                ? IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Show Snackbar',
                    onPressed: () async {
                      editMode = !editMode;
                      if (editMode) {
                        addSymbols();
                      } else {
                        removeSymbols();
                      }
                    },
                  )
                : Container()
          ],
          ...[
            gpxOriginal != null
                ? IconButton(
                    icon: const Icon(Icons.save),
                    tooltip: 'Show Snackbar',
                    onPressed: () async {
                      removeSymbols();
                      var gpx = GeoXml();
                      gpx.creator = "dart-gpx library";

                      gpx.metadata = gpxOriginal!.metadata;
                      List<Wpt> newGpx = [];
                      for (var idx = 0; idx < rawGpx.length; idx++) {
                        Wpt wpt = rawGpx[idx];
                        newGpx.add(wpt);
                      }

                      Trkseg trkseg = Trkseg(trkpts: newGpx);
                      gpx.trks = [
                        Trk(trksegs: [trkseg])
                      ];

                      // generate xml string
                      var gpxString = gpx.toGpxString(pretty: true);

                      String? outputFile = await FilePicker.platform.saveFile(
                        dialogTitle: 'Please select an output file:',
                        bytes: utf8.encode(gpxString),
                        // bytes: convertStringToUint8List(gpxString),
                        fileName: '${fileName}_edited.gpx',
                        allowedExtensions: ['gpx'],
                      );
                    },
                  )
                : Container()
          ],
          IconButton(
            icon: const Icon(Icons.folder),
            tooltip: 'Show Snackbar',
            onPressed: () async {
              FilePickerResult? result = await FilePicker.platform.pickFiles();
              if (result != null) {
                filename = result.files.single.path!.toString();
                fileName = result.files.single.name.toString();

                // TO DO. Check for invalid file format
                final stream =
                    await utf8.decoder.bind(File(filename!).openRead()).join();

                gpxOriginal = await GeoXml.fromGpxString(stream);

                setState(() {
                  cleanScreen();
                  // get only first track segment
                  lineSegment = gpxOriginal!.trks[0].trksegs[0].trkpts;
                  addLine(lineSegment);
                });
              } else {
                // User canceled the picker
              }
            },
          ),
        ],
      ),
      body: MapLibreMap(
        compassEnabled: false,
        // myLocationEnabled: true,
        trackCameraPosition: true,
        onMapClick: (point, clickedPoint) async {
          print('ON MAP CLICKED');
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
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: () {
          addImageFromAsset(controller!, "node-box", "assets/symbols/box.png");
          addImageFromAsset(
              controller!, "selected-box", "assets/symbols/selected-box.png");
          addImageFromAsset(
              controller!, "virtual-box", "assets/symbols/virtual-box.png");
          addImageFromAsset(
              controller!, "marker", "assets/symbols/custom-marker.png");
        },
        initialCameraPosition: const CameraPosition(
          target: LatLng(42.0, 3.0),
          zoom: 13.0,
        ),
        styleString:
            // 'https://geoserveis.icgc.cat/contextmaps/icgc_mapa_base_gris_simplificat.json',
            'https://geoserveis.icgc.cat/contextmaps/icgc_orto_hibrida.json',
      ),
    );
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
