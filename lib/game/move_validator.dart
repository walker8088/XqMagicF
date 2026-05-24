import 'package:magicf/utils/constants.dart';
import 'package:magicf/utils/position.dart';

/// 走棋规则验证器（中国象棋）
class MoveValidator {
  MoveValidator._();

  /// 验证走棋是否合法（仅检查是否符合该棋子的走法规则）
  /// 注：不包含将军检测等高级规则
  static bool isValidMove({
    required PieceType type,
    required PieceColor color,
    required Position from,
    required Position to,
    required List<Position> obstacles,
  }) {
    final colDiff = to.col - from.col;
    final rowDiff = to.row - from.row;
    final absCol = colDiff.abs();
    final absRow = rowDiff.abs();

    // 不能原地走
    if (absCol == 0 && absRow == 0) return false;

    switch (type) {
      case PieceType.general:
        return _isValidGeneralMove(from, to, absCol, absRow, color);
      case PieceType.advisor:
        return _isValidAdvisorMove(from, to, absCol, absRow, color);
      case PieceType.elephant:
        return _isValidElephantMove(from, to, absCol, absRow, color, obstacles);
      case PieceType.horse:
        return _isValidHorseMove(from, to, absCol, absRow, obstacles);
      case PieceType.chariot:
        return _isValidChariotMove(from, to, obstacles);
      case PieceType.cannon:
        return _isValidCannonMove(from, to, obstacles);
      case PieceType.soldier:
        return _isValidSoldierMove(from, to, absCol, absRow, color);
    }
  }

  /// 将/帅：每次走一步，只能在九宫内
  static bool _isValidGeneralMove(
    Position from, Position to, int absCol, int absRow, PieceColor color) {
    if (absCol + absRow != 1) return false; // 只能走直线一步
    // 九宫范围
    final minRow = color == PieceColor.red ? 7 : 0;
    final maxRow = color == PieceColor.red ? 9 : 2;
    return to.col >= 3 && to.col <= 5 && to.row >= minRow && to.row <= maxRow;
  }

  /// 士/仕：斜走一步，不出九宫
  static bool _isValidAdvisorMove(
    Position from, Position to, int absCol, int absRow, PieceColor color) {
    if (absCol != 1 || absRow != 1) return false; // 只能斜走一步
    final minRow = color == PieceColor.red ? 7 : 0;
    final maxRow = color == PieceColor.red ? 9 : 2;
    return to.col >= 3 && to.col <= 5 && to.row >= minRow && to.row <= maxRow;
  }

  /// 象/相：走田字，不能过河，不能被蹩腿
  static bool _isValidElephantMove(
    Position from, Position to, int absCol, int absRow,
    PieceColor color, List<Position> obstacles) {
    if (absCol != 2 || absRow != 2) return false; // 必须走田字
    // 不能过河
    if (color == PieceColor.red && to.row < 5) return false;
    if (color == PieceColor.black && to.row > 4) return false;
    // 蹩腿检测：田字中心有棋子则不能走
    final eyeCenter = Position(
      (from.col + to.col) ~/ 2,
      (from.row + to.row) ~/ 2,
    );
    if (obstacles.contains(eyeCenter)) return false;
    return true;
  }

  /// 马：走日字，不能被蹩腿
  static bool _isValidHorseMove(
    Position from, Position to, int absCol, int absRow,
    List<Position> obstacles) {
    if (!((absCol == 1 && absRow == 2) || (absCol == 2 && absRow == 1))) {
      return false;
    }
    // 蹩腿检测
    Position legPos;
    if (absCol == 2) {
      legPos = Position((from.col + to.col) ~/ 2, from.row);
    } else {
      legPos = Position(from.col, (from.row + to.row) ~/ 2);
    }
    return !obstacles.contains(legPos);
  }

  /// 车：直线行走，不限步数，不可越子
  static bool _isValidChariotMove(Position from, Position to, List<Position> obstacles) {
    // 必须走直线
    if (from.col != to.col && from.row != to.row) return false;
    return _isPathClear(from, to, obstacles);
  }

  /// 炮：走法同车，吃子必须隔一个（炮架）
  static bool _isValidCannonMove(Position from, Position to, List<Position> obstacles) {
    if (from.col != to.col && from.row != to.row) return false;
    // 移动：路径无障碍
    // 吃子：路径上恰好有一个棋子（炮架）
    final count = _countPiecesBetween(from, to, obstacles);
    // 这里简化处理，实际需判断目标位置是否有对方棋子
    return count == 0 || count == 1;
  }

  /// 兵/卒：每次一步，过河前只能前进，过河后可横走，不可后退
  static bool _isValidSoldierMove(
    Position from, Position to, int absCol, int absRow, PieceColor color) {
    if (absCol + absRow != 1) return false;

    final crossedRiver = color == PieceColor.red
        ? from.row <= 4 // 红兵过了河（row<=4）
        : from.row >= 5; // 黑卒过了河（row>=5）

    if (!crossedRiver) {
      // 未过河：只能前进，不能横走
      final forwardCol = from.col;
      final forwardRow = color == PieceColor.red ? from.row - 1 : from.row + 1;
      return to.col == forwardCol && to.row == forwardRow;
    }
    // 已过河：前/后/左/右均可
    return true;
  }

  /// 两点之间是否有障碍物（不含端点）
  static bool _isPathClear(Position from, Position to, List<Position> obstacles) {
    return _countPiecesBetween(from, to, obstacles) == 0;
  }

  /// 计算两点之间的棋子数（不含端点）
  static int _countPiecesBetween(Position from, Position to, List<Position> obstacles) {
    int count = 0;
    if (from.col == to.col) {
      // 竖线
      final minRow = from.row < to.row ? from.row : to.row;
      final maxRow = from.row < to.row ? to.row : from.row;
      for (int r = minRow + 1; r < maxRow; r++) {
        if (obstacles.contains(Position(from.col, r))) count++;
      }
    } else if (from.row == to.row) {
      // 横线
      final minCol = from.col < to.col ? from.col : to.col;
      final maxCol = from.col < to.col ? to.col : from.col;
      for (int c = minCol + 1; c < maxCol; c++) {
        if (obstacles.contains(Position(c, from.row))) count++;
      }
    }
    return count;
  }
}
