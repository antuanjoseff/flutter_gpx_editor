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
    return const Stack(
      alignment: Alignment.topRight,
      children: [
        Icon(Icons.square_rounded, color: Colors.grey, size: 30),
        Icon(
          Icons.control_camera_rounded,
          size: 20,
          color: Colors.red,
        ),
      ],
    );
  }
}

