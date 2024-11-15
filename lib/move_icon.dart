import 'package:flutter/material.dart';

class MoveIcon extends StatefulWidget {
  // const MoveIcon({super.key});
  final Color color1;
  final Color color2;

  const MoveIcon({
    Key? key,
    required this.color1,
    required this.color2,
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
        Positioned(
            top: 4,
            right: 4,
            child: Icon(Icons.square_rounded, color: widget.color2, size: 25)),
        Positioned(
          bottom: 4,
          left: 4,
          child: Icon(
            Icons.control_camera_rounded,
            size: 35,
            color: widget.color1,
          ),
        ),
      ],
    );
  }
}
