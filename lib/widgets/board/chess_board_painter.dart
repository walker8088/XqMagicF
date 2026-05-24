import 'package:flutter/material.dart';
import 'package:magicf/utils/constants.dart';
import 'package:magicf/utils/position.dart';
import '../../models/chess_piece.dart';
import '../../viewmodels/game_viewmodel.dart';

class ChessBoardPainter extends SimplePainter {
  ChessBoardPainter({
    required this.cellSize,
    required this.paddingCells,
    required this.viewModel,
    this.inCheckPosition,
  });

  final double cellSize;
  final int paddingCells;
  final GameViewModel viewModel;
  final Position? inCheckPosition;

  /// 棋盘线区域相对于 Container 的偏移
  double get gridOffset => cellSize * paddingCells;

  /// 棋盘线区域的总尺寸
  double get gridSize => cellSize * (AppConstants.boardCols - 1);

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    _drawMoveHints(canvas);
    _drawPieces(canvas);
  }

  void _drawGrid(Canvas canvas, Size canvasSize) {
    final linePaint = Paint()
      ..color = AppConstants.gridLineColor
      ..strokeWidth = 1.5;
    final thickPaint = Paint()
      ..color = AppConstants.gridLineColor
      ..strokeWidth = 2.5;

    // 竖线（9条）
    for (int col = 0; col < AppConstants.boardCols; col++) {
      final x = _gridX(col);
      // 上半部分（row 0-4）
      canvas.drawLine(
        Offset(x, _gridY(0)),
        Offset(x, _gridY(4)),
        col == 0 || col == AppConstants.boardCols - 1 ? thickPaint : linePaint,
      );
      // 下半部分（row 5-9）
      canvas.drawLine(
        Offset(x, _gridY(5)),
        Offset(x, _gridY(9)),
        col == 0 || col == AppConstants.boardCols - 1 ? thickPaint : linePaint,
      );
    }

    // 横线（10条，全部贯通）
    for (int row = 0; row < AppConstants.boardRows; row++) {
      final y = _gridY(row);
      canvas.drawLine(
        Offset(_gridX(0), y),
        Offset(_gridX(AppConstants.boardCols - 1), y),
        row == 0 || row == AppConstants.boardRows - 1 ? thickPaint : linePaint,
      );
    }

    // 九宫斜线
    // 黑方九宫（上方）
    canvas.drawLine(
      Offset(_gridX(3), _gridY(0)),
      Offset(_gridX(5), _gridY(2)),
      linePaint,
    );
    canvas.drawLine(
      Offset(_gridX(5), _gridY(0)),
      Offset(_gridX(3), _gridY(2)),
      linePaint,
    );
    // 红方九宫（下方）
    canvas.drawLine(
      Offset(_gridX(3), _gridY(7)),
      Offset(_gridX(5), _gridY(9)),
      linePaint,
    );
    canvas.drawLine(
      Offset(_gridX(5), _gridY(7)),
      Offset(_gridX(3), _gridY(9)),
      linePaint,
    );

    // 楚河汉界
    _drawRiverText(canvas, canvasSize);

    // 九宫格边框加粗
    // 左右外侧边框（row 0-2 和 row 7-9）
    // 已由竖线覆盖

    // 起始位置标记（小十字）
    _drawStartMarkers(canvas, linePaint);
  }

  void _drawRiverText(Canvas canvas, Size canvasSize) {
    const text1 = '楚 河';
    const text2 = '汉 界';

    final textStyle = TextStyle(
      fontSize: cellSize * 0.45,
      color: AppConstants.gridLineColor,
      fontWeight: FontWeight.bold,
    );

    final textCenterY = (_gridY(4) + _gridY(5)) / 2;
    final textSpan1 = TextSpan(style: textStyle, text: text1);
    final textSpan2 = TextSpan(style: textStyle, text: text2);

    final tp1 = TextPainter(text: textSpan1, textDirection: TextDirection.ltr);
    tp1.layout();
    tp1.paint(
      canvas,
      Offset(gridOffset + cellSize * 1.5, textCenterY - tp1.height / 2),
    );

    final tp2 = TextPainter(text: textSpan2, textDirection: TextDirection.ltr);
    tp2.layout();
    tp2.paint(
      canvas,
      Offset(
        canvasSize.width - gridOffset - cellSize * 4.5,
        textCenterY - tp2.height / 2,
      ),
    );
  }

  void _drawStartMarkers(Canvas canvas, Paint paint) {
    // 炮和兵的起始位置小十字标记
    final markerPositions = <int, List<int>>{
      1: [2, 7], // 炮
      7: [2, 7], // 炮
      0: [3, 6], // 兵/卒
      2: [3, 6],
      4: [3, 6],
      6: [3, 6],
      8: [3, 6],
    };

    final markerLen = cellSize * 0.15;
    final markerGap = cellSize * 0.08;

    for (final entry in markerPositions.entries) {
      for (final row in entry.value) {
        _drawCrossMarker(canvas, entry.key, row, markerLen, markerGap, paint);
      }
    }
  }

  void _drawCrossMarker(
    Canvas canvas,
    int col,
    int row,
    double len,
    double gap,
    Paint paint,
  ) {
    final x = _gridX(col);
    final y = _gridY(row);

    void drawLine(double dx, double dy) {
      final sx = x + dx * (len + gap);
      final sy = y + dy * (len + gap);
      final ex = x + dx * len;
      final ey = y + dy * len;
      canvas.drawLine(Offset(sx, sy), Offset(ex, ey), paint);
    }

    // 只画外侧的角
    if (col > 0) {
      drawLine(-1, -1);
      drawLine(-1, 1);
    }
    if (col < AppConstants.boardCols - 1) {
      drawLine(1, -1);
      drawLine(1, 1);
    }
  }

  void _drawMoveHints(Canvas canvas) {
    if (viewModel.selectedPosition == null) return;

    final hintPaint = Paint()
      ..color = AppConstants.moveHintColor
      ..style = PaintingStyle.fill;

    for (final pos in viewModel.possibleMoves) {
      final cx = _gridX(pos.col);
      final cy = _gridY(pos.row);
      final existingPiece = viewModel.currentBoard.getPiece(pos);

      if (existingPiece != null) {
        // 可吃子位置：画圆环
        final ringPaint = Paint()
          ..color = AppConstants.selectedColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
        canvas.drawCircle(Offset(cx, cy), cellSize * 0.45, ringPaint);
      } else {
        // 空位：画小圆点
        canvas.drawCircle(Offset(cx, cy), cellSize * 0.1, hintPaint);
      }
    }
  }

  void _drawPieces(Canvas canvas) {
    for (final piece in viewModel.currentBoard.pieces.values) {
      final cx = _gridX(piece.position.col);
      final cy = _gridY(piece.position.row);
      final isSelected = viewModel.isPositionSelected(piece.position);
      final isInCheck =
          inCheckPosition != null && inCheckPosition == piece.position;

      _drawPieceAt(canvas, piece, cx, cy, isSelected, isInCheck);
    }
  }

  void _drawPieceAt(
    Canvas canvas,
    ChessPiece piece,
    double cx,
    double cy,
    bool isSelected,
    bool isInCheck,
  ) {
    final radius = cellSize * AppConstants.pieceRadiusRatio;

    // 将军高亮 - 红色光晕（在棋子之前绘制，位于底层）
    if (isInCheck) {
      canvas.drawCircle(
        Offset(cx, cy),
        radius + 6,
        Paint()
          ..color = Colors.red.withOpacity(0.4)
          ..style = PaintingStyle.fill,
      );
    }

    // 阴影
    canvas.drawCircle(
      Offset(cx + 2, cy + 2),
      radius,
      Paint()..color = Colors.black.withOpacity(0.15),
    );

    // 棋子底色
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..color = AppConstants.pieceBackground
        ..style = PaintingStyle.fill,
    );

    // 棋子描边
    canvas.drawCircle(
      Offset(cx, cy),
      radius,
      Paint()
        ..color = AppConstants.pieceStroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 3.5 : 2,
    );

    // 内圈
    canvas.drawCircle(
      Offset(cx, cy),
      radius * 0.85,
      Paint()
        ..color =
            (piece.color == PieceColor.red
                    ? AppConstants.redPieceColor
                    : AppConstants.blackPieceColor)
                .withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // 选中高亮
    if (isSelected) {
      canvas.drawCircle(
        Offset(cx, cy),
        radius + 4,
        Paint()
          ..color = AppConstants.selectedColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    // 将军高亮 - 红色圆环（在棋子之后绘制，覆盖在边缘）
    if (isInCheck) {
      canvas.drawCircle(
        Offset(cx, cy),
        radius + 3,
        Paint()
          ..color = Colors.red
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    // 棋子文字
    final text = piece.type.displayName(piece.color);
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: cellSize * 0.42,
          color: piece.color == PieceColor.red
              ? AppConstants.redPieceColor
              : AppConstants.blackPieceColor,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(cx - textPainter.width / 2, cy - textPainter.height / 2),
    );
  }

  double _gridX(int col) => gridOffset + col * cellSize;
  double _gridY(int row) => gridOffset + row * cellSize;

  @override
  bool shouldRepaint(covariant ChessBoardPainter oldDelegate) =>
      inCheckPosition != oldDelegate.inCheckPosition;
}

/// 简化版 CustomPainter，始终重绘（由 Provider 触发 widget 重建）
class SimplePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
