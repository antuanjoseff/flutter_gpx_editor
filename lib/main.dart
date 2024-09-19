import 'dart:convert';
import 'package:gpx_editor/my_maplibre.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:flutter/material.dart';
import 'package:geoxml/geoxml.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert' show utf8;
import 'package:double_back_to_close/double_back_to_close.dart';
import 'controller.dart';

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
        child: MyHomePage(),
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
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final Controller _controller = Controller();

  MapLibreMapController? controller;

  bool editMode = false;
  String? filename;
  String? fileName;

  List<Wpt> lineSegment = [];
  GeoXml? gpxOriginal;
  bool trackLoaded = false;
  List<Wpt> theGpx = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('GPX'),
        actions: [
          ...[
            trackLoaded
                ? IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Show Snackbar',
                    onPressed: () async {
                      editMode = !editMode;
                      bool draggableMode = false;
                      if (editMode) {
                        _controller.addMapSymbols!(draggableMode);
                        _controller.showEditIcons!();
                      } else {
                        _controller.removeMapSymbols!();
                        _controller.hideEditIcons!();
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
                      _controller.removeMapSymbols!();
                      var gpx = GeoXml();
                      gpx.creator = "dart-gpx library";

                      gpx.metadata = gpxOriginal!.metadata;
                      List<Wpt> newGpx = [];
                      theGpx = _controller.getGpx!();
                      for (var idx = 0; idx < theGpx.length; idx++) {
                        Wpt wpt = theGpx[idx];
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

                lineSegment = gpxOriginal!.trks[0].trksegs[0].trkpts;
                await _controller.loadTrack!(lineSegment);
                await _controller.addMapSymbols!;

                setState(() {
                  trackLoaded = true;                
                });
              } else {
                // User canceled the picker
              }
            },
          ),
        ],
      ),
      body: MyMapLibre(controller: _controller),
    );
  }
}
