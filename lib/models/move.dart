import '../utils/constants.dart';
import '../utils/coord.dart';
import 'chess_piece.dart';

/// 走步记录
class MoveRecord {
  const MoveRecord({
    required this.from,
    required this.to,
    this.pieceType,
    this.capturedPiece,
    required this.color,
    this.notation,
    this.killedKing = false,
  });

  final Coord from;
  final Coord to;
  final PieceType? pieceType;
  final ChessPiece? capturedPiece;
  final PieceColor color;

  /// 中文记谱法（如 "炮二平五"），在走子时生成并永久保存
  final String? notation;

  /// 该步是否吃掉了对方将/帅，导致游戏结束
  final bool killedKing;

  /// 创建副本并更新记谱
  MoveRecord withNotation(String notation) {
    return MoveRecord(
      from: from,
      to: to,
      pieceType: pieceType,
      capturedPiece: capturedPiece,
      color: color,
      notation: notation,
      killedKing: killedKing,
    );
  }

  /// 创建副本并标记为杀王
  MoveRecord withKilledKing() {
    return MoveRecord(
      from: from,
      to: to,
      pieceType: pieceType,
      capturedPiece: capturedPiece,
      color: color,
      notation: notation,
      killedKing: true,
    );
  }
}
