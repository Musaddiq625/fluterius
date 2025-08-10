import 'package:fluterius/src/widgets/button_widget.dart';
import 'package:flutter/material.dart';

class GameOverDialog extends StatelessWidget {
  final int score;
  final Function onRestart;
  final bool timeEnded;
  const GameOverDialog({
    super.key,
    required this.score,
    required this.onRestart,
    this.timeEnded = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Text(
        timeEnded ? 'Time Ended' : 'Game Over!',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.red,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Text('Final Score'),
          const SizedBox(height: 5),
          Text(
            '$score',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
        ],
      ),
      actions: <Widget>[
        Center(
          child: ButtonWidget(
            'Play Again',
            btnColor: Colors.red,
            onPressed: () {
              Navigator.of(context).pop();
              onRestart();
            },
          ),
        ),
      ],
    );
  }
}
