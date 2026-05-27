import 'package:xqmagic/models/chess_piece.dart';
import 'package:xqmagic/models/move.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/coord.dart';
import 'package:xqmagic/utils/move_notation.dart';

/// PV 线路中文记谱转换器
///
/// 专注于多步 PV 线路的棋盘模拟和中文转换，
/// 单步格式化已统一到 [MoveNotation.formatMoveDisplay] 中
class PVChineseConverter {
  PVChineseConverter._();

  /// 将单步 ICCS 着法转换为中文记谱
  ///
  /// 如需 "中文记谱(ICCS)" 组合格式，请使用 [MoveNotation.formatMoveDisplay]
  static String singleMove(
    Map<Coord, ChessPiece> board,
    PieceColor activeColor,
    String iccs,
  ) {
    if (iccs.length != 4) return iccs;
    try {
      final (from, to) = MoveNotation.fromICCS(iccs);
      final piece = board[from];
      if (piece == null) return iccs;

      final move = MoveRecord(
        from: from,
        to: to,
        pieceType: piece.type,
        color: activeColor,
      );
      return MoveNotation.toText(board, move);
    } catch (_) {
      return iccs;
    }
  }

  /// 将 PV 线路（多步 ICCS 着法）转换为中文记谱列表
  ///
  /// 通过轻量级棋盘模拟，逐步转换每一步为中文记谱。
  /// 每一步都使用当时的棋盘状态，确保"进/退/平"方向正确。
  ///
  /// [board] 初始棋盘状态
  /// [activeColor] 初始走棋方
  /// [pv] ICCS 着法列表
  /// 返回中文记谱列表，如 ["炮二平五", "马8进7", "车一平二"]
  static List<String> pvLine(
    Map<Coord, ChessPiece> board,
    PieceColor activeColor,
    List<String> pv,
  ) {
    final chineseMoves = <String>[];
    // 轻量级副本：只复制 Map，不创建引擎
    final boardCopy = Map<Coord, ChessPiece>.from(board);
    var currentColor = activeColor;

    for (final iccs in pv) {
      if (iccs.length != 4) break;
      try {
        final (from, to) = MoveNotation.fromICCS(iccs);
        final piece = boardCopy[from];
        if (piece == null) break;

        final move = MoveRecord(
          from: from,
          to: to,
          pieceType: piece.type,
          color: currentColor,
        );
        chineseMoves.add(MoveNotation.toText(boardCopy, move));

        // 模拟走子：移动棋子
        boardCopy[to] = piece;
        boardCopy.remove(from);

        // 切换回合
        currentColor = currentColor == PieceColor.red
            ? PieceColor.black
            : PieceColor.red;
      } catch (_) {
        break;
      }
    }
    return chineseMoves;
  }

  /// 将 PV 线路格式化为 "中文记谱(iccs)" 的列表
  /// 单步格式化委托给 [MoveNotation.formatMoveDisplay]
  static List<String> formatPVWithChinese(
    Map<Coord, ChessPiece> board,
    PieceColor activeColor,
    List<String> pv,
  ) {
    final chineseMoves = pvLine(board, activeColor, pv);
    final result = <String>[];
    for (int i = 0; i < pv.length; i++) {
      final iccs = MoveNotation.formatICCS(pv[i]);
      result.add(i < chineseMoves.length ? '${chineseMoves[i]}($iccs)' : iccs);
    }
    return result;
  }
}
