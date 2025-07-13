import 'package:flutter/material.dart';
import 'map/map_page.dart';

void main() {
  runApp(const PassearApp());
}

class PassearApp extends StatelessWidget {
  const PassearApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Passear',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const MapPage(),
    );
  }
}
