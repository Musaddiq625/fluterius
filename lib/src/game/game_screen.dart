import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:fluterius/src/characters/enemy_painter.dart';
import 'package:fluterius/src/characters/player_painter.dart';
import 'package:fluterius/src/constants/asset_constants.dart';
import 'package:fluterius/src/dialogs/game_over_dialog.dart';
import 'package:fluterius/src/dialogs/game_start_dialog.dart';
import 'package:fluterius/src/enums/game_object_type.dart';
import 'package:fluterius/src/models/game_object.dart';

class FluteriusGameWidget extends StatefulWidget {
  const FluteriusGameWidget({super.key});

  @override
  FluteriusGameState createState() => FluteriusGameState();
}

class FluteriusGameState extends State<FluteriusGameWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  GameObject? _player;
  final List<GameObject> _enemies = [];
  final List<GameObject> _bullets = [];

  final double _cameraZ = -200;
  final double _focalLength = 100;
  Size _screenSize = Size.zero;

  final double _playAreaRadius = 1500;
  final Offset _playAreaCenter = Offset.zero;

  double _tunnelZOffset = 200;
  final _tunnelDepth = 9800;

  final _maxLives = 3;
  late int _lives = _maxLives;
  int _score = 0;
  final _maxTime = 50;
  late int _remainingTime = _maxTime;
  late Timer _remainingTimeTimer;

  final bgPlayer = AudioPlayer();

  String _getFormattedTime() {
    final minutes = _remainingTime ~/ 60;
    final seconds = _remainingTime % 60;
    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');
    return '$minutesStr:$secondsStr';
  }

  /// Initializes a [_maxTime] second countdown timer for the game
  void _initTimer() {
    _score = 0;
    _remainingTime = _maxTime;
    _remainingTimeTimer = Timer.periodic(Duration(seconds: 1), (_) {
      _remainingTime--;
      if (_remainingTime <= 0) {
        _remainingTimeTimer.cancel();
        _endGame(timeEnded: true);
      }
    });
  }

  Offset _project(Offset worldPos, double z) {
    if (_screenSize == Size.zero) {
      return Offset.zero;
    }
    final cx = _screenSize.width / 2;
    final cy = _screenSize.height / 2;
    final effectiveZ = _focalLength + z - _cameraZ;
    if (effectiveZ <= 0) {
      return const Offset(-1, -1);
    }

    final scale = _focalLength / effectiveZ;
    return Offset(cx + (worldPos.dx * scale), cy + (worldPos.dy * scale));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => GameStartDialog(
              onStart: () {
                Navigator.of(context).pop();
                _startGame();
              },
            ),
      );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _remainingTimeTimer.cancel();
    bgPlayer.stop();
    bgPlayer.dispose();
    super.dispose();
  }

  void _initPlayer() {
    // Bottom of the circle (positive Y axis)
    double initialPlayerAngle = pi / 2;
    _player = GameObject(
      position:
          _playAreaCenter +
          Offset(
            cos(initialPlayerAngle) * _playAreaRadius,
            sin(initialPlayerAngle) * _playAreaRadius,
          ),
      z: 200,
      baseRadius: 80,
      color: Colors.blue,
      type: GameObjectType.player,
      angle: initialPlayerAngle,
    );
  }

  void _startGame() {
    bgPlayer.setAsset(AssetConstants.soundtrack).then((_) => bgPlayer.play());
    _initTimer();
    _initPlayer();
    _animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(_updateGame)
          ..repeat();
  }

  /// Showing 'end game' dialog
  void _endGame({required bool timeEnded}) async {
    _animationController.stop();
    _remainingTimeTimer.cancel();
    bgPlayer.stop();
    _endGameSound();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return GameOverDialog(
          score: _score,
          timeEnded: timeEnded,
          onRestart: () {
            _reset();
            setState(() {});
          },
        );
      },
    );
  }

  /// Spawn Enemies at far end of tunnel
  void _spawnEnemy() {
    final rnd = Random();
    double enemyAngle = rnd.nextDouble() * 2 * pi;
    double tunnelDepth = 2500;
    _enemies.add(
      GameObject(
        position:
            _playAreaCenter +
            Offset(
              cos(enemyAngle) * _playAreaRadius,
              sin(enemyAngle) * _playAreaRadius,
            ),
        z: tunnelDepth,
        baseRadius: 50,
        color: Colors.red,
        type: GameObjectType.enemy,
        angle: enemyAngle,
      ),
    );
  }

  Future<void> _fireSound() async {
    final player = AudioPlayer();
    await player.setAsset(AssetConstants.fire);
    player.play();
    Future.delayed(Duration(milliseconds: 500)).then((_) {
      player.dispose();
    });
  }

  Future<void> _gotHitSound() async {
    final player = AudioPlayer();
    await player.setAsset(AssetConstants.gotHit);
    player.play();
    Future.delayed(Duration(milliseconds: 500)).then((_) {
      player.dispose();
    });
  }

  Future<void> _endGameSound() async {
    final player = AudioPlayer();
    await player.setAsset(AssetConstants.gameOver);
    player.play();
    Future.delayed(Duration(milliseconds: 500)).then((_) {
      player.dispose();
    });
  }

  /// Bullets fire from player's current position towards the center from player along Z
  void _fireBullet() async {
    if (_player == null) return;
    await _fireSound();
    _bullets.add(
      GameObject(
        position: _player!.position,
        z: _player!.z,
        baseRadius: 30,
        color: Colors.yellow,
        type: GameObjectType.bullet,
        angle: _player!.angle,
      ),
    );
  }

  void _updateGame() {
    if (!mounted) return;
    final double dt = 1 / 60;
    const double enemyAngularSpeed = 1;
    if (Random().nextDouble() < 0.02) {
      _spawnEnemy();
    }
    _tunnelZOffset += 100 * dt;
    // Reset offset to prevent it from growing indefinitely, creating a seamless loop
    if (_tunnelZOffset > _tunnelDepth) {
      _tunnelZOffset = 0.0;
    }
    // Move enemies along the circumference
    for (var enemy in _enemies) {
      // Make enemies slowly circle around and move towards player's angle (in clockwise)
      enemy.angle += enemyAngularSpeed * dt;
      enemy.angle %= (2 * pi);
      enemy.position =
          _playAreaCenter +
          Offset(
            cos(enemy.angle) * _playAreaRadius,
            sin(enemy.angle) * _playAreaRadius,
          );
      enemy.z -= 100 * dt * 5;
    }

    for (var bullet in _bullets) {
      // to increase bullet speed
      bullet.z += 100 * dt * 30;
    }

    // Player vs Enemy collision detection
    for (var enemy in _enemies) {
      double angleDifference = (_player!.angle - enemy.angle).abs();
      if (angleDifference > pi) angleDifference = 2 * pi - angleDifference;
      double dz = (_player!.z - enemy.z).abs();
      double angularThreshold =
          (_player!.baseRadius + enemy.baseRadius) / _playAreaRadius;
      if (angleDifference < angularThreshold && dz < 10) {
        _player = _player!.copyWith(color: Colors.grey);
        setState(() {});
        Future.delayed(Duration(milliseconds: 300), () {
          _player = _player!.copyWith(color: Colors.blue);
        });
        _enemies.remove(enemy);
        _lives--;
        _gotHitSound();
        if (_lives <= 0) {
          _endGame(timeEnded: false);
          break;
        }
      }
    }
    final enemiesToRemove = <GameObject>[];
    final bulletsToRemove = <GameObject>[];
    for (var bullet in _bullets) {
      for (var enemy in _enemies) {
        if (!enemiesToRemove.contains(enemy)) {
          double angleDifference = (bullet.angle - enemy.angle).abs();
          if (angleDifference > pi) angleDifference = 2 * pi - angleDifference;
          double dz = (bullet.z - enemy.z).abs();
          double angularThreshold =
              (bullet.baseRadius + enemy.baseRadius) / _playAreaRadius;
          if (angleDifference < angularThreshold &&
              dz < (bullet.baseRadius + enemy.baseRadius)) {
            enemiesToRemove.add(enemy);
            bulletsToRemove.add(bullet);
            _score++;
            break;
          }
        }
      }
    }

    _enemies.removeWhere((e) => enemiesToRemove.contains(e));
    _bullets.removeWhere((b) => bulletsToRemove.contains(b));

    // Remove off-screen objects
    // Enemies that passed the player (z < cameraZ or some threshold)
    _enemies.removeWhere((enemy) {
      if (enemy.z < 0) {
        double fadeProgress = (-enemy.z) / 150;
        enemy.color = enemy.color.withValues(
          alpha: (1 - fadeProgress).clamp(0.0, 1.0),
        );
      }
      return enemy.z < -150;
    });
    // Remove off-screen objects
    // Bullets that went too far
    _bullets.removeWhere((bullet) {
      if (bullet.z > 2000) {
        double fadeProgress = (bullet.z - 2000) / 400;
        bullet.color = bullet.color.withValues(
          alpha: (1 - fadeProgress).clamp(0.0, 1.0),
        );
      }
      return bullet.z > 2400;
    });
    setState(() {});
  }

  void _reset() {
    _animationController.reset();
    _animationController.repeat();
    _enemies.clear();
    _bullets.clear();
    _remainingTimeTimer.cancel;
    _initTimer();
    _lives = _maxLives;
    _initPlayer();
  }

  Widget _scoreBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        spacing: 16,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children:
                List.generate(
                  _maxLives,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      _lives < index + 1
                          ? Icons.favorite_border
                          : Icons.favorite,
                      color: Colors.red,
                    ),
                  ),
                ).reversed.toList(),
          ),
          Text(
            'Time: ${_getFormattedTime()}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            'Score: $_score',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.topRight,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              _screenSize = constraints.biggest;
              return GestureDetector(
                onTap: _fireBullet,
                onPanUpdate: (details) {
                  if (_player != null) {
                    setState(() {
                      double angleDelta =
                          -(details.delta.dx / _screenSize.width) * pi;
                      _player!.angle += angleDelta;
                      _player!.angle %= (2 * pi);
                      _player!.position =
                          _playAreaCenter +
                          Offset(
                            cos(_player!.angle) * _playAreaRadius,
                            sin(_player!.angle) * _playAreaRadius,
                          );
                    });
                  }
                },
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _FluteriusPainter(
                    player: _player,
                    enemies: _enemies,
                    bullets: _bullets,
                    project: _project,
                    cameraZ: _cameraZ,
                    focalLength: _focalLength,
                    playAreaRadius: _playAreaRadius,
                    playAreaCenter: _playAreaCenter,
                    tunnelZOffset: _tunnelZOffset,
                  ),
                ),
              );
            },
          ),
          _scoreBar(),
        ],
      ),
    );
  }
}

class _FluteriusPainter extends CustomPainter {
  GameObject? player;
  final List<GameObject> enemies;
  final List<GameObject> bullets;
  final Offset Function(Offset worldPos, double z) project;
  final double cameraZ;
  final double focalLength;
  final double playAreaRadius;
  final Offset playAreaCenter;
  final double tunnelZOffset;

  _FluteriusPainter({
    required this.player,
    required this.enemies,
    required this.bullets,
    required this.project,
    required this.cameraZ,
    required this.focalLength,
    required this.playAreaRadius,
    required this.playAreaCenter,
    required this.tunnelZOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final int numRings = 18;
    final int numRadials = 36;
    final double tunnelDepth = 2000;
    final double ringSpacing = tunnelDepth / numRings;
    final Color tunnelColor = Colors.grey.shade800;

    // Add fade-out transition variables
    final double fadeStartZ = 50;
    final double fadeEndZ = 10;

    for (int i = 1; i < numRings; i++) {
      double zNear = (i * ringSpacing + cameraZ - tunnelZOffset) % tunnelDepth;
      // Calculate opacity based on Z position
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

      // Skip drawing if beyond unpainting threshold
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

    // Optionally, overlay faint mesh lines for style
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
    for (int j = 0; j < numRadials; j++) {
      double angle = (2 * pi * j) / numRadials;
      Offset start =
          playAreaCenter +
          Offset(cos(angle) * playAreaRadius, sin(angle) * playAreaRadius);
      // Adjust start point for radial lines to also use the tunnel offset
      Offset prev2D = project(
        start,
        (cameraZ + ringSpacing - tunnelZOffset) % tunnelDepth,
      );
      if (prev2D.dx < 0) {
        prev2D = project(
          start,
          (cameraZ + ringSpacing - tunnelZOffset) % tunnelDepth + tunnelDepth,
        ); // Adjust if negative
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

    final paintPlayArea =
        Paint()
          ..color = Colors.red.withValues(alpha: .3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
    // Project the center of the play area (assuming Z=0 for the boundary itself, or player's Z for perspective)
    final projectedCenter = project(playAreaCenter, 0);
    // Projecting the boundary at Z=0
    // Scale the radius based on a reference Z, or keep it fixed if the boundary is conceptual
    // Projecting a point on the circumference at Z=0 to get the screen radius
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

    // Combine all objects and sort by Z for correct draw order
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
        ).paint(canvas, size);
      } else if (obj.type == GameObjectType.enemy) {
        EnemyPainter(
          enemy: obj,
          project: project,
          focalLength: focalLength,
          cameraZ: cameraZ,
        ).paint(canvas, size);
      } else {
        // Bullets keep original drawing
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
  bool shouldRepaint(covariant _FluteriusPainter oldDelegate) {
    // Repaint if any game state relevant to drawing has changed
    return true; // For simplicity, always repaint. Can be optimized.
  }
}
