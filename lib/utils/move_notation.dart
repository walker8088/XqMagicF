import 'package:xqmagic/models/chess_piece.dart';
import 'package:xqmagic/models/move.dart';
import 'package:xqmagic/utils/chinese_notation.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/coord.dart';

/// 中国象棋着法表示法工具
///
/// ICCS 格式：用于引擎通信（UCI/UCCI）
/// 中文格式：用于人类阅读（符合1999竞赛规则）
/// WXF 格式：中间表示，便于简繁体转换
class MoveNotation {
  MoveNotation._();

  // ========== ICCS 格式（引擎通信用） ==========

  /// 将走法记录转换为 ICCS 格式（引擎通信用）
  ///
  /// 引擎 UCCI 的 rank 约定：0=黑方底线(顶), 9=红方底线(底)
  /// 内部 row 约定：row=0=红方底线(底), row=9=黑方底线(顶)
  /// 需要转换：engineRank = 9 - ourRow
  static String toICCS(MoveRecord move) {
    final fromFile = _colToFile(move.from.col);
    final fromRank = 9 - move.from.row;
    final toFile = _colToFile(move.to.col);
    final toRank = 9 - move.to.row;
    return '${fromFile}${fromRank}${toFile}${toRank}';
  }

  /// 从 ICCS 代数坐标解析为 Coord
  ///
  /// 引擎 UCCI 的 rank 约定：0=黑方底线(顶), 9=红方底线(底)
  /// 内部 row 约定：row=0=红方底线(底), row=9=黑方底线(顶)
  /// 需要转换：ourRow = 9 - engineRank
  static (Coord, Coord) fromICCS(String iccs) {
    if (iccs.length != 4) throw ArgumentError('ICCS 格式应为4位: $iccs');
    final fromCol = _fileToCol(iccs[0]);
    final engineFromRank = int.parse(iccs[1]);
    final toCol = _fileToCol(iccs[2]);
    final engineToRank = int.parse(iccs[3]);
    return (Coord(fromCol, 9 - engineFromRank), Coord(toCol, 9 - engineToRank));
  }

  static String _colToFile(int col) {
    return String.fromCharCode('a'.codeUnitAt(0) + col);
  }

  static int _fileToCol(String file) {
    return file.codeUnitAt(0) - 'a'.codeUnitAt(0);
  }

  // ========== 中文记谱法（人类阅读用） ==========

  /// 将走法转换为标准中文记谱法（四字/五字格式）
  ///
  /// 例如：炮二平五、马8进7、车二进三、前炮平五
  ///
  /// [board] 当前棋盘（用于检查同线是否有同类型棋子）
  /// [move] 走法记录
  /// [useSimpleText] 是否使用简体中文（默认true），false 则使用繁体
  static String toText(
    Map<Coord, ChessPiece> board,
    MoveRecord move, {
    bool useSimpleText = true,
  }) {
    return ChineseNotation.toText(board, move, useSimpleText: useSimpleText);
  }

  /// 将走法转换为 WXF 格式（World Xiangqi Federation Notation）
  ///
  /// 例如：C2.5 (炮二平五), N8+7 (马8进7), R2+3 (车二进三)
  /// 同线多子：fC2.5 (前炮平五), bN8-7 (后马退7)
  static String toWXF(Map<Coord, ChessPiece> board, MoveRecord move) {
    return ChineseNotation.toWXF(board, move);
  }

  /// 从 WXF 格式解析为坐标
  static (Coord, Coord)? fromWXF(
    Map<Coord, ChessPiece> board,
    String wxf,
    PieceColor color,
  ) {
    return ChineseNotation.fromWXF(board, wxf, color);
  }

  // ========== 组合格式化（中文 + ICCS） ==========

  /// 将 ICCS 着法格式化为 "中文记谱(iccs)" 的显示格式
  ///
  /// 例如："c2e2" → "炮二平五(c2-e2)"
  ///
  /// [board] 当前棋盘状态
  /// [color] 走棋方
  /// [iccs] ICCS 格式着法（如 "c2e2"）
  static String formatMoveDisplay(
    Map<Coord, ChessPiece> board,
    PieceColor color,
    String iccs,
  ) {
    if (iccs.length != 4) return iccs;
    try {
      final (from, to) = fromICCS(iccs);
      final piece = board[from];
      if (piece == null) return formatICCS(iccs);

      final move = MoveRecord(
        from: from,
        to: to,
        pieceType: piece.type,
        color: color,
      );
      final chinese = toText(board, move);
      return '$chinese(${formatICCS(iccs)})';
    } catch (_) {
      return formatICCS(iccs);
    }
  }

  /// 格式化着法显示：ICCS → 人类可读格式 (e7-e5)
  static String formatICCS(String iccs) {
    if (iccs.length != 4) return iccs;
    return '${iccs.substring(0, 2)}-${iccs.substring(2)}';
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
