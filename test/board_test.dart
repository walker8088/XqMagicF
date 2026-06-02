import 'package:flutter_test/flutter_test.dart';
import 'package:xqmagic/models/board.dart';
import 'package:xqmagic/models/chess_piece.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/coord.dart';

void main() {
  group('Board', () {
    late Board board;

    setUp(() {
      board = Board();
    });

    test('should start empty', () {
      expect(board.pieces.isEmpty, isTrue);
    });

    group('putPiece', () {
      test('should place a piece on the board', () {
        final piece = ChessPiece(
          type: PieceType.king,
          color: PieceColor.red,
          coord: const Coord(4, 0),
        );
        board.putPiece(piece);
        expect(board.pieces.length, 1);
        expect(board.getPiece(const Coord(4, 0)), piece);
      });

      test('should overwrite existing piece at same position', () {
        final piece1 = ChessPiece(
          type: PieceType.king,
          color: PieceColor.red,
          coord: const Coord(4, 0),
        );
        final piece2 = ChessPiece(
          type: PieceType.advisor,
          color: PieceColor.red,
          coord: const Coord(4, 0),
        );
        board.putPiece(piece1);
        board.putPiece(piece2);
        expect(board.pieces.length, 1);
        expect(board.getPiece(const Coord(4, 0)), piece2);
      });

      test('should allow multiple pieces at different positions', () {
        final piece1 = ChessPiece(
          type: PieceType.king,
          color: PieceColor.red,
          coord: const Coord(4, 0),
        );
        final piece2 = ChessPiece(
          type: PieceType.rook,
          color: PieceColor.red,
          coord: const Coord(0, 0),
        );
        board.putPiece(piece1);
        board.putPiece(piece2);
        expect(board.pieces.length, 2);
        expect(board.getPiece(const Coord(4, 0)), piece1);
        expect(board.getPiece(const Coord(0, 0)), piece2);
      });
    });

    group('getPiece', () {
      test('should return null for empty position', () {
        expect(board.getPiece(const Coord(4, 4)), isNull);
      });

      test('should return piece at occupied position', () {
        final piece = ChessPiece(
          type: PieceType.cannon,
          color: PieceColor.red,
          coord: const Coord(1, 2),
        );
        board.putPiece(piece);
        expect(board.getPiece(const Coord(1, 2)), piece);
      });
    });

    group('movePiece', () {
      test('should move piece and return null when no capture', () {
        final piece = ChessPiece(
          type: PieceType.rook,
          color: PieceColor.red,
          coord: const Coord(0, 0),
        );
        board.putPiece(piece);

        final captured = board.movePiece(const Coord(0, 0), const Coord(0, 3));

        expect(captured, isNull);
        expect(board.getPiece(const Coord(0, 0)), isNull);
        final movedPiece = board.getPiece(const Coord(0, 3));
        expect(movedPiece, isNotNull);
        expect(movedPiece!.type, PieceType.rook);
        expect(movedPiece.coord, const Coord(0, 3));
      });

      test('should capture enemy piece and return it', () {
        final redChariot = ChessPiece(
          type: PieceType.rook,
          color: PieceColor.red,
          coord: const Coord(0, 0),
        );
        final blackSoldier = ChessPiece(
          type: PieceType.pawn,
          color: PieceColor.black,
          coord: const Coord(0, 3),
        );
        board.putPiece(redChariot);
        board.putPiece(blackSoldier);

        final captured = board.movePiece(const Coord(0, 0), const Coord(0, 3));

        expect(captured, blackSoldier);
        expect(board.pieces.length, 1);
        expect(board.getPiece(const Coord(0, 3))!.type, PieceType.rook);
      });

      test('should return null when no piece at from position', () {
        final result = board.movePiece(const Coord(0, 0), const Coord(0, 3));
        expect(result, isNull);
      });

      test('should update piece position after move', () {
        final piece = ChessPiece(
          type: PieceType.knight,
          color: PieceColor.red,
          coord: const Coord(1, 0),
        );
        board.putPiece(piece);

        board.movePiece(const Coord(1, 0), const Coord(2, 2));

        final movedPiece = board.getPiece(const Coord(2, 2));
        expect(movedPiece!.coord, const Coord(2, 2));
      });
    });

    group('removePiece', () {
      test('should remove piece and return it', () {
        final piece = ChessPiece(
          type: PieceType.cannon,
          color: PieceColor.black,
          coord: const Coord(1, 7),
        );
        board.putPiece(piece);

        final removed = board.removePiece(const Coord(1, 7));

        expect(removed, piece);
        expect(board.getPiece(const Coord(1, 7)), isNull);
        expect(board.pieces.isEmpty, isTrue);
      });

      test('should return null when position is empty', () {
        final result = board.removePiece(const Coord(5, 5));
        expect(result, isNull);
      });
    });

    group('clear', () {
      test('should remove all pieces', () {
        board.putPiece(
          ChessPiece(
            type: PieceType.king,
            color: PieceColor.red,
            coord: const Coord(4, 0),
          ),
        );
        board.putPiece(
          ChessPiece(
            type: PieceType.king,
            color: PieceColor.black,
            coord: const Coord(4, 9),
          ),
        );
        expect(board.pieces.length, 2);

        board.clear();

        expect(board.pieces.isEmpty, isTrue);
      });

      test('should be idempotent', () {
        board.clear();
        expect(board.pieces.isEmpty, isTrue);
        board.clear();
        expect(board.pieces.isEmpty, isTrue);
      });
    });

    group('initialize', () {
      test('should place 32 pieces on the board', () {
        board.initialize();
        expect(board.pieces.length, 32);
      });

      test('should place 16 red pieces', () {
        board.initialize();
        final redPieces = board.getPiecesOfColor(PieceColor.red);
        expect(redPieces.length, 16);
      });

      test('should place 16 black pieces', () {
        board.initialize();
        final blackPieces = board.getPiecesOfColor(PieceColor.black);
        expect(blackPieces.length, 16);
      });

      test('should place red king at (4, 0)', () {
        board.initialize();
        final king = board.getPiece(const Coord(4, 0));
        expect(king, isNotNull);
        expect(king!.type, PieceType.king);
        expect(king.color, PieceColor.red);
      });

      test('should place black king at (4, 9)', () {
        board.initialize();
        final king = board.getPiece(const Coord(4, 9));
        expect(king, isNotNull);
        expect(king!.type, PieceType.king);
        expect(king.color, PieceColor.black);
      });

      test('should place red rooks at (0, 0) and (8, 0)', () {
        board.initialize();
        expect(board.getPiece(const Coord(0, 0))!.type, PieceType.rook);
        expect(board.getPiece(const Coord(8, 0))!.type, PieceType.rook);
      });

      test('should place black rooks at (0, 9) and (8, 9)', () {
        board.initialize();
        expect(board.getPiece(const Coord(0, 9))!.type, PieceType.rook);
        expect(board.getPiece(const Coord(8, 9))!.type, PieceType.rook);
      });

      test('should place red cannons at (1, 2) and (7, 2)', () {
        board.initialize();
        expect(board.getPiece(const Coord(1, 2))!.type, PieceType.cannon);
        expect(board.getPiece(const Coord(7, 2))!.type, PieceType.cannon);
      });

      test('should place black cannons at (1, 7) and (7, 7)', () {
        board.initialize();
        expect(board.getPiece(const Coord(1, 7))!.type, PieceType.cannon);
        expect(board.getPiece(const Coord(7, 7))!.type, PieceType.cannon);
      });

      test('should place red pawns at correct positions', () {
        board.initialize();
        for (final col in [0, 2, 4, 6, 8]) {
          final piece = board.getPiece(Coord(col, 3));
          expect(piece, isNotNull);
          expect(piece!.type, PieceType.pawn);
          expect(piece.color, PieceColor.red);
        }
      });

      test('should place black pawns at correct positions', () {
        board.initialize();
        for (final col in [0, 2, 4, 6, 8]) {
          final piece = board.getPiece(Coord(col, 6));
          expect(piece, isNotNull);
          expect(piece!.type, PieceType.pawn);
          expect(piece.color, PieceColor.black);
        }
      });

      test('should place red advisors at (3, 0) and (5, 0)', () {
        board.initialize();
        expect(board.getPiece(const Coord(3, 0))!.type, PieceType.advisor);
        expect(board.getPiece(const Coord(5, 0))!.type, PieceType.advisor);
      });

      test('should place red bishops at (2, 0) and (6, 0)', () {
        board.initialize();
        expect(board.getPiece(const Coord(2, 0))!.type, PieceType.bishop);
        expect(board.getPiece(const Coord(6, 0))!.type, PieceType.bishop);
      });

      test('should place red knights at (1, 0) and (7, 0)', () {
        board.initialize();
        expect(board.getPiece(const Coord(1, 0))!.type, PieceType.knight);
        expect(board.getPiece(const Coord(7, 0))!.type, PieceType.knight);
      });
    });

    group('getPiecesOfColor', () {
      setUp(() {
        board.initialize();
      });

      test('should return all red pieces', () {
        final redPieces = board.getPiecesOfColor(PieceColor.red);
        expect(redPieces.length, 16);
        expect(redPieces.every((p) => p.color == PieceColor.red), isTrue);
      });

      test('should return all black pieces', () {
        final blackPieces = board.getPiecesOfColor(PieceColor.black);
        expect(blackPieces.length, 16);
        expect(blackPieces.every((p) => p.color == PieceColor.black), isTrue);
      });

      test('should return empty list when no pieces of that color', () {
        board.clear();
        final redPieces = board.getPiecesOfColor(PieceColor.red);
        expect(redPieces.isEmpty, isTrue);
      });
    });

    group('isValidPosition', () {
      test('should accept valid positions within board', () {
        expect(board.isValidPosition(const Coord(0, 0)), isTrue);
        expect(board.isValidPosition(const Coord(8, 9)), isTrue);
        expect(board.isValidPosition(const Coord(4, 4)), isTrue);
        expect(board.isValidPosition(const Coord(0, 5)), isTrue);
      });

      test('should reject column out of range', () {
        expect(board.isValidPosition(const Coord(-1, 5)), isFalse);
        expect(board.isValidPosition(const Coord(9, 5)), isFalse);
      });

      test('should reject row out of range', () {
        expect(board.isValidPosition(const Coord(4, -1)), isFalse);
        expect(board.isValidPosition(const Coord(4, 10)), isFalse);
      });

      test('should reject both out of range', () {
        expect(board.isValidPosition(const Coord(-1, -1)), isFalse);
        expect(board.isValidPosition(const Coord(10, 10)), isFalse);
      });
    });

    group('pieces (unmodifiable)', () {
      test('should return unmodifiable map', () {
        board.putPiece(
          ChessPiece(
            type: PieceType.king,
            color: PieceColor.red,
            coord: const Coord(4, 0),
          ),
        );

        expect(() => board.pieces.clear(), throwsUnsupportedError);
      });
    });

    // —— 越界坐标行为：getPiece / putPiece / movePiece / removePiece 表现
    // 不同，必须锁定。getPiece 走 isValidPosition 返回 null；
    // 后三者未走保护检查，会直接抛 RangeError（原代码设计选择）。———
    group('out-of-range coordinates', () {
      test('getPiece on out-of-range returns null', () {
        expect(board.getPiece(const Coord(-1, 0)), isNull);
        expect(board.getPiece(const Coord(9, 0)), isNull);
        expect(board.getPiece(const Coord(0, -1)), isNull);
        expect(board.getPiece(const Coord(0, 10)), isNull);
      });

      test('putPiece with out-of-range coord throws RangeError', () {
        expect(
          () => board.putPiece(
            const ChessPiece(
              type: PieceType.rook,
              color: PieceColor.red,
              coord: Coord(20, 20),
            ),
          ),
          throwsRangeError,
        );
      });

      test('movePiece with out-of-range from throws RangeError', () {
        board.putPiece(
          const ChessPiece(
            type: PieceType.rook,
            color: PieceColor.red,
            coord: Coord(0, 0),
          ),
        );
        expect(
          () => board.movePiece(const Coord(-1, 0), const Coord(0, 1)),
          throwsRangeError,
        );
      });

      test('movePiece with out-of-range to throws RangeError', () {
        board.putPiece(
          const ChessPiece(
            type: PieceType.rook,
            color: PieceColor.red,
            coord: Coord(0, 0),
          ),
        );
        expect(
          () => board.movePiece(const Coord(0, 0), const Coord(0, 100)),
          throwsRangeError,
        );
      });

      test('removePiece with out-of-range coord throws RangeError', () {
        expect(() => board.removePiece(const Coord(99, 99)), throwsRangeError);
      });
    });

    // —— pieceList getter 是公开 API 却从未被测过。——
    group('pieceList', () {
      test('should return all pieces on board', () {
        board.initialize();
        expect(board.pieceList.length, 32);
      });

      test('should return empty list on fresh board', () {
        expect(board.pieceList, isEmpty);
      });

      test('returned pieces should be in board positions', () {
        board.putPiece(
          const ChessPiece(
            type: PieceType.knight,
            color: PieceColor.red,
            coord: Coord(1, 0),
          ),
        );
        board.putPiece(
          const ChessPiece(
            type: PieceType.bishop,
            color: PieceColor.black,
            coord: Coord(2, 9),
          ),
        );
        final positions = board.pieceList.map((p) => p.coord).toSet();
        expect(positions, contains(const Coord(1, 0)));
        expect(positions, contains(const Coord(2, 9)));
        expect(board.pieceList.length, 2);
      });
    });
  });
}
