import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import './vars/vars.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ColorPickerPage extends StatefulWidget {
  final Color? trackColor;
  final double? trackWidth;

  const ColorPickerPage({
    Key? key,
    required this.trackColor,
    required this.trackWidth,
  }) : super(key: key);

  @override
  State<ColorPickerPage> createState() => _ColorPickerPageState();
}

class _ColorPickerPageState extends State<ColorPickerPage> {
  double? trackWidth;
  Color? trackColor;

  @override
  void initState() {
    trackWidth = widget.trackWidth ?? 3;
    trackColor = widget.trackColor ?? primaryColor;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).secondaryHeaderColor,
      appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.trackSettings),
          backgroundColor: Theme.of(context).secondaryHeaderColor,
          leading: BackButton(
            onPressed: () {
              print('on pressed back');
              Navigator.of(context).pop((
                trackColor,
                trackWidth,
              ));
            },
          )),
      body: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // const Padding(padding: EdgeInsets.only(top: 12)),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppLocalizations.of(context)!.trackColor,
                  style: TextStyle(fontSize: 20),
                ),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SizedBox(
                    width: kIsWeb ? 600 : 200,
                    height: kIsWeb ? 500 : null,
                    child: BlockPicker(
                      pickerColor: trackColor,
                      onColorChanged: (color) {
                        setState(() {
                          trackColor = color;
                        });
                      },
                    ),
                  ),
                ]),
                Text(
                  AppLocalizations.of(context)!.trackWidth,
                  style: TextStyle(fontSize: 20),
                ),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SizedBox(
                      width: kIsWeb ? 600 : 300,
                      child: Slider(
                        value: trackWidth!,
                        min: 1,
                        max: 15,
                        divisions: 15,
                        label: "${trackWidth!.round().toString()}",
                        activeColor: trackColor,
                        onChanged: (value) {
                          setState(() {
                            trackWidth = value;
                          });
                        },
                      )),
                ])
              ],
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).canvasColor,
                  foregroundColor: Colors.white),
              onPressed: () {
                Navigator.of(context).pop((
                  trackColor,
                  trackWidth,
                ));
              },
              child: Text(AppLocalizations.of(context)!.apply),
            ),
          ],
        ),
      ),
    );
  }
}
