import 'package:flutter/material.dart';

class DeleteIcon extends StatelessWidget {
  const DeleteIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const Stack(
      alignment: Alignment.topRight,
      children: [
        Icon(Icons.square_rounded, color: Colors.grey, size: 25),
        Icon(
          Icons.delete,
          size: 20,
          color: Colors.red,
        ),
      ],
    );
  }
}
