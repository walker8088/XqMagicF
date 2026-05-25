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
  });

  final Coord from;
  final Coord to;
  final PieceType? pieceType;
  final ChessPiece? capturedPiece;
  final PieceColor color;

  /// 中文记谱法（如 "炮二平五"），在走子时生成并永久保存
  final String? notation;

  /// 创建副本并更新记谱
  MoveRecord withNotation(String notation) {
    return MoveRecord(
      from: from,
      to: to,
      pieceType: pieceType,
      capturedPiece: capturedPiece,
      color: color,
      notation: notation,
    );
  }
}
