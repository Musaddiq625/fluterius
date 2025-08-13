import 'package:flutter/material.dart';

class Particle {
  Offset position;
  double z;
  Offset velocity;
  double vz;
  Color color;
  double timeLeft;
  final double totalDuration;
  double size;

  Particle({
    required this.position,
    required this.z,
    required this.velocity,
    required this.vz,
    required this.color,
    required this.timeLeft,
    required this.totalDuration,
    required this.size,
  });
}
