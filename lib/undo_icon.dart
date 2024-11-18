import 'package:flutter/material.dart';
import './vars/vars.dart';

class UndoIcon extends StatelessWidget {
  final Color color;
  const UndoIcon({
    super.key,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.undo,
      size: 35,
      color: color,
    );
  }
}
