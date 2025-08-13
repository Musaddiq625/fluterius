import 'package:flutter/material.dart';

class Explosion {
  Offset position;
  double z;
  double timeLeft;
  final double totalDuration;
  final Color color;

  Explosion({
    required this.position,
    required this.z,
    required this.timeLeft,
    this.totalDuration = 0.4,
    this.color = Colors.orange,
  });
}
