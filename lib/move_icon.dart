import 'package:flutter/material.dart';

class MoveIcon extends StatelessWidget {
  const MoveIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      alignment: Alignment.topRight,
      children: [
        Icon(
          Icons.pan_tool_alt_outlined,
          color: Colors.black,
        ),
        Icon(
          Icons.circle,
          size: 10,
          color: Colors.green,
        ),
      ],
    );
  }
}
