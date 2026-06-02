import 'package:xqmagic/models/board.dart';
import 'package:xqmagic/models/chess_piece.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/coord.dart';

/// FEN (Forsyth-Edwards Notation) for Chinese Chess (Xiangqi)
/// Format: rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w
/// - Board: 10 rows separated by '/' (row 0 = top = black side)
/// - Pieces: uppercase = red, lowercase = black
/// - Active color: 'w' (white/red) or 'b' (black)
class FenParser {
  FenParser._();

  static const String initial =
      'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w';

  /// Convert piece type and color to FEN character
  static String pieceToFenChar(PieceType type, PieceColor color) {
    final char = switch (type) {
      PieceType.king => 'k',
      PieceType.advisor => 'a',
      PieceType.bishop => 'b', // bishop
      PieceType.knight => 'n',
      PieceType.rook => 'r',
      PieceType.cannon => 'c',
      PieceType.pawn => 'p',
    };
    return color == PieceColor.red ? char.toUpperCase() : char;
  }

  /// Convert FEN character to piece type and color
  static (PieceType, PieceColor)? fenCharToPiece(String char) {
    if (char.isEmpty) return null;
    final lower = char.toLowerCase();
    final color = char == lower ? PieceColor.black : PieceColor.red;
    final type = switch (lower) {
      'k' => PieceType.king,
      'a' => PieceType.advisor,
      'b' => PieceType.bishop,
      'n' => PieceType.knight,
      'r' => PieceType.rook,
      'c' => PieceType.cannon,
      'p' => PieceType.pawn,
      _ => null,
    };
    if (type == null) return null;
    return (type, color);
  }

  /// Generate FEN string from board state
  /// FEN row 0 = top of board (Black side, our row 9)
  /// FEN row 9 = bottom of board (Red side, our row 0)
  static String generate(Board board, PieceColor activeColor) {
    final rows = <String>[];
    for (int fenRow = 0; fenRow < AppConstants.boardRows; fenRow++) {
      final row = AppConstants.boardRows - 1 - fenRow;
      int emptyCount = 0;
      String rowStr = '';
      for (int col = 0; col < AppConstants.boardCols; col++) {
        final piece = board.getPiece(Coord(col, row));
        if (piece == null) {
          emptyCount++;
        } else {
          if (emptyCount > 0) {
            rowStr += emptyCount.toString();
            emptyCount = 0;
          }
          rowStr += pieceToFenChar(piece.type, piece.color);
        }
      }
      if (emptyCount > 0) rowStr += emptyCount.toString();
      rows.add(rowStr);
    }
    final boardStr = rows.join('/');
    return '$boardStr ${activeColor == PieceColor.red ? "w" : "b"}';
  }

  /// Parse FEN string and populate the board
  /// FEN row 0 = top of board (Black side) → our row 9
  /// FEN row 9 = bottom of board (Red side) → our row 0
  ///
  /// FEN 至少包含两个字段：布局和走子方(r/b)
  static PieceColor parse(String fen, Board board) {
    board.clear();

    final parts = fen.trim().split(' ');
    assert(parts.length >= 2, 'FEN 至少需要两个字段（布局 + 走子方），收到: "$fen"');
    final boardStr = parts[0];
    // 兼容多种走子方表示：'w' (UCI 标准)、'r' (部分引擎)、其他默认为红方
    final activeColor = parts[1].toLowerCase() == 'b'
        ? PieceColor.black
        : PieceColor.red;

    final fenRows = boardStr.split('/');
    for (
      int fenRow = 0;
      fenRow < fenRows.length && fenRow < AppConstants.boardRows;
      fenRow++
    ) {
      final row = AppConstants.boardRows - 1 - fenRow;
      int col = 0;
      for (final char in fenRows[fenRow].split('')) {
        if (int.tryParse(char) != null) {
          col += int.parse(char);
        } else {
          final result = fenCharToPiece(char);
          if (result != null) {
            final (type, color) = result;
            board.putPiece(
              ChessPiece(type: type, color: color, coord: Coord(col, row)),
            );
          }
          col++;
        }
      }
    }
    return activeColor;
  }

  /// Generate a unique hash key for the board position (for transposition table)
  static int generateHash(String boardOnly) {
    // Simple Zobrist-like hash from the board-only FEN
    int hash = 0;
    for (int i = 0; i < boardOnly.length; i++) {
      hash = ((hash << 5) - hash) + boardOnly.codeUnitAt(i);
      hash |= 0; // Convert to 32bit integer
    }
    return hash;
  }
}
