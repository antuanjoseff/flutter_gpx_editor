import 'package:flutter/material.dart';

class DeleteIcon extends StatefulWidget {
  // const DeleteIcon({super.key});
  final Color color1;
  final Color color2;

  const DeleteIcon({
    Key? key,
    required this.color1,
    required this.color2,
  }) : super(key: key);

  @override
  State<DeleteIcon> createState() => _DeleteIconState();
}

class _DeleteIconState extends State<DeleteIcon> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        // Positioned(
        //     top: 4,
        //     right: 4,
        //     child: Icon(Icons.square_rounded, color: widget.color2, size: 25)),
        Icon(
          Icons.cancel_presentation_rounded,
          size: 35,
          color: widget.color1,
        ),
      ],
    );
  }
}
