import 'package:flutter/gestures.dart';

import './vars/vars.dart';
import 'dart:convert';
import 'package:gpx_editor/my_maplibre.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:flutter/material.dart';
import 'package:geoxml/geoxml.dart';
import 'dart:io';
import 'dart:convert' show utf8;
import 'controller.dart';
import 'mapLayers.dart';
import 'color_picker_page.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:double_tap_to_exit/double_tap_to_exit.dart';
import 'util.dart';
import 'utils/user_simple_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

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
          canvasColor: primaryColor,
          colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
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

  final bool _isIOS = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

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

  Future<void> _saveFile() async {
    final String fileName = _nameController.text;
    // This demonstrates using an initial directory for the prompt, which should
    // only be done in cases where the application can likely predict where the
    // file will be saved. In most cases, this parameter should not be provided,
    // and in the web, path_provider shouldn't even be called.
    final String? initialDirectory =
        kIsWeb ? null : (await getApplicationDocumentsDirectory()).path;
    final FileSaveLocation? result = await getSaveLocation(
      initialDirectory: initialDirectory,
      suggestedName: fileName,
    );
    if (result == null) {
      // Operation was canceled by the user.
      return;
    }

    final String text = _contentController.text;
    final Uint8List fileData = Uint8List.fromList(text.codeUnits);
    const String fileMimeType = 'text/plain';
    final XFile textFile =
        XFile.fromData(fileData, mimeType: fileMimeType, name: fileName);

    await textFile.saveTo(result.path);
  }

  Future<(String, String)> openTextFile(BuildContext context) async {
    const XTypeGroup typeGroup = XTypeGroup(
      label: 'xml',
      // extensions: <String>[],
    );
    // This demonstrates using an initial directory for the prompt, which should
    // only be done in cases where the application can likely predict where the
    // file would be. In most cases, this parameter should not be provided.
    final String? initialDirectory =
        kIsWeb ? null : (await getApplicationDocumentsDirectory()).path;
    final XFile? file = await openFile(
      // acceptedTypeGroups: <XTypeGroup>[typeGroup],
      initialDirectory: initialDirectory,
    );
    if (file == null) {
      // Operation was canceled by the user.
      return ('', '');
    }
    final String fileName = file.name;
    if (!fileName.toLowerCase().endsWith('.gpx')) {
      return ('Incorrect format file', '');
      // await showDialog<void>(
      //   context: context,
      //   builder: (BuildContext context) =>
      //       TextDisplay('INCORRECT FORMAT', 'Chose another file'),
      // );
    } else {
      final String fileContent = await file.readAsString();
      return (fileName, fileContent);
      // if (context.mounted) {
      //   await showDialog<void>(
      //     context: context,
      //     builder: (BuildContext context) => TextDisplay(fileName, fileContent),
      //   );
      // }
    }
  }

  void setBaseLayer(layer) {
    _controller.setBaseLayer!(layer);
  }

  @override
  Widget build(BuildContext context) {
    return DoubleTapToExit(
      snackBar: SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: primaryColor,
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
        drawer: GestureDetector(
          onTap: () {
            Navigator.of(context).pop();
          },
          child: SizedBox(
              width: 300,
              child: Container(
                  color: Theme.of(context).canvasColor,
                  child: MapLayers(controller: _controller))),
        ),
        appBar: AppBar(
          backgroundColor: Theme.of(context).canvasColor,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          // backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          automaticallyImplyLeading: false,
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
                    // FilePickerResult? result =
                    //     await FilePicker.platform.pickFiles();

                    var (msg, content) = await openTextFile(context);
                    if (content == '') {
                      if (msg != '') {
                        TextDisplay(msg, 'Choose a GPX file');
                      }
                      return;
                    }
                    if (content != null) {
                      filename = msg;
                      // fileName = result.files.single.name.toString();

                      try {
                        // final stream = await utf8.decoder
                        //     .bind(File(filename!).openRead())
                        //     .join();
                        gpxOriginal = await GeoXml.fromGpxString(content);
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
                            color: editMode ? primaryColor : white),
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

/// Widget that displays a text file in a dialog
class TextDisplay extends StatelessWidget {
  /// Default Constructor
  const TextDisplay(this.fileName, this.fileContent, {super.key});

  /// File's name
  final String fileName;

  /// File to display
  final String fileContent;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(fileName),
      content: Scrollbar(
        child: SingleChildScrollView(
          child: Text(fileContent),
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('Close'),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
