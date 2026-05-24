import 'chess_piece.dart';
import '../utils/constants.dart';
import '../utils/position.dart';

/// 棋盘状态管理
class Board {
  Board() : _pieces = {};

  /// 棋盘格子上的棋子，key 为 Position
  final Map<Position, ChessPiece> _pieces;

  Map<Position, ChessPiece> get pieces => Map.unmodifiable(_pieces);

  /// 获取指定位置的棋子
  ChessPiece? getPiece(Position pos) => _pieces[pos];

  /// 放置棋子
  void putPiece(ChessPiece piece) {
    _pieces[piece.position] = piece;
  }

  /// 移动棋子，返回被吃掉的棋子（如有）
  ChessPiece? movePiece(Position from, Position to) {
    final piece = _pieces.remove(from);
    if (piece == null) return null;

    final captured = _pieces[to];
    final movedPiece = piece.copyWith(position: to);
    _pieces[to] = movedPiece;
    return captured;
  }

  /// 移除指定位置的棋子
  ChessPiece? removePiece(Position pos) => _pieces.remove(pos);

  /// 清空棋盘
  void clear() => _pieces.clear();

  /// 初始化标准象棋棋盘
  void initialize() {
    _pieces.clear();

    // 黑方（上方 row 0-4）
    _putRow(PieceColor.black, 0, [
      PieceType.chariot,
      PieceType.horse,
      PieceType.elephant,
      PieceType.advisor,
      PieceType.general,
      PieceType.advisor,
      PieceType.elephant,
      PieceType.horse,
      PieceType.chariot,
    ]);
    putPiece(
      ChessPiece(
        type: PieceType.cannon,
        color: PieceColor.black,
        position: const Position(1, 2),
      ),
    );
    putPiece(
      ChessPiece(
        type: PieceType.cannon,
        color: PieceColor.black,
        position: const Position(7, 2),
      ),
    );
    for (final col in [0, 2, 4, 6, 8]) {
      putPiece(
        ChessPiece(
          type: PieceType.soldier,
          color: PieceColor.black,
          position: Position(col, 3),
        ),
      );
    }

    // 红方（下方 row 5-9）
    _putRow(PieceColor.red, 9, [
      PieceType.chariot,
      PieceType.horse,
      PieceType.elephant,
      PieceType.advisor,
      PieceType.general,
      PieceType.advisor,
      PieceType.elephant,
      PieceType.horse,
      PieceType.chariot,
    ]);
    putPiece(
      ChessPiece(
        type: PieceType.cannon,
        color: PieceColor.red,
        position: const Position(1, 7),
      ),
    );
    putPiece(
      ChessPiece(
        type: PieceType.cannon,
        color: PieceColor.red,
        position: const Position(7, 7),
      ),
    );
    for (final col in [0, 2, 4, 6, 8]) {
      putPiece(
        ChessPiece(
          type: PieceType.soldier,
          color: PieceColor.red,
          position: Position(col, 6),
        ),
      );
    }
  }

  void _putRow(PieceColor color, int row, List<PieceType> types) {
    for (int col = 0; col < AppConstants.boardCols; col++) {
      putPiece(
        ChessPiece(
          type: types[col],
          color: color,
          position: Position(col, row),
        ),
      );
    }
  }

  /// 获取某方的所有棋子
  List<ChessPiece> getPiecesOfColor(PieceColor color) {
    return _pieces.values.where((p) => p.color == color).toList();
  }

  /// 判断位置是否在棋盘内
  bool isValidPosition(Position pos) =>
      pos.col >= 0 &&
      pos.col < AppConstants.boardCols &&
      pos.row >= 0 &&
      pos.row < AppConstants.boardRows;
}
