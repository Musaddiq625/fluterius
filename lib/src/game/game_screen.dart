import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fluterius/src/dialogs/game_over_dialog.dart';
import 'package:fluterius/src/dialogs/game_start_dialog.dart';
import 'package:fluterius/src/enums/game_object_type.dart';
import 'package:fluterius/src/models/game_object.dart';
import 'package:fluterius/src/models/particle.dart';
import 'package:fluterius/src/game/game_logic_manager.dart';
import 'package:fluterius/src/game/audio_manager.dart';
import 'package:fluterius/src/game/game_renderer.dart';
import 'package:fluterius/src/widgets/score_bar_widget.dart';

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
  final List<Particle> _particles = [];

  final double _cameraZ = -200;
  final double _focalLength = 100;
  Size _screenSize = Size.zero;

  double _tunnelZOffset = 200;
  final double _tunnelDepth = 9800.0;

  late GameLogicManager _gameLogicManager;
  late AudioManager _audioManager;

  bool _gameOverDialogShown = false;
  bool overlayAdded = false;

  void _insertOverlay(BuildContext context) {
    if (overlayAdded) return;
    setState(() => overlayAdded = true);
    return Overlay.of(context).insert(
      OverlayEntry(
        builder: (context) {
          return Positioned(
            bottom: 16,
            left: 16,
            child: Material(
              color: Colors.transparent,
              child: Text(
                'Made with ❤️ by Musaddiq625',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _gameLogicManager = GameLogicManager();
    _audioManager = AudioManager();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _insertOverlay(context);
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
    _gameLogicManager.dispose();
    _audioManager.dispose();
    super.dispose();
  }

  void _initPlayer() {
    // Bottom of the circle (positive Y axis)
    double initialPlayerAngle = pi / 2;
    _player = GameObject(
      position:
          _gameLogicManager.playAreaCenter +
          Offset(
            cos(initialPlayerAngle) * _gameLogicManager.playAreaRadius,
            sin(initialPlayerAngle) * _gameLogicManager.playAreaRadius,
          ),
      z: 200,
      baseRadius: 80,
      color: Colors.blue,
      type: GameObjectType.player,
      angle: initialPlayerAngle,
    );
    _gameLogicManager.initializePlayer(_player!);
  }

  void _startGame() {
    _audioManager.playBackgroundMusic();
    _gameLogicManager.startGame();
    _initPlayer();
    _animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..addListener(_updateGame)
          ..repeat();
  }

  /// Showing 'end game' dialog
  void _endGame({required bool timeEnded}) async {
    _animationController.stop();
    _gameLogicManager.stopGame();
    _audioManager.playGameOverSound();
    if (_gameOverDialogShown) return;
    _gameOverDialogShown = true;
    setState(() {});
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return GameOverDialog(
          score: _gameLogicManager.score,
          timeEnded: timeEnded,
          onRestart: () {
            _reset();
            setState(() {});
          },
        );
      },
    );
  }

  void _updateGame() {
    if (!mounted || _gameOverDialogShown) return;

    if (!_gameLogicManager.gameRunning && !_gameOverDialogShown) {
      bool timeEnded = _gameLogicManager.isTimeUp;
      _endGame(timeEnded: timeEnded);
      return;
    }

    _tunnelZOffset += 100 * (1 / 60);
    if (_tunnelZOffset > _tunnelDepth) {
      _tunnelZOffset = 0.0;
    }

    _gameLogicManager.updateGame(
      _player,
      _enemies,
      _bullets,
      _particles,
      _tunnelZOffset,
      _tunnelDepth,
      () => _endGame(timeEnded: false), // onGameOver (lives = 0)
      () => _onPlayerHit(),
      () => _onEnemyDestroyed(),
    );

    setState(() {});
  }

  void _onPlayerHit() {
    if (_gameOverDialogShown) return;

    if (_player != null) {
      _player = _player!.copyWith(color: Colors.grey);
      setState(() {});
      Future.delayed(Duration(milliseconds: 300), () {
        if (_player != null && !_gameOverDialogShown) {
          _player = _player!.copyWith(color: Colors.blue);
          setState(() {});
        }
      });
    }
    _audioManager.playGotHitSound();
  }

  void _onEnemyDestroyed() {
    if (_gameOverDialogShown) return;
    _audioManager.playExplodeSound();
  }

  void _fireBullet() async {
    if (_player == null || _gameOverDialogShown) return;
    _audioManager.playFireSound();
    _gameLogicManager.fireBullet(_player!, _bullets);
  }

  void _reset() {
    _animationController.reset();
    _animationController.repeat();
    _enemies.clear();
    _bullets.clear();
    _particles.clear();
    _gameOverDialogShown = false;
    _gameLogicManager.reset();
    _gameLogicManager.startGame();
    _initPlayer();
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
                onTap: _gameOverDialogShown ? null : _fireBullet,
                onPanUpdate: (details) {
                  if (_player != null && !_gameOverDialogShown) {
                    setState(() {
                      double angleDelta =
                          -(details.delta.dx / _screenSize.width) * pi;
                      _player!.angle += angleDelta;
                      _player!.angle %= (2 * pi);
                      _player!.position =
                          _gameLogicManager.playAreaCenter +
                          Offset(
                            cos(_player!.angle) *
                                _gameLogicManager.playAreaRadius,
                            sin(_player!.angle) *
                                _gameLogicManager.playAreaRadius,
                          );
                    });
                  }
                },
                child: CustomPaint(
                  size: Size.infinite,
                  painter: GameRenderer(
                    player: _player,
                    enemies: _enemies,
                    bullets: _bullets,
                    particles: _particles,
                    project: _project,
                    cameraZ: _cameraZ,
                    focalLength: _focalLength,
                    playAreaRadius: _gameLogicManager.playAreaRadius,
                    playAreaCenter: _gameLogicManager.playAreaCenter,
                    tunnelZOffset: _tunnelZOffset,
                  ),
                ),
              );
            },
          ),
          ScoreBarWidget(
            lives: _gameLogicManager.lives,
            maxLives: _gameLogicManager.maxLives,
            timeText: _gameLogicManager.getFormattedTime(),
            score: _gameLogicManager.score,
          ),
        ],
      ),
    );
  }
}
