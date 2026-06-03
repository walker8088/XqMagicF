import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/coord.dart';

/// 象棋走法规则验证器
///
/// 纯静态方法，无状态，可独立进行单元测试。
/// 仅负责判断单步走法是否符合对应棋子的走子规则，
/// 不负责将军检测、局面模拟等高级逻辑。
class MoveValidator {
  MoveValidator._();

  /// 判断指定棋子在当前位置是否能走到目标位置
  ///
  /// [allPiecePositions] 必须包含**所有**棋子的坐标，包括目标位置的棋子。
  /// 炮的吃子判断依赖 `allPiecePositions.contains(to)` 来区分走子和吃子，
  /// 如果不包含目标位置棋子，炮的吃子判断会出错。
  /// 其他棋子仅使用中间位置的坐标进行路径/蹩腿检查。
  static bool isValidMove({
    required PieceType type,
    required PieceColor color,
    required Coord from,
    required Coord to,
    required List<Coord> allPiecePositions,
  }) {
    final colDiff = to.col - from.col;
    final rowDiff = to.row - from.row;
    final absCol = colDiff.abs();
    final absRow = rowDiff.abs();
    if (absCol == 0 && absRow == 0) return false;

    switch (type) {
      case PieceType.king:
        return _isValidGeneralMove(from, to, absCol, absRow, color);
      case PieceType.advisor:
        return _isValidAdvisorMove(from, to, absCol, absRow, color);
      case PieceType.bishop:
        return _isValidBishopMove(
          from,
          to,
          absCol,
          absRow,
          color,
          allPiecePositions,
        );
      case PieceType.knight:
        return _isValidKnightMove(from, to, absCol, absRow, allPiecePositions);
      case PieceType.rook:
        return _isValidRookMove(from, to, allPiecePositions);
      case PieceType.cannon:
        return _isValidCannonMove(from, to, allPiecePositions);
      case PieceType.pawn:
        return _isValidPawnMove(from, to, absCol, absRow, color);
    }
  }

  static bool _isValidGeneralMove(
    Coord from,
    Coord to,
    int absCol,
    int absRow,
    PieceColor color,
  ) {
    if (absCol + absRow != 1) return false;
    final minRow = color == PieceColor.red ? 0 : 7;
    final maxRow = color == PieceColor.red ? 2 : 9;
    return to.col >= 3 && to.col <= 5 && to.row >= minRow && to.row <= maxRow;
  }

  static bool _isValidAdvisorMove(
    Coord from,
    Coord to,
    int absCol,
    int absRow,
    PieceColor color,
  ) {
    if (absCol != 1 || absRow != 1) return false;
    final minRow = color == PieceColor.red ? 0 : 7;
    final maxRow = color == PieceColor.red ? 2 : 9;
    return to.col >= 3 && to.col <= 5 && to.row >= minRow && to.row <= maxRow;
  }

  static bool _isValidBishopMove(
    Coord from,
    Coord to,
    int absCol,
    int absRow,
    PieceColor color,
    List<Coord> allPiecePositions,
  ) {
    if (absCol != 2 || absRow != 2) return false;
    if (color == PieceColor.red && to.row > 4) return false;
    if (color == PieceColor.black && to.row < 5) return false;
    final eyeCenter = Coord((from.col + to.col) ~/ 2, (from.row + to.row) ~/ 2);
    if (allPiecePositions.contains(eyeCenter)) return false;
    return true;
  }

  static bool _isValidKnightMove(
    Coord from,
    Coord to,
    int absCol,
    int absRow,
    List<Coord> allPiecePositions,
  ) {
    if (!((absCol == 1 && absRow == 2) || (absCol == 2 && absRow == 1))) {
      return false;
    }
    Coord legPos;
    if (absCol == 2) {
      legPos = Coord((from.col + to.col) ~/ 2, from.row);
    } else {
      legPos = Coord(from.col, (from.row + to.row) ~/ 2);
    }
    return !allPiecePositions.contains(legPos);
  }

  static bool _isValidRookMove(
    Coord from,
    Coord to,
    List<Coord> allPiecePositions,
  ) {
    if (from.col != to.col && from.row != to.row) return false;
    return _isPathClear(from, to, allPiecePositions);
  }

  static bool _isValidCannonMove(
    Coord from,
    Coord to,
    List<Coord> allPiecePositions,
  ) {
    if (from.col != to.col && from.row != to.row) return false;
    final count = _countPiecesBetween(from, to, allPiecePositions);
    final hasTargetPiece = allPiecePositions.contains(to);
    return hasTargetPiece ? count == 1 : count == 0;
  }

  static bool _isValidPawnMove(
    Coord from,
    Coord to,
    int absCol,
    int absRow,
    PieceColor color,
  ) {
    if (absCol + absRow != 1) return false;
    final crossedRiver = color == PieceColor.red ? from.row > 4 : from.row < 5;
    if (!crossedRiver) {
      final forwardCol = from.col;
      final forwardRow = color == PieceColor.red ? from.row + 1 : from.row - 1;
      return to.col == forwardCol && to.row == forwardRow;
    }
    // 过河后：可以前进或横移，但不能后退
    if (absRow == 1) {
      // 纵向移动：必须前进
      final forward = color == PieceColor.red ? from.row + 1 : from.row - 1;
      return to.col == from.col && to.row == forward;
    }
    // 横向移动：允许
    return absCol == 1 && absRow == 0;
  }

  /// 检查路径是否畅通（不含起点和终点）
  static bool _isPathClear(
    Coord from,
    Coord to,
    List<Coord> allPiecePositions,
  ) {
    return _countPiecesBetween(from, to, allPiecePositions) == 0;
  }

  /// 计算两点之间的棋子数量（不含起点和终点）
  static int _countPiecesBetween(
    Coord from,
    Coord to,
    List<Coord> allPiecePositions,
  ) {
    int count = 0;
    if (from.col == to.col) {
      final minRow = from.row < to.row ? from.row : to.row;
      final maxRow = from.row < to.row ? to.row : from.row;
      for (int r = minRow + 1; r < maxRow; r++) {
        if (allPiecePositions.contains(Coord(from.col, r))) count++;
      }
    } else if (from.row == to.row) {
      final minCol = from.col < to.col ? from.col : to.col;
      final maxCol = from.col < to.col ? to.col : from.col;
      for (int c = minCol + 1; c < maxCol; c++) {
        if (allPiecePositions.contains(Coord(c, from.row))) count++;
      }
    }
    return count;
  }
}
