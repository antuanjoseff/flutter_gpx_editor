import 'package:flutter/material.dart';
import './vars/vars.dart';

class UndoIcon extends StatelessWidget {
  final Color color;
  final double? size;
  const UndoIcon({
    super.key,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.undo,
      size: size,
      color: color,
    );
  }
}
