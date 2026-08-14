import 'package:flutter/material.dart';

import 'screens/restaurants_screen.dart';

void main() {
  runApp(const DominoApp());
}

class DominoApp extends StatelessWidget {
  const DominoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RestaurantsScreen(),
    );
  }
}
