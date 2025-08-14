import 'package:flutter/material.dart';
import 'package:fluterius/src/models/game_object.dart';

class PlayerPainter extends CustomPainter {
  final GameObject player;
  final Offset Function(Offset worldPos, double z) project;
  final double focalLength;
  final double cameraZ;

  PlayerPainter({
    required this.player,
    required this.project,
    required this.focalLength,
    required this.cameraZ,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final projectedPlayer = project(player.position, player.z);
    if (projectedPlayer.dx < 0 || projectedPlayer.dy < 0) return;

    final playerPaint = Paint()..color = player.color;
    final effectiveZ = focalLength + player.z - cameraZ;
    if (effectiveZ <= 0) return;
    final playerRadius = player.baseRadius * (focalLength / effectiveZ);

    if (playerRadius <= 0) return;

    canvas.drawCircle(projectedPlayer, playerRadius, playerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}