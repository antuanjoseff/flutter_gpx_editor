import 'package:flutter/material.dart';

class AddIcon extends StatefulWidget {
  // const AddIcon({super.key});
  final Color color;
  final double? size;

  const AddIcon({
    Key? key,
    required this.color,
    required this.size,
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
        Icon(
          Icons.add_to_photos_outlined,
          size: widget.size,
          color: widget.color,
        ),
      ],
    );
  }
}
