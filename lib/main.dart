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
  final GlobalKey<_MyHomePageState> _childKey = GlobalKey();
  final Controller _controller = Controller();

  MapLibreMapController? controller;

  bool editMode = false;
  String? filename;
  String? fileName;

  List<Wpt> lineSegment = [];
  GeoXml? gpxOriginal;
  bool gpxLoaded = false;

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
                  // get only first track segment
                  lineSegment = gpxOriginal!.trks[0].trksegs[0].trkpts;
                  // addLine(lineSegment);
                  // _controller.addLine!(lineSegment);
                  _controller.loadTrack!(lineSegment);
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
