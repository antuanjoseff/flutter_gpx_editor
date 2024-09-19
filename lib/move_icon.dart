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
      alignment: Alignment.topCenter,
      children: [
        Icon(
          Icons.square,
          size: 15,
          color: widget.color1,
        ),
        Icon(Icons.pan_tool_alt_sharp, color: widget.color2, size: 35),
      ],
    );
  }
}

