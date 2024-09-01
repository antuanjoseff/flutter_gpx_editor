import 'dart:convert';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:flutter/material.dart';
import 'package:geoxml/geoxml.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:external_path/external_path.dart';
import 'util.dart';
import 'dart:typed_data';
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
  List<Symbol> mapSymbols = [];
  bool circlesVisible = false;
  List<CircleOptions> circleOptions = [];
  List<Wpt> rawGpx = [];
  String? filename;
  String? fileName;
  List<(int, Wpt, String)> edits = []; 
  Circle? _selectedCircle;
  Symbol? _selectedSymbol;
  int selectedNode = -1;

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
    controller!.onFeatureDrag.add(_onCircleDrag);
  }

  void undoMove(idx, wpt) async{
    rawGpx[idx] = wpt;
    LatLng latlng = LatLng(wpt.lat!, wpt.lon!);
    gpxCoords[idx] = latlng;
    
    controller!.removeLine(mapLine!);
        
    mapLine = await controller!.addLine(
      LineOptions(
        geometry: gpxCoords,
        lineColor: "#ff0000",
        lineWidth: 1.5,
        lineOpacity: 0.9,
      ),
    );

    Symbol symbol = mapSymbols.first;
    symbol.toGeoJson()['geometry']['coordinates'] = latlng;

    mapSymbols.insert(
      idx,
      symbol
    );
    removeSymbols();
    addSymbols();
    setState(() {});   
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

  int searchNode(Circle circle) {
    var search = LatLng(
      circle.toGeoJson()['geometry']['coordinates'][1],
      circle.toGeoJson()['geometry']['coordinates'][0]
    );
    bool found = false;
    int i = 0;
    
    while (!found && i < mapCircles.length) {
      if (mapCircles[i].options.geometry!.latitude == search.latitude && mapCircles[i].options.geometry!.longitude == search.longitude ) {
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

  Future<int> searchSymbol(Symbol symbol) async{
    var search = LatLng(
      symbol.toGeoJson()['geometry']['coordinates'][1],
      symbol.toGeoJson()['geometry']['coordinates'][0]
    );
    bool found = false;
    int i = 0;
    
    while (!found && i < mapSymbols.length) {
      if (mapSymbols[i].options.geometry!.latitude == search.latitude && mapSymbols[i].options.geometry!.longitude == search.longitude ) {
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
    setState(() {
    });
  }

  void _updateSelectedSymbol(SymbolOptions changes) async {
    await controller!.updateSymbol(_selectedSymbol!, changes);
    // setState(() {
    // });
  }

  void updateTrackLine(int selectedNode, LatLng current, LatLng origin) async{
    gpxCoords[selectedNode] = current;
    
    await controller!.updateLine(mapLine!, LineOptions(geometry: gpxCoords));
    // setState(() {});       
  }

  void _onSymbolTapped(Symbol symbol) async{
     selectedNode = await searchSymbol(symbol);
     print('---------SELECTED NODE----------------------$selectedNode');
    _selectedSymbol = symbol;

    var draggable = _selectedSymbol!.options.draggable;
    
    draggable ??= false;
    _updateSelectedSymbol(
      SymbolOptions(
        draggable: !draggable,
        iconImage: 'selected-box'
      ),
    );

    Wpt e = rawGpx[selectedNode];

    Wpt previous = Wpt(
      lat: e.lat, lon: e.lon, ele: e.ele, time: e.time, magvar: e.magvar,
      geoidheight: e.geoidheight, name: e.name, cmt: e.cmt, desc: e.desc,
      src: e.src, links: e.links, sym: e.sym, type: e.type, fix: e.fix,
      sat: e.sat, hdop: e.hdop, vdop: e.vdop, pdop: e.pdop, ageofdgpsdata: e.ageofdgpsdata,
      dgpsid: e.dgpsid, extensions: e.extensions
    );

    edits.add((selectedNode, previous, 'moved'),);
  }

  void _onCircleTapped(Circle circle) {
    selectedNode = searchNode(circle);
    _selectedCircle = circle;

    var draggable = _selectedCircle!.options.draggable;
    
    draggable ??= false;
    
    _updateSelectedCircle(
      CircleOptions(
        draggable: !draggable,
        circleRadius: draggable ? 8 : 20,
        circleColor: draggable ? "#00FF00": "#FF0000"
      ),
    );
    
    // deleteCircle('circle', circle.id, circle);
  }

  void _onCircleDrag(id,
      {required current,
      required delta,
      required origin,
      required point,
      required eventType}) {
        final DragEventType type = eventType;
        switch (type) {
          case DragEventType.start:
            // TODO: Handle this case.
            break;
          case DragEventType.drag:
            // TODO: Handle this case.
            updateTrackLine(selectedNode, current, origin);
            break;
          case DragEventType.end:
            rawGpx[selectedNode].lat = current.latitude;
            rawGpx[selectedNode].lon = current.longitude;

            updateTrackLine(selectedNode, current, origin);
            _updateSelectedSymbol(
              SymbolOptions(
                geometry: gpxCoords[selectedNode],
                draggable: false,
                iconImage: 'node-box'
              ),
            );            
            
            break;
        }
    }

  void removeCircles() async {
    await controller!.removeCircles(mapCircles);    
  }

  void removeSymbols() async {
    await controller!.removeSymbols(mapSymbols);    
  }

  void addCircles() async {
    circleOptions = [];
    for (var latLng in gpxCoords) {
      circleOptions
          .add(CircleOptions(geometry: latLng, circleColor: "#00FF00", circleRadius: 8, draggable: false ));
    }
    mapCircles = await controller!.addCircles(circleOptions);
  }

  void addSymbols() async {
    mapSymbols = await controller!.addSymbols(makeSymbolOptionsForFillOptions());
  }

  List<SymbolOptions> makeSymbolOptionsForFillOptions() {
    final symbolOptions = <SymbolOptions>[];
    for (var idx = 0; idx < gpxCoords.length - 1; idx++) {
      LatLng coord = gpxCoords[idx];
    
      if (idx % 2 ==0 ) {
        symbolOptions.add(SymbolOptions(iconImage: 'node-box', geometry: coord));        
      } else {
        symbolOptions.add(SymbolOptions(iconImage: 'virtual-box', geometry: coord));
      }
      
    }
    return symbolOptions;
  }


  void addLine(trackSegment) async{
    LatLng cur;
    LatLng next;
      
    if (mapLine != null) {
      gpxCoords = [];
      rawGpx = [];
      controller!.removeLine(mapLine!);
      if (circlesVisible) {
        circlesVisible = false;
        removeSymbols();
      }
    }

    Bounds bounds  = Bounds(
      LatLng(trackSegment.first.lat, trackSegment.first.lon), 
      LatLng(trackSegment.first.lat, trackSegment.first.lon)
    );
    
    for (var i = 0; i < trackSegment.length - 1; i++) {
      cur = LatLng(trackSegment[i].lat, trackSegment[i].lon);
      bounds.expand(cur);
      gpxCoords.add(cur);
      rawGpx.add(trackSegment[i]);
      
      //add a virtual node in the middle of each segment
      Wpt halfNode = halfSegmentNode(trackSegment[i], trackSegment[i+1]);
      rawGpx.add(halfNode);

      next = LatLng(halfNode.lat!, halfNode.lon!);
      gpxCoords.add(next);
    }    

    //Last point. No mid node required
    int last = trackSegment.length - 1;
    cur = LatLng(trackSegment[last].lat, trackSegment[last].lon);
    bounds.expand(cur);
    gpxCoords.add(cur);
    rawGpx.add(trackSegment[last]);

    print('                        RAWGPX LENGTH ${rawGpx.length}');

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
          ...[edits.isNotEmpty ? IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Show Snackbar',
            onPressed: () async {
              undo();
            },
          ): Container()],
          ...[gpxOriginal != null ? IconButton(
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
          ): Container()],
          ...[gpxOriginal != null ? IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Show Snackbar',
            onPressed: () async {
              removeSymbols();
              var gpx = GeoXml();
              gpx.creator = "dart-gpx library";
              
              gpx.metadata = gpxOriginal!.metadata;
              List<Wpt> newGpx = [];
              for (var idx = 0; idx < rawGpx.length; idx++ ){
                if (idx % 2 == 0) {
                  newGpx.add(rawGpx[idx]);
                }
              }

              print('                        NEWGPX LENGTH ${newGpx.length}');
              Trkseg trkseg = Trkseg(trkpts: newGpx);

              gpx.trks = [
                Trk(
                  trksegs: [trkseg])
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
          ) : Container()],
          IconButton(
            icon: const Icon(Icons.folder),
            tooltip: 'Show Snackbar',
            onPressed: () async {
              FilePickerResult? result = await FilePicker.platform.pickFiles();
              if (result != null) {
                filename = result.files.single.path!.toString();
                fileName = result.files.single.name.toString();

                // TO DO. Check for invalid file format
                final stream = await utf8.decoder.bind(
                  File(filename!).openRead()
                ).join();
                 
                gpxOriginal = await GeoXml.fromGpxString(stream);
                
                setState(() {
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
            addImageFromAsset(controller!, "selected-box", "assets/symbols/selected-box.png");
            addImageFromAsset(controller!, "virtual-box", "assets/symbols/virtual-box.png");
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

  expand(LatLng coord){
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
