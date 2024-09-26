import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
              
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
    trackColor = widget.trackColor ?? Colors.pink;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.trackSettings),
          leading: BackButton(
            onPressed: () {
              print('on pressed back');
              Navigator.of(context).pop((
                trackColor,
                trackWidth,
              ));
            },
          )),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Padding(padding: EdgeInsets.all(4)),
          ColorPicker(
            pickerColor: trackColor!,
            enableAlpha: false,
            labelTypes: const [],
            onColorChanged: (color) {
              setState(() {
                trackColor = color;
              });
            },
          ),
          Text(AppLocalizations.of(context)!.trackWidth),
          Slider(
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
          ),
          TextButton(
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
    );
  }
}
