import 'package:flutter/material.dart';
import 'game_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3E2723), Color(0xFF5D4037)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '象 棋',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF5DEB3),
                  letterSpacing: 24,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '中国象棋',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white.withOpacity(0.7),
                  letterSpacing: 8,
                ),
              ),
              const SizedBox(height: 64),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GameScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFCC0000),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  textStyle: const TextStyle(fontSize: 20),
                ),
                child: const Text('开始对局'),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () {
                  // TODO: 进入复盘模式
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF5DEB3),
                  side: const BorderSide(color: Color(0xFFF5DEB3)),
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  textStyle: const TextStyle(fontSize: 20),
                ),
                child: const Text('复盘分析'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
