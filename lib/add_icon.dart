import 'package:flutter/material.dart';

class AddIcon extends StatefulWidget {
  // const AddIcon({super.key});
  final Color color1;
  final Color color2;

  const AddIcon({
    Key? key,
    required this.color1,
    required this.color2,
  }) : super(key: key);

  @override
  State<AddIcon> createState() => _AddIconState();
}

class _AddIconState extends State<AddIcon> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        Positioned(
            top: 4,
            right: 4,
            child: Icon(Icons.square_rounded, color: widget.color2, size: 20)),
        Positioned(
          bottom: 4,
          left: 4,
          child: Icon(
            Icons.add_box,
            size: 25,
            color: widget.color1,
          ),
        ),
      ],
    );
  }
}
