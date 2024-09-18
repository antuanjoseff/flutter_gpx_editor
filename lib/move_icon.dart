import 'package:flutter/material.dart';
import 'package:icon_craft/icon_craft.dart';

class MoveIcon extends StatelessWidget {
  const MoveIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      alignment: Alignment.topCenter,
      children: [
        Icon(
          Icons.square,
          size: 15,
          color: Colors.green,
        ),
        Icon(Icons.pan_tool_alt_sharp, color: Colors.black, size: 35),
      ],
    );
  }
}
