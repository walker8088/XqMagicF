import 'package:flutter/material.dart';
import 'package:xqmagic/models/board_render_data.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/coord.dart';
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
      cellSize * (AppConstants.boardCols + AppConstants.paddingCells);
  double get boardHeight =>
      cellSize * (AppConstants.boardRows + AppConstants.paddingCells);

  /// 构建渲染数据（从 ViewModel 提取纯数据）
  BoardRenderData _buildRenderData() {
    return BoardRenderData(
      pieces: viewModel.currentBoard.pieces.values.toList(),
      selectedPosition: viewModel.selectedPosition,
      possibleMoves: viewModel.possibleMoves,
      lastMove: viewModel.lastMove,
      inCheckPosition: viewModel.inCheckPosition,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final localPosition = details.localPosition;
        // 使用 floor() 而非 round()：点击落在某格右半部时
        // round() 会四舍五入到下一格，导致用户点 cell 0 却被当成 cell 1。
        // floor() 才是“以包含点击位置的最左侧格”为准的正确取整。
        final col =
            (localPosition.dx / cellSize).floor() - AppConstants.paddingCells;
        final rawRow =
            (localPosition.dy / cellSize).floor() - AppConstants.paddingCells;
        final row = (AppConstants.boardRows - 1) - rawRow;

        if (col >= 0 &&
            col < AppConstants.boardCols &&
            row >= 0 &&
            row < AppConstants.boardRows) {
          viewModel.selectPiece(Coord(col, row));
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
              color: Colors.black.withValues(alpha: 0.3),
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
            renderData: _buildRenderData(),
          ),
        ),
      ),
    );
  }
}
