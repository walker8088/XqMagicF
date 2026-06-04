import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'data/endgame_puzzles.dart';
import 'utils/app_settings.dart';
import 'viewmodels/game_viewmodel.dart';
import 'screens/game_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.init();
  // 加载残局数据及已解决状态
  EndgameCollection.loadSolvedState();
  await EndgameCollection.loadFromAsset();
  runApp(const ChessApp());
}

class ChessApp extends StatelessWidget {
  const ChessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameViewModel(),
      child: MaterialApp(
        title: '象棋',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B6914)),
          useMaterial3: true,
        ),
        home: const GameScreen(),
      ),
    );
  }
}
