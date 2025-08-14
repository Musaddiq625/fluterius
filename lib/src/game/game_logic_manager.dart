import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fluterius/src/enums/game_object_type.dart';
import 'package:fluterius/src/models/game_object.dart';
import 'package:fluterius/src/models/particle.dart';

class GameLogicManager {
  final double _playAreaRadius = 1500;
  final Offset _playAreaCenter = Offset.zero;
  final int _maxLives = 3;
  final int _maxTime = 5;

  final double explosionParticleBaseSize = 32.0;
  final double explosionParticleSizeDepthFactor = 1.0;
  final double maxExplosionZ = 2500.0;

  int _score = 0;
  late int _lives = _maxLives;
  late int _remainingTime = _maxTime;
  Timer? _remainingTimeTimer;
  bool _gameRunning = false;

  double _gameTimeElapsed = 0.0;
  final double _baseSpawnRate = 0.02;
  final double _maxSpawnRate = 0.5;
  final double _spawnRateIncrease = 0.001;

  final int _baseEnemyCount = 5;
  final int _maxEnemyCount = 20;
  final double _multipleEnemyThreshold = 10.0;

  int get lives => _lives;
  int get maxLives => _maxLives;
  int get score => _score;
  int get remainingTime => _remainingTime;
  bool get gameRunning => _gameRunning;
  double get playAreaRadius => _playAreaRadius;
  Offset get playAreaCenter => _playAreaCenter;
  double get gameTimeElapsed => _gameTimeElapsed;
  double get currentSpawnRate {
    double rate = _baseSpawnRate + (_spawnRateIncrease * _gameTimeElapsed);
    return rate.clamp(_baseSpawnRate, _maxSpawnRate);
  }

  int get currentEnemyCount => _calculateEnemyCount();
  bool get isTimeUp => _remainingTime == 0;

  void reset() {
    _lives = _maxLives;
    _score = 0;
    _remainingTime = _maxTime;
    _gameRunning = false;
    _gameTimeElapsed = 0.0;
    _remainingTimeTimer?.cancel();
    _remainingTimeTimer = null;
  }

  void startGame() {
    _gameRunning = true;
    _initTimer();
  }

  void stopGame() {
    _gameRunning = false;
    _remainingTimeTimer?.cancel();
    _remainingTimeTimer = null;
  }

  void _initTimer() {
    _score = 0;
    _remainingTime = _maxTime;
    _remainingTimeTimer = Timer.periodic(Duration(seconds: 1), (_) {
      _remainingTime--;
      if (_remainingTime == 0) {
        _remainingTimeTimer?.cancel();
        _remainingTimeTimer = null;
        _gameRunning = false;
      }
    });
  }

  String getFormattedTime() {
    final minutes = _remainingTime ~/ 60;
    final seconds = _remainingTime % 60;
    final minutesStr = minutes.toString().padLeft(2, '0');
    final secondsStr = seconds.toString().padLeft(2, '0');
    return '$minutesStr:$secondsStr';
  }

  void _initPlayer(GameObject player) {
    // Bottom of the circle (positive Y axis)
    double initialPlayerAngle = pi / 2;
    player.position =
        _playAreaCenter +
        Offset(
          cos(initialPlayerAngle) * _playAreaRadius,
          sin(initialPlayerAngle) * _playAreaRadius,
        );
    player.angle = initialPlayerAngle;
  }

  void initializePlayer(GameObject player) {
    _initPlayer(player);
  }

  void spawnEnemy(List<GameObject> enemies) {
    final rnd = Random();
    double enemyAngle = rnd.nextDouble() * 2 * pi;
    double tunnelDepth = 2500;

    // Adding some variation to enemy size for visual interest
    double sizeVariation = 0.8 + (rnd.nextDouble() * 0.4);

    enemies.add(
      GameObject(
        position:
            _playAreaCenter +
            Offset(
              cos(enemyAngle) * _playAreaRadius,
              sin(enemyAngle) * _playAreaRadius,
            ),
        z: tunnelDepth,
        baseRadius: 50 * sizeVariation,
        color: Colors.red,
        type: GameObjectType.enemy,
        angle: enemyAngle,
      ),
    );
  }

  void fireBullet(GameObject player, List<GameObject> bullets) {
    bullets.add(
      GameObject(
        position: player.position,
        z: player.z,
        baseRadius: 30,
        color: Colors.yellow,
        type: GameObjectType.bullet,
        angle: player.angle,
      ),
    );
  }

  void updateGame(
    GameObject? player,
    List<GameObject> enemies,
    List<GameObject> bullets,
    List<Particle> particles,
    double tunnelZOffset,
    double tunnelDepth,
    Function() onGameOver,
    Function() onPlayerHit,
    Function() onEnemyDestroyed,
  ) {
    if (!_gameRunning) return;

    final double dt = 1 / 60;
    const double enemyAngularSpeed = 2;

    _gameTimeElapsed += dt;
    double currentSpawnRate =
        _baseSpawnRate + (_spawnRateIncrease * _gameTimeElapsed);
    currentSpawnRate = currentSpawnRate.clamp(_baseSpawnRate, _maxSpawnRate);

    if (Random().nextDouble() < currentSpawnRate) {
      int enemyCount = _calculateEnemyCount();
      enemyCount = enemyCount.clamp(1, _maxEnemyCount);
      for (int i = 0; i < enemyCount; i++) {
        spawnEnemy(enemies);
      }
    }

    // Move enemies along the circumference
    for (var enemy in enemies) {
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

    for (var bullet in bullets) {
      // to increase bullet speed
      bullet.z += 100 * dt * 30;
    }

    if (player != null) {
      for (var enemy in enemies) {
        double angleDifference = (player.angle - enemy.angle).abs();
        if (angleDifference > pi) angleDifference = 2 * pi - angleDifference;
        double dz = (player.z - enemy.z).abs();
        double angularThreshold =
            (player.baseRadius + enemy.baseRadius) / _playAreaRadius;
        if (angleDifference < angularThreshold && dz < 10) {
          player.color = Colors.grey;
          enemies.remove(enemy);
          _lives--;
          onPlayerHit();
          if (_lives <= 0) {
            onGameOver();
            return;
          }
        }
      }
    }

    final enemiesToRemove = <GameObject>[];
    final bulletsToRemove = <GameObject>[];

    for (var bullet in bullets) {
      for (var enemy in enemies) {
        if (!enemiesToRemove.contains(enemy)) {
          double angleDifference = (bullet.angle - enemy.angle).abs();
          if (angleDifference > pi) angleDifference = 2 * pi - angleDifference;
          double dz = (bullet.z - enemy.z).abs();
          double angularThreshold =
              (bullet.baseRadius + enemy.baseRadius) / _playAreaRadius;
          if (angleDifference < angularThreshold &&
              dz < (bullet.baseRadius + enemy.baseRadius)) {
            _createExplosionParticles(enemy, particles);
            enemiesToRemove.add(enemy);
            bulletsToRemove.add(bullet);
            _score++;
            onEnemyDestroyed();
            break;
          }
        }
      }
    }

    final particlesToRemove = <Particle>[];
    for (var particle in particles) {
      particle.position += particle.velocity * dt;
      particle.z += particle.vz * dt;
      particle.timeLeft -= dt;
      if (particle.timeLeft <= 0) {
        particlesToRemove.add(particle);
      }
    }
    particles.removeWhere((p) => particlesToRemove.contains(p));
    enemies.removeWhere((e) => enemiesToRemove.contains(e));
    bullets.removeWhere((b) => bulletsToRemove.contains(b));

    // Remove off-screen objects
    // Enemies that passed the player (z < cameraZ or some threshold)
    enemies.removeWhere((enemy) {
      return enemy.z < -150;
    });

    // Bullets that went too far
    bullets.removeWhere((bullet) {
      if (bullet.z > 2000) {
        double fadeProgress = (bullet.z - 2000) / 400;
        bullet.color = bullet.color.withValues(
          alpha: (1 - fadeProgress).clamp(0.0, 1.0),
        );
      }
      return bullet.z > 2400;
    });
  }

  int _calculateEnemyCount() {
    if (_gameTimeElapsed < _multipleEnemyThreshold) {
      return _baseEnemyCount;
    }

    double progress = 0.0;

    if (_maxTime > _multipleEnemyThreshold) {
      progress =
          (_gameTimeElapsed - _multipleEnemyThreshold) /
          (_maxTime - _multipleEnemyThreshold);
      progress = progress.clamp(0.0, 1.0);
    } else {
      progress = 1.0;
    }

    int enemyCount =
        _baseEnemyCount +
        (progress * (_maxEnemyCount - _baseEnemyCount)).round();
    return enemyCount.clamp(_baseEnemyCount, _maxEnemyCount);
  }

  void _createExplosionParticles(GameObject enemy, List<Particle> particles) {
    final int numParticles = 18;
    final double baseSpeed = 350;
    final double explosionSizeFactor =
        1 +
        explosionParticleSizeDepthFactor *
            (1 - (enemy.z / maxExplosionZ)).clamp(0.0, 1.0);

    for (int i = 0; i < numParticles; i++) {
      final double theta =
          (2 * pi * i) / numParticles + (Random().nextDouble() - 0.5) * 0.2;
      final double speed = baseSpeed * (0.7 + Random().nextDouble() * 0.6);
      final Offset velocity = Offset(cos(theta), sin(theta)) * speed;
      final double vz = 80 * (Random().nextDouble() - 0.5);
      final Color color =
          Color.lerp(Colors.yellow, Colors.red, Random().nextDouble())!;
      final double size =
          explosionParticleBaseSize *
          explosionSizeFactor *
          (0.1 + Random().nextDouble() * 0.4);

      particles.add(
        Particle(
          position: enemy.position,
          z: enemy.z,
          velocity: velocity,
          vz: vz,
          color: color,
          timeLeft: 0.5,
          totalDuration: 0.5,
          size: size,
        ),
      );
    }
  }

  void dispose() {
    _remainingTimeTimer?.cancel();
    _remainingTimeTimer = null;
  }
}
