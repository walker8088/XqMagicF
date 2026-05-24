import 'package:magicf/models/move.dart';
import 'package:magicf/utils/position.dart';

/// 中国象棋着法表示法工具
class MoveNotation {
  MoveNotation._();

  /// ICCS 坐标记法: 起始位置(列行) + 目标位置(列行)
  /// 列: 1-9 (从右到左对红方), 行: 1-10
  /// 例如: 8182 表示从 (8,1) 到 (8,2)（红方视角）
  static String toICCS(MoveRecord move) {
    // ICCS 使用 1-indexed, 列从红方右到左为 1-9
    // 我们的 col 是 0-8 从左到右
    // 红方视角: col 0 -> 9, col 8 -> 1
    // row: 我们的 row 0-9 (上到下), ICCS row 1-10 (上到下)
    final fromColIccs = 9 - move.from.col;
    final toColIccs = 9 - move.to.col;
    final fromRowIccs = move.from.row + 1;
    final toRowIccs = move.to.row + 1;
    return '${fromColIccs}${fromRowIccs}${toColIccs}${toRowIccs}';
  }

  /// 从 ICCS 坐标解析为 Position
  static (Position, Position) fromICCS(String iccs) {
    if (iccs.length != 4) throw ArgumentError('ICCS 格式应为4位数字: $iccs');
    final fromCol = 9 - int.parse(iccs[0]);
    final fromRow = int.parse(iccs[1]) - 1;
    final toCol = 9 - int.parse(iccs[2]);
    final toRow = int.parse(iccs[3]) - 1;
    return (Position(fromCol, fromRow), Position(toCol, toRow));
  }

  /// 中文纵线记法：简记法
  /// 红方用中文数字一~九（从右到左），黑方用阿拉伯数字1~9（从右到左）
  /// 格式：棋子名 + 纵线 + 进退平 + 目标
  static String toChinese(MoveRecord move) {
    final pieceName = _getPieceName(move);
    final isRed = move.color.index == 0; // red=0, black=1

    // 纵线编号
    final fromFile = _getFileNumber(move.from.col, isRed);
    final toFile = _getFileNumber(move.to.col, isRed);

    final colDiff = move.to.col - move.from.col;
    final rowDiff = move.to.row - move.from.row;

    String action;
    String target;

    if (rowDiff == 0) {
      action = '平';
      target = toFile;
    } else if (rowDiff < 0) {
      action = '进';
      // 进：如果是车炮兵直线前进，显示步数；如果是马相士，显示目标纵线
      if (colDiff == 0) {
        target = rowDiff.abs().toString();
      } else {
        target = toFile;
      }
    } else {
      action = '退';
      if (colDiff == 0) {
        target = rowDiff.abs().toString();
      } else {
        target = toFile;
      }
    }

    return '$pieceName$fromFile$action$target';
  }

  static String _getPieceName(MoveRecord move) {
    if (move.capturedPiece != null) {
      // 吃子时可能需要区分同名棋子
    }
    final type = move.capturedPiece?.type; // placeholder - should be from piece
    final isRed = move.color.index == 0;
    // This needs the actual piece type from the move source
    // For now, return generic
    return '';
  }

  static String _getFileNumber(int col, bool isRed) {
    // 纵线从右到左编号
    // 红方用中文数字，黑方用阿拉伯数字
    final fileNumber = 9 - col; // 1-9 from right to left
    if (isRed) {
      const chineseNumbers = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
      return chineseNumbers[fileNumber];
    }
    return fileNumber.toString();
  }
}

/// 着法质量标注
class MoveQuality {
  static const int best = 0; // 最优着法（无标记）
  static const int good = -30; // ★ 好棋
  static const int ok = -70; // ✓ 一般
  static const int bad = -100; // ✗ 劣着

  /// 根据分数偏离度获取质量标记
  static String getMark(int diff) {
    if (diff >= best - 5) return '';
    if (diff >= good) return '★';
    if (diff >= ok) return '✓';
    if (diff >= bad) return '✗';
    return '✗✗';
  }

  /// 获取颜色标记
  static String? getColor(int diff) {
    if (diff >= best - 5) return null;
    if (diff >= good) return 'green';
    if (diff >= ok) return 'blue';
    return 'red';
  }
}
