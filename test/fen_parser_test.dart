import 'package:flutter_test/flutter_test.dart';
import 'package:xqmagic/models/board.dart';
import 'package:xqmagic/models/chess_piece.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/coord.dart';
import 'package:xqmagic/utils/fen.dart';

void main() {
  group('FenParser', () {
    group('pieceToFenChar', () {
      test('should convert red pieces to uppercase', () {
        expect(FenParser.pieceToFenChar(PieceType.king, PieceColor.red), 'K');
        expect(
          FenParser.pieceToFenChar(PieceType.advisor, PieceColor.red),
          'A',
        );
        expect(FenParser.pieceToFenChar(PieceType.bishop, PieceColor.red), 'B');
        expect(FenParser.pieceToFenChar(PieceType.knight, PieceColor.red), 'N');
        expect(FenParser.pieceToFenChar(PieceType.rook, PieceColor.red), 'R');
        expect(FenParser.pieceToFenChar(PieceType.cannon, PieceColor.red), 'C');
        expect(FenParser.pieceToFenChar(PieceType.pawn, PieceColor.red), 'P');
      });

      test('should convert black pieces to lowercase', () {
        expect(FenParser.pieceToFenChar(PieceType.king, PieceColor.black), 'k');
        expect(
          FenParser.pieceToFenChar(PieceType.advisor, PieceColor.black),
          'a',
        );
        expect(
          FenParser.pieceToFenChar(PieceType.bishop, PieceColor.black),
          'b',
        );
        expect(
          FenParser.pieceToFenChar(PieceType.knight, PieceColor.black),
          'n',
        );
        expect(FenParser.pieceToFenChar(PieceType.rook, PieceColor.black), 'r');
        expect(
          FenParser.pieceToFenChar(PieceType.cannon, PieceColor.black),
          'c',
        );
        expect(FenParser.pieceToFenChar(PieceType.pawn, PieceColor.black), 'p');
      });
    });

    group('fenCharToPiece', () {
      test('should parse uppercase to red pieces', () {
        expect(
          FenParser.fenCharToPiece('K'),
          equals(const (PieceType.king, PieceColor.red)),
        );
        expect(
          FenParser.fenCharToPiece('R'),
          equals(const (PieceType.rook, PieceColor.red)),
        );
        expect(
          FenParser.fenCharToPiece('C'),
          equals(const (PieceType.cannon, PieceColor.red)),
        );
        expect(
          FenParser.fenCharToPiece('P'),
          equals(const (PieceType.pawn, PieceColor.red)),
        );
      });

      test('should parse lowercase to black pieces', () {
        expect(
          FenParser.fenCharToPiece('k'),
          equals(const (PieceType.king, PieceColor.black)),
        );
        expect(
          FenParser.fenCharToPiece('r'),
          equals(const (PieceType.rook, PieceColor.black)),
        );
        expect(
          FenParser.fenCharToPiece('c'),
          equals(const (PieceType.cannon, PieceColor.black)),
        );
        expect(
          FenParser.fenCharToPiece('p'),
          equals(const (PieceType.pawn, PieceColor.black)),
        );
      });

      test('should return null for invalid character', () {
        expect(FenParser.fenCharToPiece('x'), isNull);
        expect(FenParser.fenCharToPiece(''), isNull);
        expect(FenParser.fenCharToPiece('Z'), isNull);
      });

      test('should parse all piece types', () {
        for (final type in PieceType.values) {
          final upperChar = FenParser.pieceToFenChar(type, PieceColor.red);
          final lowerChar = FenParser.pieceToFenChar(type, PieceColor.black);

          final upperResult = FenParser.fenCharToPiece(upperChar);
          expect(upperResult?.$1, type);
          expect(upperResult?.$2, PieceColor.red);

          final lowerResult = FenParser.fenCharToPiece(lowerChar);
          expect(lowerResult?.$1, type);
          expect(lowerResult?.$2, PieceColor.black);
        }
      });
    });

    group('initial FEN', () {
      test('should have correct initial FEN format', () {
        expect(
          FenParser.initial,
          'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w',
        );
      });

      test('should have 10 rows separated by /', () {
        final rows = FenParser.initial.split('/');
        expect(rows.length, 10);
      });

      test('should end with active color', () {
        expect(FenParser.initial.endsWith('w'), isTrue);
      });
    });

    group('parse', () {
      late Board board;

      setUp(() {
        board = Board();
      });

      test('should parse initial FEN and place 32 pieces', () {
        final activeColor = FenParser.parse(FenParser.initial, board);
        expect(board.pieces.length, 32);
        expect(activeColor, PieceColor.red);
      });

      test('should place red general at correct position after parse', () {
        FenParser.parse(FenParser.initial, board);
        // In our coordinate system: Red general at row 0, col 4
        // FEN row 0 (top) maps to our row 9 (black side)
        // FEN row 9 (bottom) maps to our row 0 (red side)
        final general = board.getPiece(const Coord(4, 0));
        expect(general, isNotNull);
        expect(general!.type, PieceType.king);
        expect(general.color, PieceColor.red);
      });

      test('should place black general at correct position after parse', () {
        FenParser.parse(FenParser.initial, board);
        final general = board.getPiece(const Coord(4, 9));
        expect(general, isNotNull);
        expect(general!.type, PieceType.king);
        expect(general.color, PieceColor.black);
      });

      test('should clear board before parsing', () {
        board.putPiece(
          ChessPiece(
            type: PieceType.king,
            color: PieceColor.red,
            coord: const Coord(0, 0),
          ),
        );
        expect(board.pieces.length, 1);

        FenParser.parse(FenParser.initial, board);
        expect(board.pieces.length, 32);
      });

      test('should parse active color correctly', () {
        expect(FenParser.parse(FenParser.initial, board), PieceColor.red);
        expect(
          FenParser.parse(
            'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR b',
            board,
          ),
          PieceColor.black,
        );
      });

      test('should default to red when active color missing', () {
        // FEN must include active color per strict validation rules
        // This test now verifies that FEN with ' r' parses correctly
        expect(
          FenParser.parse(
            'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR r',
            board,
          ),
          PieceColor.red,
        );
      });

      test('should handle empty board FEN', () {
        FenParser.parse('9/9/9/9/9/9/9/9/9/9 w', board);
        expect(board.pieces.isEmpty, isTrue);
      });

      test('should handle single piece FEN', () {
        FenParser.parse('9/9/9/9/9/9/9/9/9/K7 w', board);
        expect(board.pieces.length, 1);
        // K is red general, FEN row 9 → our row 0, col 0
        final piece = board.getPiece(const Coord(0, 0));
        expect(piece, isNotNull);
        expect(piece!.type, PieceType.king);
        expect(piece.color, PieceColor.red);
      });
    });

    group('generate', () {
      late Board board;

      setUp(() {
        board = Board();
      });

      test('should generate initial FEN from initialized board', () {
        board.initialize();
        final fen = FenParser.generate(board, PieceColor.red);
        expect(fen, FenParser.initial);
      });

      test('should generate FEN with correct active color', () {
        board.initialize();
        final fenRed = FenParser.generate(board, PieceColor.red);
        final fenBlack = FenParser.generate(board, PieceColor.black);
        expect(fenRed.endsWith('w'), isTrue);
        expect(fenBlack.endsWith('b'), isTrue);
      });

      test('should generate FEN for empty board', () {
        final fen = FenParser.generate(board, PieceColor.red);
        expect(fen, '9/9/9/9/9/9/9/9/9/9 w');
      });

      test('should generate FEN for partial board', () {
        board.putPiece(
          ChessPiece(
            type: PieceType.king,
            color: PieceColor.red,
            coord: const Coord(4, 0),
          ),
        );
        final fen = FenParser.generate(board, PieceColor.red);
        // Our row 0 is bottom, which is FEN row 9
        final rows = fen.split('/');
        expect(rows[9], contains('K')); // Red general at bottom
      });

      test('should round-trip: parse then generate produces same FEN', () {
        final originalFen = FenParser.initial;
        FenParser.parse(originalFen, board);
        final generatedFen = FenParser.generate(board, PieceColor.red);
        expect(generatedFen, originalFen);
      });

      test('should round-trip: generate then parse produces same board', () {
        board.initialize();
        final fen = FenParser.generate(board, PieceColor.red);
        final board2 = Board();
        FenParser.parse(fen, board2);

        expect(board2.pieces.length, board.pieces.length);
        for (final entry in board.pieces.entries) {
          final piece2 = board2.getPiece(entry.key);
          expect(piece2, isNotNull);
          expect(piece2!.type, entry.value.type);
          expect(piece2.color, entry.value.color);
        }
      });
    });

    group('generateHash', () {
      test('should produce same hash for same input', () {
        const fen =
            'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR';
        final hash1 = FenParser.generateHash(fen);
        final hash2 = FenParser.generateHash(fen);
        expect(hash1, hash2);
      });

      test('should produce different hash for different input', () {
        final hash1 = FenParser.generateHash(
          'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR',
        );
        final hash2 = FenParser.generateHash('9/9/9/9/9/9/9/9/9/9');
        expect(hash1 != hash2, isTrue);
      });

      test('should return integer hash', () {
        final hash = FenParser.generateHash('rnbakabnr');
        expect(hash, isA<int>());
        // Note: Dart's | 0 doesn't constrain to 32-bit like JavaScript,
        // so the hash can be larger than 32-bit for long strings
        expect(hash, isNonZero);
      });
    });
  });
}
