import 'package:flutter/material.dart';
import 'package:fluterius/src/enums/game_object_type.dart';

class GameObject {
  Offset position;
  double z;
  double baseRadius;
  Color color;
  GameObjectType type;
  Offset velocity;
  double angle;

  GameObject({
    required this.position,
    required this.z,
    required this.baseRadius,
    required this.color,
    required this.type,
    this.velocity = Offset.zero,
    this.angle = 0,
  });

  GameObject copyWith({
    Offset? position,
    double? z,
    double? baseRadius,
    Color? color,
    GameObjectType? type,
    Offset? velocity,
    double? angle,
  }) {
    return GameObject(
      position: position ?? this.position,
      z: z ?? this.z,
      baseRadius: baseRadius ?? this.baseRadius,
      color: color ?? this.color,
      type: type ?? this.type,
      velocity: velocity ?? this.velocity,
      angle: angle ?? this.angle,
    );
  }
}
