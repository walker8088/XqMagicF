import 'chess_piece.dart';
import '../utils/constants.dart';
import '../utils/coord.dart';

/// 棋盘状态管理
/// 内部使用二维数组 _grid[row][col] 存储 FEN 字符
/// '.' 表示空位，其他字符表示对应棋子
class Board {
  Board() : _grid = _createEmptyGrid();

  /// 棋盘格子上的棋子，_grid[row][col] 存储 FEN 字符
  /// row: 0-9 (红方在下方 row 0-4, 黑方在上方 row 5-9)
  /// col: 0-8
  final List<List<String>> _grid;

  /// FEN 字符映射到 (PieceType, PieceColor)
  static final Map<String, (PieceType, PieceColor)> _charToPiece = {
    'K': (PieceType.king, PieceColor.red),
    'A': (PieceType.advisor, PieceColor.red),
    'B': (PieceType.bishop, PieceColor.red),
    'N': (PieceType.knight, PieceColor.red),
    'R': (PieceType.rook, PieceColor.red),
    'C': (PieceType.cannon, PieceColor.red),
    'P': (PieceType.pawn, PieceColor.red),
    'k': (PieceType.king, PieceColor.black),
    'a': (PieceType.advisor, PieceColor.black),
    'b': (PieceType.bishop, PieceColor.black),
    'n': (PieceType.knight, PieceColor.black),
    'r': (PieceType.rook, PieceColor.black),
    'c': (PieceType.cannon, PieceColor.black),
    'p': (PieceType.pawn, PieceColor.black),
  };

  /// (PieceType, PieceColor) 映射到 FEN 字符
  static final Map<(PieceType, PieceColor), String> _pieceToChar = {
    for (final entry in _charToPiece.entries) entry.value: entry.key,
  };

  static List<List<String>> _createEmptyGrid() {
    return List.generate(
      AppConstants.boardRows,
      (_) => List.filled(AppConstants.boardCols, '.'),
    );
  }

  /// 获取不可变的棋盘视图（从网格构建）
  Map<Coord, ChessPiece> get pieces {
    final result = <Coord, ChessPiece>{};
    for (int row = 0; row < AppConstants.boardRows; row++) {
      for (int col = 0; col < AppConstants.boardCols; col++) {
        final char = _grid[row][col];
        if (char != '.') {
          final entry = _charToPiece[char];
          if (entry != null) {
            final (type, color) = entry;
            result[Coord(col, row)] = ChessPiece(
              type: type,
              color: color,
              coord: Coord(col, row),
            );
          }
        }
      }
    }
    return Map.unmodifiable(result);
  }

  /// 获取指定位置的棋子
  ChessPiece? getPiece(Coord pos) {
    if (!isValidPosition(pos)) return null;
    final char = _grid[pos.row][pos.col];
    if (char == '.') return null;
    final entry = _charToPiece[char];
    if (entry == null) return null;
    final (type, color) = entry;
    return ChessPiece(type: type, color: color, coord: pos);
  }

  /// 放置棋子
  void putPiece(ChessPiece piece) {
    final char = _pieceToChar[(piece.type, piece.color)];
    if (char != null) {
      _grid[piece.coord.row][piece.coord.col] = char;
    }
  }

  /// 移动棋子，返回被吃掉的棋子（如有）
  ChessPiece? movePiece(Coord from, Coord to) {
    final fromChar = _grid[from.row][from.col];
    if (fromChar == '.') return null;

    final toChar = _grid[to.row][to.col];
    ChessPiece? captured;
    if (toChar != '.') {
      final entry = _charToPiece[toChar];
      if (entry != null) {
        final (type, color) = entry;
        captured = ChessPiece(type: type, color: color, coord: to);
      }
    }

    _grid[to.row][to.col] = fromChar;
    _grid[from.row][from.col] = '.';
    return captured;
  }

  /// 移除指定位置的棋子
  ChessPiece? removePiece(Coord pos) {
    final char = _grid[pos.row][pos.col];
    if (char == '.') return null;
    final entry = _charToPiece[char];
    if (entry == null) return null;
    final (type, color) = entry;
    final piece = ChessPiece(type: type, color: color, coord: pos);
    _grid[pos.row][pos.col] = '.';
    return piece;
  }

  /// 清空棋盘
  void clear() {
    for (int row = 0; row < AppConstants.boardRows; row++) {
      for (int col = 0; col < AppConstants.boardCols; col++) {
        _grid[row][col] = '.';
      }
    }
  }

  /// 初始化标准象棋棋盘
  void initialize() {
    clear();

    // 红方（下方 row 0-4）
    _putRow(PieceColor.red, 0, [
      PieceType.rook,
      PieceType.knight,
      PieceType.bishop,
      PieceType.advisor,
      PieceType.king,
      PieceType.advisor,
      PieceType.bishop,
      PieceType.knight,
      PieceType.rook,
    ]);
    putPiece(
      ChessPiece(
        type: PieceType.cannon,
        color: PieceColor.red,
        coord: const Coord(1, 2),
      ),
    );
    putPiece(
      ChessPiece(
        type: PieceType.cannon,
        color: PieceColor.red,
        coord: const Coord(7, 2),
      ),
    );
    for (final col in [0, 2, 4, 6, 8]) {
      putPiece(
        ChessPiece(
          type: PieceType.pawn,
          color: PieceColor.red,
          coord: Coord(col, 3),
        ),
      );
    }

    // 黑方（上方 row 5-9）
    _putRow(PieceColor.black, 9, [
      PieceType.rook,
      PieceType.knight,
      PieceType.bishop,
      PieceType.advisor,
      PieceType.king,
      PieceType.advisor,
      PieceType.bishop,
      PieceType.knight,
      PieceType.rook,
    ]);
    putPiece(
      ChessPiece(
        type: PieceType.cannon,
        color: PieceColor.black,
        coord: const Coord(1, 7),
      ),
    );
    putPiece(
      ChessPiece(
        type: PieceType.cannon,
        color: PieceColor.black,
        coord: const Coord(7, 7),
      ),
    );
    for (final col in [0, 2, 4, 6, 8]) {
      putPiece(
        ChessPiece(
          type: PieceType.pawn,
          color: PieceColor.black,
          coord: Coord(col, 6),
        ),
      );
    }
  }

  void _putRow(PieceColor color, int row, List<PieceType> types) {
    for (int col = 0; col < AppConstants.boardCols; col++) {
      putPiece(
        ChessPiece(type: types[col], color: color, coord: Coord(col, row)),
      );
    }
  }

  /// 获取某方的所有棋子
  List<ChessPiece> getPiecesOfColor(PieceColor color) {
    final result = <ChessPiece>[];
    for (int row = 0; row < AppConstants.boardRows; row++) {
      for (int col = 0; col < AppConstants.boardCols; col++) {
        final char = _grid[row][col];
        if (char != '.') {
          final entry = _charToPiece[char];
          if (entry != null) {
            final (type, pieceColor) = entry;
            if (pieceColor == color) {
              result.add(
                ChessPiece(type: type, color: color, coord: Coord(col, row)),
              );
            }
          }
        }
      }
    }
    return result;
  }

  /// 判断位置是否在棋盘内
  bool isValidPosition(Coord pos) =>
      pos.col >= 0 &&
      pos.col < AppConstants.boardCols &&
      pos.row >= 0 &&
      pos.row < AppConstants.boardRows;
}
