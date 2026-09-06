import 'package:flutter/material.dart';
import 'home_page.dart';

class FavoritePage extends StatelessWidget {
  const FavoritePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomePage(initialIndex: 3);
  }
}
