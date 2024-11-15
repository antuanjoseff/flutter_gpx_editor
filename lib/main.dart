import 'dart:convert';
import 'dart:convert';
import 'package:gpx_editor/my_maplibre.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:flutter/material.dart';
import 'package:geoxml/geoxml.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert' show utf8;
import 'controller.dart';
import 'color_picker_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:double_tap_to_exit/double_tap_to_exit.dart';
import 'util.dart';
import 'utils/user_simple_preferences.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UserSimplePreferences.init();
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
          canvasColor: Colors.pink,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.pink),
          useMaterial3: true,
        ),
        localizationsDelegates: const [
          AppLocalizations.delegate, // Add this line
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ca'), // catalan
          Locale('es'), // Spanish
          Locale('en'), // English
        ],
        home: MyHomePage());
  }
}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final Controller _controller = Controller();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  MapLibreMapController? controller;

  bool editMode = false;
  String? filename;
  String? fileName;

  List<Wpt> lineSegment = [];
  GeoXml? gpxOriginal;
  bool trackLoaded = false;
  List<Wpt> theGpx = [];

  Color? trackColor;
  double trackWidth = 3;

  @override
  void initState() {
    super.initState();
    trackWidth = UserSimplePreferences.getTrackWidth() ?? 3;
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _dialogBuilder(BuildContext context) {
    return showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.red),
                  const SizedBox(
                    width: 10,
                  ),
                  Text(AppLocalizations.of(context)!.errorOpeningFile),
                ],
              ),
            ),
            content: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppLocalizations.of(context)!.fileFormatNotSupported,
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                style: TextButton.styleFrom(
                  textStyle: Theme.of(context).textTheme.labelLarge,
                ),
                child: Text(AppLocalizations.of(context)!.accept),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return DoubleTapToExit(
      snackBar: SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.red,
        margin: const EdgeInsets.only(left: 50, right: 50, bottom: 30),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(50),
        ),

        //this will add margin to all side
        behavior: SnackBarBehavior.floating,
        content: Text(AppLocalizations.of(context)!.tapAgainToExit,
            textAlign: TextAlign.center),
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).canvasColor,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          // backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              GestureDetector(
                child: IconButton(
                  icon: const Icon(
                    Icons.folder,
                    color: Colors.white,
                  ),
                  tooltip: 'Open file',
                  onPressed: () async {
                    FilePickerResult? result =
                        await FilePicker.platform.pickFiles();

                    if (result != null) {
                      filename = result.files.single.path!.toString();
                      fileName = result.files.single.name.toString();

                      try {
                        final stream = await utf8.decoder
                            .bind(File(filename!).openRead())
                            .join();
                        gpxOriginal = await GeoXml.fromGpxString(stream);
                        if (gpxOriginal!.trks[0].trksegs.length >= 1) {
                          showSnackBar(
                            context,
                            AppLocalizations.of(context)!
                                .onEditFirstTrackSegment,
                          );
                        }
                        lineSegment = gpxOriginal!.trks[0].trksegs[0].trkpts;

                        // await _controller.removeTrackLine!;
                        editMode = false;
                        _controller.setEditMode!(editMode);
                        await _controller.loadTrack!(lineSegment);

                        setState(() {
                          trackLoaded = true;
                        });
                      } on Exception catch (e) {
                        _dialogBuilder(context);
                      }
                    } else {
                      // User canceled the picker
                    }
                  },
                ),
              ),
              Text(
                AppLocalizations.of(context)!.appTitle,
                style: const TextStyle(color: Colors.white, fontSize: 20),
              ),
            ],
          ),
          actions: [
            ...[
              trackLoaded
                  ? CircleAvatar(
                      backgroundColor: editMode
                          ? Theme.of(context).secondaryHeaderColor
                          : Colors.transparent,
                      child: IconButton(
                        icon: Icon(Icons.edit,
                            color: editMode ? Colors.pink : Colors.white),
                        tooltip: 'Show Snackbar',
                        onPressed: () async {
                          editMode = !editMode;
                          _controller.setEditMode!(editMode);
                          setState(() {});
                        },
                      ),
                    )
                  : Container()
            ],
            ...[
              gpxOriginal != null
                  ? IconButton(
                      icon: const Icon(
                        Icons.save,
                        color: Colors.white,
                      ),
                      tooltip: 'Show Snackbar',
                      onPressed: () async {
                        _controller.removeNodeSymbols!();
                        var gpx = GeoXml();
                        gpx.creator = "dart-gpx library";

                        gpx.metadata = gpxOriginal!.metadata;
                        List<Wpt> newGpx = [];
                        theGpx = _controller.getGpx!();
                        List<Wpt> wpts = _controller.getWpts!();

                        for (var idx = 0; idx < theGpx.length; idx++) {
                          Wpt wpt = theGpx[idx];
                          newGpx.add(wpt);
                        }

                        Trkseg trkseg = Trkseg(trkpts: newGpx);
                        gpx.trks = [
                          Trk(trksegs: [trkseg])
                        ];
                        gpx.wpts = wpts;

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
            ...[
              trackLoaded
                  ? CircleAvatar(
                      backgroundColor: Colors.transparent,
                      child: IconButton(
                        icon: const Icon(Icons.settings, color: Colors.white),
                        tooltip: 'Show Snackbar',
                        onPressed: () async {
                          editMode = false;
                          _controller.removeNodeSymbols!();
                          _controller.setEditMode!(editMode);

                          var result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ColorPickerPage(
                                    trackColor: trackColor,
                                    trackWidth: trackWidth),
                              ));
                          if (result != null) {
                            var (Color? trColor, double? trWidth) = result;
                            trackColor = trColor!;
                            trackWidth = trWidth!;

                            await UserSimplePreferences.setTrackWidth(trWidth);
                            await UserSimplePreferences.setTrackColor(
                                trackColor!);

                            LineOptions changes = LineOptions(
                                lineColor: trackColor!.toHexStringRGB(),
                                lineWidth: trackWidth);

                            _controller.updateTrack!(changes);
                          }

                          setState(() {});
                        },
                      ),
                    )
                  : Container()
            ],
          ],
        ),
        body: MyMapLibre(scaffoldKey: _scaffoldKey, controller: _controller),
      ),
    );
  }
}
