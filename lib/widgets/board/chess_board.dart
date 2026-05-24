import 'package:flutter/material.dart';
import 'package:magicf/game/game_engine.dart';
import 'package:magicf/utils/constants.dart';
import 'package:magicf/utils/position.dart';
import '../../viewmodels/game_viewmodel.dart';
import 'chess_board_painter.dart';

class ChessBoard extends StatelessWidget {
  const ChessBoard({
    super.key,
    required this.cellSize,
    required this.viewModel,
  });

  final double cellSize;
  final GameViewModel viewModel;

  double get boardWidth =>
      cellSize * (AppConstants.boardCols + AppConstants.paddingCells * 2);
  double get boardHeight =>
      cellSize * (AppConstants.boardRows + AppConstants.paddingCells * 2);

  /// 计算当前被将军的将/帅位置
  Position? _getInCheckPosition() {
    final fen = viewModel.gameTree.currentFen;
    if (fen == null) return null;

    final engine = GameEngine(fen);
    if (!engine.isInCheck(viewModel.currentTurn)) return null;

    // 查找被将军方的将/帅位置
    for (final piece in viewModel.currentBoard.pieces.values) {
      if (piece.type == PieceType.general &&
          piece.color == viewModel.currentTurn) {
        return piece.position;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final localPosition = details.localPosition;
        final col =
            (localPosition.dx / cellSize).round() - AppConstants.paddingCells;
        final row =
            (localPosition.dy / cellSize).round() - AppConstants.paddingCells;

        if (col >= 0 &&
            col < AppConstants.boardCols &&
            row >= 0 &&
            row < AppConstants.boardRows) {
          viewModel.selectPiece(Position(col, row));
        }
      },
      child: Container(
        width: boardWidth,
        height: boardHeight,
        decoration: BoxDecoration(
          color: AppConstants.boardBackground,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: CustomPaint(
          size: Size(boardWidth, boardHeight),
          painter: ChessBoardPainter(
            cellSize: cellSize,
            paddingCells: AppConstants.paddingCells,
            viewModel: viewModel,
            inCheckPosition: _getInCheckPosition(),
          ),
        ),
      ),
    );
  }
}
