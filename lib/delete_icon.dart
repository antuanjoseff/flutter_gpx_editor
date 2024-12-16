import 'package:flutter/material.dart';

class DeleteIcon extends StatefulWidget {
  // const DeleteIcon({super.key});
  final Color color;
  final double? size;

  const DeleteIcon({
    Key? key,
    required this.color,
    required this.size,
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
        Icon(
          Icons.cancel_presentation_rounded,
          size: widget.size,
          color: widget.color,
        ),
      ],
    );
  }
}
