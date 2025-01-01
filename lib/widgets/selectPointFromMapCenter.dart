import 'package:flutter/material.dart';
import 'package:gpx_editor/vars/vars.dart';

class SelectPointFromMapCenter extends StatelessWidget {
  final constraints;
  const SelectPointFromMapCenter({
    super.key,
    required this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        child: Center(
          child: CircleAvatar(
              radius: 35,
              backgroundColor: primaryColor.withOpacity(0.6),
              child: Icon(
                Icons.add,
                size: 40,
                color: white,
              )),
        ));
  }
}
