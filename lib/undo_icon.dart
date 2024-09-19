import 'package:flutter/material.dart';

class UndoIcon extends StatelessWidget {
  const UndoIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const 
        Icon(
          Icons.undo,
          size: 25,
          color: Colors.black,
        );
  }
}