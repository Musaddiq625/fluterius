import 'package:flutter/material.dart';

class ScoreBarWidget extends StatelessWidget {
  final int lives;
  final int maxLives;
  final String timeText;
  final int score;

  const ScoreBarWidget({
    super.key,
    required this.lives,
    required this.maxLives,
    required this.timeText,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        spacing: 16,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children:
                List.generate(
                  maxLives,
                  (index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      lives < index + 1
                          ? Icons.favorite_border
                          : Icons.favorite,
                      color: Colors.red,
                    ),
                  ),
                ).reversed.toList(),
          ),
          Text(
            'Time: $timeText',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            'Score: $score',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
