import 'package:flutter/material.dart';

/// Consistent spacing values throughout the app.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  /// Default horizontal padding for screens.
  static const EdgeInsets screenPadding =
      EdgeInsets.symmetric(horizontal: 24, vertical: 16);
}
