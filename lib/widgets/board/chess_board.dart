import 'package:flutter/material.dart';
import 'package:xqmagic/models/board_render_data.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/coord.dart';
import 'chess_board_painter.dart';

class ChessBoard extends StatelessWidget {
  const ChessBoard({
    super.key,
    required this.cellSize,
    required this.renderData,
    this.onTap,
  });

  final double cellSize;
  final BoardRenderData renderData;
  final void Function(Coord)? onTap;

  double get boardWidth =>
      cellSize * (AppConstants.boardCols + AppConstants.paddingCells);
  double get boardHeight =>
      cellSize * (AppConstants.boardRows + AppConstants.paddingCells);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final localPosition = details.localPosition;
        final gridOffset = cellSize * AppConstants.paddingCells;
        // 以交叉点为中心，映射到最近的网格位置
        // round() 使点击区域以交叉点对称分布，而非以格子左/上边缘为界
        final col = ((localPosition.dx - gridOffset) / cellSize).round();
        final rawRow = ((localPosition.dy - gridOffset) / cellSize).round();
        final row = (AppConstants.boardRows - 1) - rawRow;

        if (col >= 0 &&
            col < AppConstants.boardCols &&
            row >= 0 &&
            row < AppConstants.boardRows) {
          onTap?.call(Coord(col, row));
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
            renderData: renderData,
          ),
        ),
      ),
    );
  }
}
