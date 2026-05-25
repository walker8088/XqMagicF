import 'package:flutter_test/flutter_test.dart';
import 'package:xqmagic/models/chess_piece.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/coord.dart';

void main() {
  group('ChessPiece', () {
    test('should create piece with all fields', () {
      const piece = ChessPiece(
        type: PieceType.king,
        color: PieceColor.red,
        coord: Coord(4, 0),
      );
      expect(piece.type, PieceType.king);
      expect(piece.color, PieceColor.red);
      expect(piece.coord.col, 4);
      expect(piece.coord.row, 0);
    });

    test('should support const constructor', () {
      const piece = ChessPiece(
        type: PieceType.rook,
        color: PieceColor.black,
        coord: Coord(0, 9),
      );
      expect(piece.type, PieceType.rook);
      expect(piece.color, PieceColor.black);
    });

    group('equality', () {
      test('should be equal when all fields match', () {
        const p1 = ChessPiece(
          type: PieceType.knight,
          color: PieceColor.red,
          coord: Coord(1, 0),
        );
        const p2 = ChessPiece(
          type: PieceType.knight,
          color: PieceColor.red,
          coord: Coord(1, 0),
        );
        expect(p1, p2);
      });

      test('should not be equal when type differs', () {
        const p1 = ChessPiece(
          type: PieceType.knight,
          color: PieceColor.red,
          coord: Coord(1, 0),
        );
        const p2 = ChessPiece(
          type: PieceType.rook,
          color: PieceColor.red,
          coord: Coord(1, 0),
        );
        expect(p1 != p2, isTrue);
      });

      test('should not be equal when color differs', () {
        const p1 = ChessPiece(
          type: PieceType.king,
          color: PieceColor.red,
          coord: Coord(4, 0),
        );
        const p2 = ChessPiece(
          type: PieceType.king,
          color: PieceColor.black,
          coord: Coord(4, 0),
        );
        expect(p1 != p2, isTrue);
      });

      test('should not be equal when coord differs', () {
        const p1 = ChessPiece(
          type: PieceType.pawn,
          color: PieceColor.red,
          coord: Coord(0, 3),
        );
        const p2 = ChessPiece(
          type: PieceType.pawn,
          color: PieceColor.red,
          coord: Coord(2, 3),
        );
        expect(p1 != p2, isTrue);
      });

      test('should not be equal to non-ChessPiece object', () {
        const piece = ChessPiece(
          type: PieceType.cannon,
          color: PieceColor.red,
          coord: Coord(1, 2),
        );
        expect(piece == 'not a piece', isFalse);
      });

      test('should use identical for same instance', () {
        const piece = ChessPiece(
          type: PieceType.king,
          color: PieceColor.red,
          coord: Coord(4, 0),
        );
        // ignore: unnecessary_statements
        expect(piece == piece, isTrue);
      });
    });

    group('hashCode', () {
      test('should produce same hashCode for equal pieces', () {
        const p1 = ChessPiece(
          type: PieceType.advisor,
          color: PieceColor.black,
          coord: Coord(3, 9),
        );
        const p2 = ChessPiece(
          type: PieceType.advisor,
          color: PieceColor.black,
          coord: Coord(3, 9),
        );
        expect(p1.hashCode, p2.hashCode);
      });

      test('should produce different hashCode for different pieces', () {
        const p1 = ChessPiece(
          type: PieceType.king,
          color: PieceColor.red,
          coord: Coord(4, 0),
        );
        const p2 = ChessPiece(
          type: PieceType.advisor,
          color: PieceColor.red,
          coord: Coord(3, 0),
        );
        expect(p1.hashCode != p2.hashCode, isTrue);
      });
    });

    group('copyWith', () {
      const original = ChessPiece(
        type: PieceType.pawn,
        color: PieceColor.red,
        coord: Coord(0, 3),
      );

      test('should return same piece when no args', () {
        final copied = original.copyWith();
        expect(copied.type, PieceType.pawn);
        expect(copied.color, PieceColor.red);
        expect(copied.coord.col, 0);
        expect(copied.coord.row, 3);
      });

      test('should update type when provided', () {
        final copied = original.copyWith(type: PieceType.rook);
        expect(copied.type, PieceType.rook);
        expect(copied.color, PieceColor.red);
        expect(copied.coord, original.coord);
      });

      test('should update color when provided', () {
        final copied = original.copyWith(color: PieceColor.black);
        expect(copied.type, PieceType.pawn);
        expect(copied.color, PieceColor.black);
        expect(copied.coord, original.coord);
      });

      test('should update coord when provided', () {
        final copied = original.copyWith(coord: const Coord(0, 4));
        expect(copied.type, PieceType.pawn);
        expect(copied.color, PieceColor.red);
        expect(copied.coord.col, 0);
        expect(copied.coord.row, 4);
      });

      test('should update all fields when provided', () {
        final copied = original.copyWith(
          type: PieceType.rook,
          color: PieceColor.black,
          coord: const Coord(0, 9),
        );
        expect(copied.type, PieceType.rook);
        expect(copied.color, PieceColor.black);
        expect(copied.coord.col, 0);
        expect(copied.coord.row, 9);
      });
    });

    group('all piece types', () {
      test('should create all 7 piece types for red', () {
        const pieces = [
          ChessPiece(
            type: PieceType.king,
            color: PieceColor.red,
            coord: Coord(4, 0),
          ),
          ChessPiece(
            type: PieceType.advisor,
            color: PieceColor.red,
            coord: Coord(3, 0),
          ),
          ChessPiece(
            type: PieceType.bishop,
            color: PieceColor.red,
            coord: Coord(2, 0),
          ),
          ChessPiece(
            type: PieceType.knight,
            color: PieceColor.red,
            coord: Coord(1, 0),
          ),
          ChessPiece(
            type: PieceType.rook,
            color: PieceColor.red,
            coord: Coord(0, 0),
          ),
          ChessPiece(
            type: PieceType.cannon,
            color: PieceColor.red,
            coord: Coord(1, 2),
          ),
          ChessPiece(
            type: PieceType.pawn,
            color: PieceColor.red,
            coord: Coord(0, 3),
          ),
        ];
        for (final piece in pieces) {
          expect(piece.color, PieceColor.red);
        }
      });

      test('should create all 7 piece types for black', () {
        const pieces = [
          ChessPiece(
            type: PieceType.king,
            color: PieceColor.black,
            coord: Coord(4, 9),
          ),
          ChessPiece(
            type: PieceType.advisor,
            color: PieceColor.black,
            coord: Coord(3, 9),
          ),
          ChessPiece(
            type: PieceType.bishop,
            color: PieceColor.black,
            coord: Coord(2, 9),
          ),
          ChessPiece(
            type: PieceType.knight,
            color: PieceColor.black,
            coord: Coord(1, 9),
          ),
          ChessPiece(
            type: PieceType.rook,
            color: PieceColor.black,
            coord: Coord(0, 9),
          ),
          ChessPiece(
            type: PieceType.cannon,
            color: PieceColor.black,
            coord: Coord(1, 7),
          ),
          ChessPiece(
            type: PieceType.pawn,
            color: PieceColor.black,
            coord: Coord(0, 6),
          ),
        ];
        for (final piece in pieces) {
          expect(piece.color, PieceColor.black);
        }
      });
    });
  });

  group('PieceType displayName', () {
    test('should return correct red names', () {
      expect(PieceType.king.displayName(PieceColor.red), '帅');
      expect(PieceType.advisor.displayName(PieceColor.red), '仕');
      expect(PieceType.bishop.displayName(PieceColor.red), '相');
      expect(PieceType.knight.displayName(PieceColor.red), '傌');
      expect(PieceType.rook.displayName(PieceColor.red), '俥');
      expect(PieceType.cannon.displayName(PieceColor.red), '炮');
      expect(PieceType.pawn.displayName(PieceColor.red), '兵');
    });

    test('should return correct black names', () {
      expect(PieceType.king.displayName(PieceColor.black), '将');
      expect(PieceType.advisor.displayName(PieceColor.black), '士');
      expect(PieceType.bishop.displayName(PieceColor.black), '象');
      expect(PieceType.knight.displayName(PieceColor.black), '馬');
      expect(PieceType.rook.displayName(PieceColor.black), '車');
      expect(PieceType.cannon.displayName(PieceColor.black), '砲');
      expect(PieceType.pawn.displayName(PieceColor.black), '卒');
    });
  });

  group('PieceColor', () {
    test('should have two values', () {
      expect(PieceColor.values.length, 2);
      expect(PieceColor.values[0], PieceColor.red);
      expect(PieceColor.values[1], PieceColor.black);
    });

    test('should use index 0 for red', () {
      expect(PieceColor.red.index, 0);
    });

    test('should use index 1 for black', () {
      expect(PieceColor.black.index, 1);
    });
  });

  group('PieceType', () {
    test('should have 7 values', () {
      expect(PieceType.values.length, 7);
    });

    test('should have correct order', () {
      expect(PieceType.values[0], PieceType.king);
      expect(PieceType.values[1], PieceType.advisor);
      expect(PieceType.values[2], PieceType.bishop);
      expect(PieceType.values[3], PieceType.knight);
      expect(PieceType.values[4], PieceType.rook);
      expect(PieceType.values[5], PieceType.cannon);
      expect(PieceType.values[6], PieceType.pawn);
    });
  });
}
