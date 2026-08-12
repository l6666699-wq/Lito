import 'package:flutter/animation.dart';

abstract final class AppMotion {
  static const Duration instant = Duration(milliseconds: 80);
  static const Duration fast = Duration(milliseconds: 100);
  static const Duration normal = Duration(milliseconds: 140);

  static const Duration dialogEnter = Duration(milliseconds: 160);
  static const Duration dialogExit = Duration(milliseconds: 110);
  static const Duration dialogBarrier = Duration(milliseconds: 120);

  static const Duration popoverEnter = Duration(milliseconds: 110);
  static const Duration popoverExit = Duration(milliseconds: 80);

  static const Duration tree = Duration(milliseconds: 160);
  static const Duration page = Duration(milliseconds: 140);
  static const Duration theme = Duration(milliseconds: 220);
  static const Duration completion = Duration(milliseconds: 120);

  static const Curve enterCurve = Curves.easeOutCubic;
  static const Curve exitCurve = Curves.easeInCubic;
  static const Curve standardCurve = Curves.easeInOutCubic;

  static const Color dialogBarrierColor = Color(0x26000000);
}
