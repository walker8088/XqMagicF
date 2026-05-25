import 'package:flutter/material.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/models/game_state.dart';

class GameStatusBar extends StatelessWidget {
  const GameStatusBar({
    super.key,
    required this.currentTurn,
    required this.gameState,
    required this.onNewGame,
  });

  final PieceColor currentTurn;
  final GameState gameState;
  final VoidCallback onNewGame;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: Colors.black.withOpacity(0.3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTurnIndicator(
            '红方',
            AppConstants.redPieceColor,
            currentTurn == PieceColor.red,
          ),
          const SizedBox(width: 32),
          _buildTurnIndicator(
            '黑方',
            AppConstants.blackPieceColor,
            currentTurn == PieceColor.black,
          ),
          if (gameState == GameState.checkmate) ...[
            const SizedBox(width: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '胜负已分',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTurnIndicator(String label, Color color, bool isActive) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [BoxShadow(color: color, blurRadius: 8, spreadRadius: 2)]
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70,
            fontSize: 16,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
