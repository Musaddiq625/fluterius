import 'dart:developer';

import 'package:just_audio/just_audio.dart';
import 'package:fluterius/src/constants/asset_constants.dart';

class AudioManager {
  final AudioPlayer bgPlayer = AudioPlayer();

  Future<void> playBackgroundMusic() async {
    try {
      await bgPlayer.setAsset(AssetConstants.soundtrack);
      bgPlayer
        ..setLoopMode(LoopMode.all)
        ..play();
    } catch (e) {
      log('playBackgroundMusic error: $e');
    }
  }

  Future<void> playFireSound() async {
    try {
      final player = AudioPlayer();
      await player.setAsset(AssetConstants.fire);
      await player.play();
      Future.delayed(Duration(milliseconds: 500)).then((_) {
        player.dispose();
      });
    } catch (e) {
      log('playFireSound error: $e');
    }
  }

  Future<void> playExplodeSound() async {
    try {
      final player = AudioPlayer();
      await player.setAsset(AssetConstants.explode);
      await player.play();
      Future.delayed(Duration(milliseconds: 500)).then((_) {
        player.dispose();
      });
    } catch (e) {
      log('playExplodeSound error: $e');
    }
  }

  Future<void> playGotHitSound() async {
    try {
      final player = AudioPlayer();
      await player.setAsset(AssetConstants.gotHit);
      await player.play();
      Future.delayed(Duration(milliseconds: 500)).then((_) {
        player.dispose();
      });
    } catch (e) {
      log('playGotHitSound error: $e');
    }
  }

  Future<void> playGameOverSound() async {
    try {
      final player = AudioPlayer();
      await player.setAsset(AssetConstants.gameOver);
      await player.play();
      Future.delayed(Duration(milliseconds: 500)).then((_) {
        player.dispose();
      });
    } catch (e) {
      log('playGameOverSound error: $e');
    }
  }

  void dispose() {
    bgPlayer.stop();
    bgPlayer.dispose();
  }
}
