import '../utils/constants.dart';
import '../utils/position.dart';
import 'chess_piece.dart';

/// 走步记录
class MoveRecord {
  const MoveRecord({
    required this.from,
    required this.to,
    required this.capturedPiece,
    required this.color,
  });

  final Position from;
  final Position to;
  final ChessPiece? capturedPiece;
  final PieceColor color;
}
