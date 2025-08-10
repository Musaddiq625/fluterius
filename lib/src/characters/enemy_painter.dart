import 'package:flutter/material.dart';
import 'package:fluterius/src/models/game_object.dart';

class EnemyPainter extends CustomPainter {
  final GameObject enemy;
  final Offset Function(Offset worldPos, double z) project;
  final double focalLength;
  final double cameraZ;

  EnemyPainter({
    required this.enemy,
    required this.project,
    required this.focalLength,
    required this.cameraZ,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final projectedEnemy = project(enemy.position, enemy.z);
    if (projectedEnemy.dx < 0 || projectedEnemy.dy < 0) return;

    final enemyPaint = Paint()..color = enemy.color;
    // Corrected radius calculation
    final effectiveZ = focalLength + enemy.z - cameraZ;
    if (effectiveZ <= 0) return;
    final enemyRadius = enemy.baseRadius * (focalLength / effectiveZ);

    if (enemyRadius <= 0) return;

    canvas.drawCircle(projectedEnemy, enemyRadius, enemyPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
