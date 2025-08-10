import 'package:fluterius/src/widgets/button_widget.dart';
import 'package:flutter/material.dart';

class GameStartDialog extends StatelessWidget {
  final Function() onStart;
  const GameStartDialog({required this.onStart, super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: const Text(
        'Welcome',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      actions: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: Center(
            child: ButtonWidget(
              'Start Game',
              btnColor: Colors.blueAccent,
              onPressed: onStart,
            ),
          ),
        ),
      ],
    );
  }
}
