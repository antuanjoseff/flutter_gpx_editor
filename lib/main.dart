import 'dart:convert';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:flutter/material.dart';
import 'package:geoxml/geoxml.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'util.dart';
import 'dart:convert' show utf8;
import 'package:double_back_to_close/double_back_to_close.dart';

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
        onFirstBackPress: (context) {
          // change this with your custom action
          final snackBar = SnackBar(content: Text('Press back again to exit'));
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
          // ---
        },
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
  List<Circle> mapCircles = [];
  List<Symbol> realSymbols =
      []; //Symbols on map to allow dragging the existing NODES of the gpx track
  List<Symbol> virtualSymbols =
      []; //Symbols on map to allow adding new NODES to the gpx track
  List<Symbol?> neighbouringNodes = [];
  bool circlesVisible = false;
  List<CircleOptions> circleOptions = [];
  List<Wpt> rawGpx = [];
  List<LatLng> realNodes = [];
  List<LatLng> virtualNodes = [];
  String? filename;
  String? fileName;
  List<(int, Wpt, String)> edits = [];
  Circle? _selectedCircle;
  Symbol? _selectedSymbol;
  int selectedNode = -1;
  String selectedNodeType = '';

  var lineSegment;
  GeoXml? gpxOriginal;
  bool gpxLoaded = false;

  @override
  void initState() {
    super.initState();
  }

  void _onMapCreated(MapLibreMapController mapController) async {
    controller = mapController;
    // controller!.onCircleTapped.add(_onCircleTapped);
    controller!.onSymbolTapped.add(_onSymbolTapped);
    controller!.onFeatureDrag.add(_onNodeDrag);
  }

  void undoMove(idx, wpt) async {}

  void undo() async {
    if (edits.isEmpty) return;

    var (idx, wpt, type) = edits.removeLast();

    switch (type) {
      case 'moved':
        // undoMove(idx, wpt);
        break;
    }
  }

  int searchNode(Circle circle) {
    var search = LatLng(circle.toGeoJson()['geometry']['coordinates'][1],
        circle.toGeoJson()['geometry']['coordinates'][0]);
    bool found = false;
    int i = 0;

    while (!found && i < realNodes.length) {
      if (realNodes[i].latitude == search.latitude &&
          realNodes[i].longitude == search.longitude) {
        found = true;
      } else {
        i++;
      }
    }

    if (found) {
      return i;
    } else {
      return -1;
    }
  }

  Future<(int, String)> searchSymbol(Symbol symbol) async {
    String type = 'real';
    var search = LatLng(symbol.toGeoJson()['geometry']['coordinates'][1],
        symbol.toGeoJson()['geometry']['coordinates'][0]);
    int found = -1;
    int i = 0;

    while (found == -1 && i < realNodes.length) {
      if (realNodes[i].latitude == search.latitude &&
          realNodes[i].longitude == search.longitude) {
        found = i;
      } else {
        i++;
      }
    }

    i = 0;
    while (found == -1 && i < virtualNodes.length) {
      if (virtualNodes[i].latitude == search.latitude &&
          virtualNodes[i].longitude == search.longitude) {
        found = i;
        type = 'virtual';
      } else {
        i++;
      }
    }

    print(
        'FOUND SYMBOL AT POSITION   ------------------------------------  $found');
    if (found != -1) {
      return (found, type);
    } else {
      return (-1, '');
    }
  }

  // void deleteCircle(String type, String id, Circle circle) async{

  //   found = false;
  //   i = 0;
  //   // SAME WITH CIRCLES
  //   while (!found && i < mapCircles.length) {
  //     if (mapCircles[i].options.geometry!.latitude == search.latitude && mapCircles[i].options.geometry!.longitude == search.longitude ) {
  //       found = true;
  //       mapCircles.removeAt(i);
  //       controller!.removeCircle(circle);
  //     } else {
  //       i++;
  //     }
  //   }
  // }

  void _updateSelectedCircle(CircleOptions changes) {
    controller!.updateCircle(_selectedCircle!, changes);
    setState(() {});
  }

  void _updateSelectedSymbol(Symbol selected, SymbolOptions changes) async {
    await controller!.updateSymbol(selected!, changes);
    setState(() {});
  }

  void updateTrackLine() async {
    await controller!.updateLine(mapLine!, LineOptions(geometry: gpxCoords));
    // setState(() {});
  }

  void _onSymbolTapped(Symbol symbol) async {
    LatLng latlon = LatLng(
      symbol.toGeoJson()['geometry']['coordinates'][0],
      symbol.toGeoJson()['geometry']['coordinates'][1],
    );

    print('TAPPED SYMBOL COORDINATES ---------------------------- $latlon');
    var (selected, type) = await searchSymbol(symbol);
    selectedNode = selected;
    selectedNodeType = type;
    _selectedSymbol = symbol;

    // if realNode is being dragged, then get the two virtualNodes neighbouring the dragging realNode
    neighbouringNodes = [];
    if (type == 'real') {
      if (selectedNode == 0) {
        neighbouringNodes.add(null);
      } else {
        neighbouringNodes.add(virtualSymbols[selectedNode - 1]);
      }
      if (selectedNode == realNodes.length - 1) {
        neighbouringNodes.add(null);
      } else {
        neighbouringNodes.add(virtualSymbols[selectedNode]);
      }
    }

    var draggable = _selectedSymbol!.options.draggable;

    draggable ??= false;
    draggable = !draggable;
    if (draggable) {
      _updateSelectedSymbol(
        _selectedSymbol!,
        const SymbolOptions(draggable: true, iconImage: 'selected-box'),
      );
    } else {
      _updateSelectedSymbol(
        _selectedSymbol!,
        const SymbolOptions(draggable: false, iconImage: 'node-box'),
      );
    }
  }

  void _onNodeDrag(id,
      {required current,
      required delta,
      required origin,
      required point,
      required eventType}) {
    final DragEventType type = eventType;
    switch (type) {
      case DragEventType.start:
        break;
      case DragEventType.drag:
        gpxCoords[selectedNode] = LatLng(current.latitude, current.longitude);
        // While node is dragging, redraw gpx line and neighbouring virtual nodes
        if (selectedNodeType == 'real') {}
        updateTrackLine();
        //Move neighbouring nodes
        if (selectedNode > 0) {
          LatLng latlon = halfSegmentSymbol(
              gpxCoords[selectedNode - 1], gpxCoords[selectedNode]);
          _updateSelectedSymbol(
            neighbouringNodes[0]!,
            SymbolOptions(
                geometry: latlon, draggable: false, iconImage: 'virtual-box'),
          );
        }

        if (selectedNode < gpxCoords.length - 1) {
          LatLng latlon = halfSegmentSymbol(
              gpxCoords[selectedNode], gpxCoords[selectedNode + 1]);
          _updateSelectedSymbol(
            neighbouringNodes[1]!,
            SymbolOptions(
                geometry: latlon, draggable: false, iconImage: 'virtual-box'),
          );
        }
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
          _selectedSymbol!,
          SymbolOptions(
              geometry: coord, draggable: false, iconImage: 'node-box'),
        );

        //Move neighbouring nodes
        if (selectedNode > 0) {
          LatLng latlon = halfSegmentSymbol(
              gpxCoords[selectedNode - 1], gpxCoords[selectedNode]);
          _updateSelectedSymbol(
            neighbouringNodes[0]!,
            SymbolOptions(
                geometry: latlon, draggable: false, iconImage: 'virtual-box'),
          );
        }

        if (selectedNode < gpxCoords.length - 1) {
          LatLng latlon = halfSegmentSymbol(
              gpxCoords[selectedNode], gpxCoords[selectedNode + 1]);
          _updateSelectedSymbol(
            neighbouringNodes[1]!,
            SymbolOptions(
                geometry: latlon, draggable: false, iconImage: 'virtual-box'),
          );
        }

        // removeSymbols();
        // addSymbols();

        break;
    }
  }

  void removeCircles() async {
    await controller!.removeCircles(mapCircles);
  }

  void addCircles() async {
    circleOptions = [];
    for (var latLng in gpxCoords) {
      circleOptions.add(CircleOptions(
          geometry: latLng,
          circleColor: "#00FF00",
          circleRadius: 8,
          draggable: false));
    }
    mapCircles = await controller!.addCircles(circleOptions);
  }

  List<SymbolOptions> makeSymbolOptions(nodes, symbolIcon) {
    final symbolOptions = <SymbolOptions>[];

    for (var idx = 0; idx < nodes.length; idx++) {
      LatLng coord = nodes[idx];
      symbolOptions.add(SymbolOptions(iconImage: symbolIcon, geometry: coord));
    }

    return symbolOptions;
  }

  void addRealSymbols() async {
    realSymbols =
        await controller!.addSymbols(makeSymbolOptions(realNodes, 'node-box'));
  }

  void addVirtualSymbols() async {
    virtualSymbols = await controller!
        .addSymbols(makeSymbolOptions(virtualNodes, 'virtual-box'));
  }

  void addSymbols() async {
    addRealSymbols();
    addVirtualSymbols();
  }

  void removeSymbols() async {
    await controller!.removeSymbols(virtualSymbols);
    await controller!.removeSymbols(realSymbols);
    realSymbols = [];
    virtualSymbols = [];
  }

  void resetSymbols() {
    removeSymbols();
    addSymbols();
  }

  void addLine(trackSegment) async {
    LatLng cur;
    LatLng next;

    if (mapLine != null) {
      controller!.removeLine(mapLine!);
      if (circlesVisible) {
        circlesVisible = false;
        removeSymbols();
      }
    }

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

      virtualNodes.add(halfSegmentSymbol(cur, next));

      //add a virtual node in the middle of each segment
      // Wpt halfNode = halfSegmentWpt(trackSegment[i], trackSegment[i + 1]);
      // rawGpx.add(
      //   (halfNode, virtualNode),
      // );
      // next = LatLng(halfNode.lat!, halfNode.lon!);
      // gpxCoords.add(next);
    }

    //Last point. No mid node required
    int last = trackSegment.length - 1;
    cur = LatLng(trackSegment[last].lat, trackSegment[last].lon);
    bounds.expand(cur);
    gpxCoords.add(cur);
    rawGpx.add(trackSegment[last]);

    mapLine = await controller!.addLine(
      LineOptions(
        geometry: gpxCoords,
        lineColor: "#ff0000",
        lineWidth: 1.5,
        lineOpacity: 0.9,
      ),
    );

    controller!.moveCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: bounds.southEast!,
          northeast: bounds.northWest!,
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

  // Uint8List convertStringToUint8List(String str) {
  //   final List<int> codeUnits = str.codeUnits;
  //   final Uint8List unit8List = Uint8List.fromList(codeUnits);
  //   return unit8List;
  // }

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
                      circlesVisible = !circlesVisible;
                      if (circlesVisible) {
                        addSymbols();
                        // addCircles();
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
                  realNodes = [];
                  virtualNodes = [];
                  realSymbols = [];
                  virtualSymbols = [];
                  gpxCoords = [];
                  rawGpx = [];

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
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: () {
          addImageFromAsset(controller!, "node-box", "assets/symbols/box.png");
          addImageFromAsset(
              controller!, "selected-box", "assets/symbols/selected-box.png");
          addImageFromAsset(
              controller!, "virtual-box", "assets/symbols/virtual-box.png");
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
