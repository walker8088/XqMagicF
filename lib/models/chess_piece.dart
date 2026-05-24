import '../utils/constants.dart';
import '../utils/position.dart';

/// 棋子模型
class ChessPiece {
  const ChessPiece({
    required this.type,
    required this.color,
    required this.position,
  });

  final PieceType type;
  final PieceColor color;
  final Position position;

  ChessPiece copyWith({
    PieceType? type,
    PieceColor? color,
    Position? position,
  }) {
    return ChessPiece(
      type: type ?? this.type,
      color: color ?? this.color,
      position: position ?? this.position,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChessPiece &&
          type == other.type &&
          color == other.color &&
          position == other.position;

  @override
  int get hashCode => type.hashCode ^ color.hashCode ^ position.hashCode;
}
