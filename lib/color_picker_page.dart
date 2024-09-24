import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ColorPickerPage extends StatefulWidget {
  const ColorPickerPage({super.key});

  @override
  State<ColorPickerPage> createState() => _ColorPickerPageState();
}

class _ColorPickerPageState extends State<ColorPickerPage> {
  double trackWidth = 3;
  Color trackColor = Colors.orange;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('COLOR PICKER'),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Padding(padding: EdgeInsets.all(4)),
          ColorPicker(
            pickerColor: trackColor,
            enableAlpha: false,
            labelTypes: const [],
            onColorChanged: (color) {
              setState(() {
                trackColor = color;
              });
            },
          ),
          const Text('Amplada del track'),
          Slider(
            value: trackWidth,
            max: 8,
            divisions: 10,
            label: "${trackWidth.round().toString()}",
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
                trackWidth,
                trackColor,
              ));
            },
            child: const Text('Aplica'),
          ),
        ],
      ),
    );
  }
}
