import '../utils/constants.dart';
import '../utils/coord.dart';
import 'chess_piece.dart';

/// 走步记录
///
/// 包含走子前后完整状态，所有引擎/云库查询和记谱显示都从这里取。
class MoveRecord {
  const MoveRecord({
    required this.from,
    required this.to,
    this.pieceType,
    this.capturedPiece,
    required this.color,
    this.notation,
    this.nextColor,
    this.boardBefore = const {},
    this.boardAfter = const {},
    this.fenBefore,
    this.fenAfter,
  });

  final Coord from;
  final Coord to;
  final PieceType? pieceType;

  /// 被吃的棋子（null = 移动未吃子）
  /// 若 type == PieceType.king 则表示将/帅被吃，游戏结束
  final ChessPiece? capturedPiece;

  /// 走子方（红方或黑方）
  final PieceColor color;

  /// 走子后的下一步走子方（用于历史回溯和引擎/云库查询）
  final PieceColor? nextColor;

  /// 中文记谱法（如 "炮二平五"），在走子时生成并永久保存
  final String? notation;

  /// 走子前的棋盘状态（局面 FEN 反映的状态）
  final Map<Coord, ChessPiece> boardBefore;

  /// 走子后的棋盘状态（用于记谱显示和分析）
  final Map<Coord, ChessPiece> boardAfter;

  /// 走子前的 FEN（引擎/云库查询用）
  final String? fenBefore;

  /// 走子后的 FEN（引擎/云库查询用）
  final String? fenAfter;

  /// 是否吃掉了将/帅（由 capturedPiece?.type == PieceType.king 推导）
  bool get killedKing =>
      capturedPiece != null && capturedPiece!.type == PieceType.king;

  /// 创建副本并更新记谱
  MoveRecord withNotation(String notation) {
    return MoveRecord(
      from: from,
      to: to,
      pieceType: pieceType,
      capturedPiece: capturedPiece,
      color: color,
      notation: notation,
      nextColor: nextColor,
      boardBefore: boardBefore,
      boardAfter: boardAfter,
      fenBefore: fenBefore,
      fenAfter: fenAfter,
    );
  }

  /// 创建副本并设置下一步走子方
  MoveRecord withNextColor(PieceColor nextColor) {
    return MoveRecord(
      from: from,
      to: to,
      pieceType: pieceType,
      capturedPiece: capturedPiece,
      color: color,
      notation: notation,
      nextColor: nextColor,
      boardBefore: boardBefore,
      boardAfter: boardAfter,
      fenBefore: fenBefore,
      fenAfter: fenAfter,
    );
  }

  /// 创建完整副本（含走子前后状态）
  MoveRecord withBoardState({
    required Map<Coord, ChessPiece> boardBefore,
    required Map<Coord, ChessPiece> boardAfter,
    required String fenBefore,
    required String fenAfter,
  }) {
    return MoveRecord(
      from: from,
      to: to,
      pieceType: pieceType,
      capturedPiece: capturedPiece,
      color: color,
      notation: notation,
      nextColor: nextColor,
      boardBefore: boardBefore,
      boardAfter: boardAfter,
      fenBefore: fenBefore,
      fenAfter: fenAfter,
    );
  }
}
