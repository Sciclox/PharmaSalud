import 'package:flutter/material.dart';

class SnackbarManager {
  static bool _enabled = true;

  static void disable() => _enabled = false;
  static void enable() => _enabled = true;

  static void show(BuildContext context, SnackBar snackbar) {
    if (_enabled) {
      ScaffoldMessenger.of(context).showSnackBar(snackbar);
    }
  }
}
