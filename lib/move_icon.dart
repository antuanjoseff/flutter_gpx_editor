import 'package:flutter/material.dart';

class MoveIcon extends StatefulWidget {
  // const MoveIcon({super.key});
  final Color color;
  final double? size;

  const MoveIcon({
    Key? key,
    required this.color,
    required this.size,
  }) : super(key: key);

  @override
  State<MoveIcon> createState() => _MoveIconState();
}

class _MoveIconState extends State<MoveIcon> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        Icon(
          Icons.control_camera_rounded,
          size: widget.size,
          color: widget.color,
        ),
      ],
    );
  }
}
