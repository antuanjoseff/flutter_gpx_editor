import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class UserSimplePreferences {
  static late SharedPreferences _preferences;

  static const _trackWidth = 'trackWidth';
  static const _trackColor = 'trackColor';

  static Future init() async =>
      _preferences = await SharedPreferences.getInstance();

  static Future setTrackWidth(double trkWidth) async =>
      await _preferences.setDouble(_trackWidth, trkWidth);

  static double? getTrackWidth() {
    final trackWidth = _preferences.getDouble(_trackWidth);
    return trackWidth == null ? null : trackWidth;
  }

  static Future setTrackColor(Color color) async =>
      await _preferences.setInt(_trackColor, color.value);

  static Color? getTrackColor() {
    final trackColor = _preferences.getInt(_trackColor);
    return trackColor == null ? null : Color(trackColor);
  }
}
