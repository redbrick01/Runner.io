import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('runner.io')),
      body: const Center(child: Text('runner.io 러닝 앱 시작')),
    );
  }
}
