import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fluterius/src/characters/enemy_painter.dart';
import 'package:fluterius/src/characters/player_painter.dart';
import 'package:fluterius/src/enums/game_object_type.dart';
import 'package:fluterius/src/models/game_object.dart';
import 'package:fluterius/src/models/particle.dart';

class GameRenderer extends CustomPainter {
  GameObject? player;
  final List<GameObject> enemies;
  final List<GameObject> bullets;
  final List<Particle> particles;
  final Offset Function(Offset worldPos, double z) project;
  final double cameraZ;
  final double focalLength;
  final double playAreaRadius;
  final Offset playAreaCenter;
  final double tunnelZOffset;

  GameRenderer({
    required this.player,
    required this.enemies,
    required this.bullets,
    required this.particles,
    required this.project,
    required this.cameraZ,
    required this.focalLength,
    required this.playAreaRadius,
    required this.playAreaCenter,
    required this.tunnelZOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawTunnel(canvas, size);
    _drawPlayAreaBoundary(canvas);
    _drawParticles(canvas);
    _drawGameObjects(canvas);
  }

  void _drawTunnel(Canvas canvas, Size size) {
    final int numRings = 18;
    final int numRadials = 36;
    final double tunnelDepth = 2000;
    final double ringSpacing = tunnelDepth / numRings;
    final Color tunnelColor = Colors.grey.shade800;

    final double fadeStartZ = 50;
    final double fadeEndZ = 10;

    for (int i = 1; i < numRings; i++) {
      double zNear = (i * ringSpacing + cameraZ - tunnelZOffset) % tunnelDepth;
      double segmentOpacity =
          0.85 *
          (1 - ((zNear - fadeStartZ) / (fadeEndZ - fadeStartZ)).clamp(0, 1));

      final Paint tunnelPaint =
          Paint()
            ..color = tunnelColor.withValues(alpha: segmentOpacity)
            ..style = PaintingStyle.fill;

      if (zNear > 0) zNear += tunnelDepth;
      double zFar =
          ((i + 1) * ringSpacing + cameraZ - tunnelZOffset) % tunnelDepth;
      if (zFar < 0) zFar += tunnelDepth;

      if (zNear > 2500 || zFar > 2500) continue;

      for (int j = 0; j < numRadials; j++) {
        double angle1 = (2 * pi * j) / numRadials;
        double angle2 = (2 * pi * (j + 1)) / numRadials;
        Offset p1Near = project(
          playAreaCenter +
              Offset(
                cos(angle1) * playAreaRadius,
                sin(angle1) * playAreaRadius,
              ),
          zNear,
        );
        Offset p2Near = project(
          playAreaCenter +
              Offset(
                cos(angle2) * playAreaRadius,
                sin(angle2) * playAreaRadius,
              ),
          zNear,
        );
        Offset p2Far = project(
          playAreaCenter +
              Offset(
                cos(angle2) * playAreaRadius,
                sin(angle2) * playAreaRadius,
              ),
          zFar,
        );
        Offset p1Far = project(
          playAreaCenter +
              Offset(
                cos(angle1) * playAreaRadius,
                sin(angle1) * playAreaRadius,
              ),
          zFar,
        );
        Path quad =
            Path()
              ..moveTo(p1Near.dx, p1Near.dy)
              ..lineTo(p2Near.dx, p2Near.dy)
              ..lineTo(p2Far.dx, p2Far.dy)
              ..lineTo(p1Far.dx, p1Far.dy)
              ..close();
        canvas.drawPath(quad, tunnelPaint);
      }
    }

    _drawTunnelMesh(canvas, numRings, ringSpacing, tunnelDepth);
  }

  void _drawTunnelMesh(
    Canvas canvas,
    int numRings,
    double ringSpacing,
    double tunnelDepth,
  ) {
    final Paint meshPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: .08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;

    // Draw concentric rings
    for (int i = 1; i <= numRings; i++) {
      double ringZ = (i * ringSpacing + cameraZ - tunnelZOffset) % tunnelDepth;
      if (ringZ < 0) ringZ += tunnelDepth;
      final center2D = project(playAreaCenter, ringZ);
      final edge2D = project(playAreaCenter + Offset(playAreaRadius, 0), ringZ);
      final radius2D = (edge2D - center2D).distance;
      if (center2D.dx > 0 && center2D.dy > 0 && radius2D > 0) {
        canvas.drawCircle(center2D, radius2D, meshPaint);
      }
    }

    // Draw radial lines
    for (int j = 0; j < 36; j++) {
      double angle = (2 * pi * j) / 36;
      Offset start =
          playAreaCenter +
          Offset(cos(angle) * playAreaRadius, sin(angle) * playAreaRadius);
      Offset prev2D = project(
        start,
        (cameraZ + ringSpacing - tunnelZOffset) % tunnelDepth,
      );
      if (prev2D.dx < 0) {
        prev2D = project(
          start,
          (cameraZ + ringSpacing - tunnelZOffset) % tunnelDepth + tunnelDepth,
        );
      }

      for (int i = 2; i <= numRings; i++) {
        double ringZ =
            (i * ringSpacing + cameraZ - tunnelZOffset) % tunnelDepth;
        if (ringZ < 0) ringZ += tunnelDepth;
        Offset next3D =
            playAreaCenter +
            Offset(cos(angle) * playAreaRadius, sin(angle) * playAreaRadius);
        Offset next2D = project(next3D, ringZ);
        if (prev2D.dx > 0 && prev2D.dy > 0 && next2D.dx > 0 && next2D.dy > 0) {
          canvas.drawLine(prev2D, next2D, meshPaint);
        }
        prev2D = next2D;
      }
    }
  }

  void _drawPlayAreaBoundary(Canvas canvas) {
    final paintPlayArea =
        Paint()
          ..color = Colors.red.withValues(alpha: .3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

    final projectedCenter = project(playAreaCenter, 0);
    final projectedCircumferencePoint = project(
      playAreaCenter + Offset(playAreaRadius, 0),
      100,
    );
    final screenRadius =
        (projectedCircumferencePoint - projectedCenter).distance / 1.2;

    if (projectedCenter.dx >= 0 &&
        projectedCenter.dy >= 0 &&
        screenRadius > 0) {
      canvas.drawCircle(projectedCenter, screenRadius, paintPlayArea);
    }
  }

  /// Draw particles (scattering explosion effect)
  void _drawParticles(Canvas canvas) {
    for (final particle in particles) {
      final screenPos = project(particle.position, particle.z);
      final double progress =
          1.0 - (particle.timeLeft / particle.totalDuration).clamp(0.0, 1.0);
      final double worldSize = particle.size * (1.0 - progress * 0.1);
      final double effectiveZ = focalLength + particle.z - cameraZ;
      if (effectiveZ <= 0) continue;
      final double screenSize = worldSize * (focalLength / effectiveZ);
      final double alpha = (1.0 - progress).clamp(0.0, 1.0);
      final paint = Paint()..color = particle.color.withValues(alpha: alpha);
      if (screenPos.dx > 0 && screenPos.dy > 0 && screenSize > 0) {
        canvas.drawCircle(screenPos, screenSize, paint);
      }
    }
  }

  void _drawGameObjects(Canvas canvas) {
    List<GameObject> allObjects = [];
    if (player != null) allObjects.add(player!);
    allObjects.addAll(enemies);
    allObjects.addAll(bullets);
    allObjects.sort((a, b) => b.z.compareTo(a.z));

    for (final obj in allObjects) {
      final screenPos = project(obj.position, obj.z);
      if (screenPos.dx < 0 && screenPos.dy < 0) continue;
      if (obj.type == GameObjectType.player) {
        PlayerPainter(
          player: obj,
          project: project,
          focalLength: focalLength,
          cameraZ: cameraZ,
        ).paint(canvas, Size.infinite);
      } else if (obj.type == GameObjectType.enemy) {
        EnemyPainter(
          enemy: obj,
          project: project,
          focalLength: focalLength,
          cameraZ: cameraZ,
        ).paint(canvas, Size.infinite);
      } else {
        final effectiveZ = focalLength + obj.z - cameraZ;
        if (effectiveZ <= 0) continue;
        final radius = obj.baseRadius * (focalLength / effectiveZ);
        if (radius <= 0) continue;
        final paint = Paint()..color = obj.color;
        canvas.drawCircle(screenPos, radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GameRenderer oldDelegate) => true;
}
