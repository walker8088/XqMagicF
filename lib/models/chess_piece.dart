import '../utils/constants.dart';
import '../utils/coord.dart';

/// 棋子模型
class ChessPiece {
  const ChessPiece({
    required this.type,
    required this.color,
    required this.coord,
  });

  final PieceType type;
  final PieceColor color;
  final Coord coord;

  ChessPiece copyWith({PieceType? type, PieceColor? color, Coord? coord}) {
    return ChessPiece(
      type: type ?? this.type,
      color: color ?? this.color,
      coord: coord ?? this.coord,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChessPiece &&
          type == other.type &&
          color == other.color &&
          coord == other.coord;

  @override
  int get hashCode => type.hashCode ^ color.hashCode ^ coord.hashCode;
}
