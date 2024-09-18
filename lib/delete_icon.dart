import 'package:flutter/material.dart';
import 'package:icon_craft/icon_craft.dart';

class DeleteIcon extends StatelessWidget {
  const DeleteIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      alignment: Alignment.topRight,
      children: [
        Icon(Icons.square_rounded, color: Colors.green, size: 20),
        Icon(
          Icons.cancel,
          size: 15,
          color: Colors.red,
        ),
      ],
    );
  }
}
