import 'package:magicf/models/board.dart';
import 'package:magicf/models/chess_piece.dart';
import 'package:magicf/utils/constants.dart';
import 'package:magicf/utils/position.dart';

/// FEN (Forsyth-Edwards Notation) for Chinese Chess (Xiangqi)
/// Format: rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR r
/// - Board: 10 rows separated by '/' (row 0 = top = black side)
/// - Pieces: uppercase = red, lowercase = black
/// - Active color: 'r' (red) or 'b' (black)
class FenParser {
  FenParser._();

  static const String initial =
      'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR r';

  /// Convert piece type and color to FEN character
  static String pieceToFenChar(PieceType type, PieceColor color) {
    final char = switch (type) {
      PieceType.general => 'k',
      PieceType.advisor => 'a',
      PieceType.elephant => 'b', // bishop
      PieceType.horse => 'n',
      PieceType.chariot => 'r',
      PieceType.cannon => 'c',
      PieceType.soldier => 'p',
    };
    return color == PieceColor.red ? char.toUpperCase() : char;
  }

  /// Convert FEN character to piece type and color
  static (PieceType, PieceColor)? fenCharToPiece(String char) {
    if (char.isEmpty) return null;
    final lower = char.toLowerCase();
    final color = char == lower ? PieceColor.black : PieceColor.red;
    final type = switch (lower) {
      'k' => PieceType.general,
      'a' => PieceType.advisor,
      'b' => PieceType.elephant,
      'n' => PieceType.horse,
      'r' => PieceType.chariot,
      'c' => PieceType.cannon,
      'p' => PieceType.soldier,
      _ => null,
    };
    if (type == null) return null;
    return (type, color);
  }

  /// Generate FEN string from board state
  static String generate(Board board, PieceColor activeColor) {
    final rows = <String>[];
    for (int row = 0; row < AppConstants.boardRows; row++) {
      int emptyCount = 0;
      String rowStr = '';
      for (int col = 0; col < AppConstants.boardCols; col++) {
        final piece = board.getPiece(Position(col, row));
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
    return '$boardStr ${activeColor == PieceColor.red ? "r" : "b"}';
  }

  /// Parse FEN string and populate the board
  static PieceColor parse(String fen, Board board) {
    board.clear();

    final parts = fen.trim().split(' ');
    final boardStr = parts[0];
    final activeColor = parts.length > 1 && parts[1] == 'b'
        ? PieceColor.black
        : PieceColor.red;

    final rows = boardStr.split('/');
    for (
      int row = 0;
      row < rows.length && row < AppConstants.boardRows;
      row++
    ) {
      int col = 0;
      for (final char in rows[row].split('')) {
        if (int.tryParse(char) != null) {
          col += int.parse(char);
        } else {
          final result = fenCharToPiece(char);
          if (result != null) {
            final (type, color) = result;
            board.putPiece(
              ChessPiece(
                type: type,
                color: color,
                position: Position(col, row),
              ),
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
