import 'package:flutter/material.dart';
import 'package:fluterius/src/game/game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const FluteriusGameWidget(),
      theme: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark()),
    ),
  );
}
