import 'package:flutter_test/flutter_test.dart';
import 'package:xqmagic/models/board.dart';
import 'package:xqmagic/models/move.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/coord.dart';
import 'package:xqmagic/utils/move_notation.dart';

void main() {
  group('MoveNotation.toICCS', () {
    test('should convert move from (4, 0) to (4, 1) correctly', () {
      final move = MoveRecord(
        from: const Coord(4, 0),
        to: const Coord(4, 1),
        capturedPiece: null,
        color: PieceColor.red,
      );
      // col=4 → file 'e', row=0 → rank 0
      final iccs = MoveNotation.toICCS(move);
      expect(iccs, 'e0e1');
    });

    test('should convert move from (4, 9) to (4, 8) correctly', () {
      final move = MoveRecord(
        from: const Coord(4, 9),
        to: const Coord(4, 8),
        capturedPiece: null,
        color: PieceColor.black,
      );
      // col=4 → file 'e', row=9 → rank 9
      final iccs = MoveNotation.toICCS(move);
      expect(iccs, 'e9e8');
    });

    test('should convert horizontal move correctly', () {
      final move = MoveRecord(
        from: const Coord(0, 0),
        to: const Coord(8, 0),
        capturedPiece: null,
        color: PieceColor.red,
      );
      // from: col=0 → 'a', row=0 → 0; to: col=8 → 'i', row=0 → 0
      final iccs = MoveNotation.toICCS(move);
      expect(iccs, 'a0i0');
    });

    test('should convert cannon move from (1, 2) to (1, 5)', () {
      final move = MoveRecord(
        from: const Coord(1, 2),
        to: const Coord(1, 5),
        capturedPiece: null,
        color: PieceColor.red,
      );
      // col=1 → 'b', row=2 → 2; col=1 → 'b', row=5 → 5
      final iccs = MoveNotation.toICCS(move);
      expect(iccs, 'b2b5');
    });
  });

  group('MoveNotation.fromICCS', () {
    test('should parse ICCS "e0e1" to coordinates', () {
      final (from, to) = MoveNotation.fromICCS('e0e1');
      expect(from.col, 4);
      expect(from.row, 0);
      expect(to.col, 4);
      expect(to.row, 1);
    });

    test('should parse ICCS "b2b5" to coordinates', () {
      final (from, to) = MoveNotation.fromICCS('b2b5');
      expect(from.col, 1);
      expect(from.row, 2);
      expect(to.col, 1);
      expect(to.row, 5);
    });

    test('should parse ICCS with row 9', () {
      final (from, to) = MoveNotation.fromICCS('e9e8');
      expect(from.col, 4);
      expect(from.row, 9);
      expect(to.col, 4);
      expect(to.row, 8);
    });

    test('should round-trip moves involving row 0', () {
      final move = MoveRecord(
        from: const Coord(4, 0),
        to: const Coord(4, 1),
        capturedPiece: null,
        color: PieceColor.red,
      );
      final iccs = MoveNotation.toICCS(move);
      expect(iccs.length, 4);
      final (from, to) = MoveNotation.fromICCS(iccs);
      expect(from, move.from);
      expect(to, move.to);
    });

    test('should round-trip moves involving row 9', () {
      final move = MoveRecord(
        from: const Coord(4, 9),
        to: const Coord(4, 8),
        capturedPiece: null,
        color: PieceColor.black,
      );
      final iccs = MoveNotation.toICCS(move);
      expect(iccs.length, 4);
      final (from, to) = MoveNotation.fromICCS(iccs);
      expect(from, move.from);
      expect(to, move.to);
    });

    test('should throw ArgumentError for invalid ICCS format', () {
      expect(() => MoveNotation.fromICCS('123'), throwsArgumentError);
      expect(() => MoveNotation.fromICCS('1234567'), throwsArgumentError);
      expect(() => MoveNotation.fromICCS('abcd'), throwsFormatException);
    });

    test('should round-trip: toICCS then fromICCS', () {
      final move = MoveRecord(
        from: const Coord(3, 5),
        to: const Coord(6, 2),
        capturedPiece: null,
        color: PieceColor.red,
      );
      final iccs = MoveNotation.toICCS(move);
      final (from, to) = MoveNotation.fromICCS(iccs);
      expect(from.col, 3);
      expect(from.row, 5);
      expect(to.col, 6);
      expect(to.row, 2);
    });
  });

  group('MoveNotation.toText', () {
    late Board board;

    setUp(() {
      board = Board();
      board.initialize();
    });

    test('should generate file number correctly for red', () {
      final move = MoveRecord(
        from: const Coord(4, 0),
        to: const Coord(5, 0),
        pieceType: PieceType.king,
        capturedPiece: null,
        color: PieceColor.red,
      );
      final notation = MoveNotation.toText(board.pieces, move);
      // col=4 → file 5 (五), col=5 → file 4 (四)
      expect(notation, contains('五'));
      expect(notation, contains('平'));
    });

    test('should generate file number correctly for black', () {
      final move = MoveRecord(
        from: const Coord(4, 9),
        to: const Coord(5, 9),
        pieceType: PieceType.king,
        capturedPiece: null,
        color: PieceColor.black,
      );
      final notation = MoveNotation.toText(board.pieces, move);
      expect(notation, contains('5'));
    });

    test('should use 进 for forward move', () {
      // Red king at (4,0) moving forward = row 增大
      final move = MoveRecord(
        from: const Coord(4, 0),
        to: const Coord(4, 1),
        pieceType: PieceType.king,
        capturedPiece: null,
        color: PieceColor.red,
      );
      final notation = MoveNotation.toText(board.pieces, move);
      expect(notation, contains('进'));
    });

    test('should use 退 for backward move', () {
      // Red king at (4,1) moving backward = row 减小
      final move = MoveRecord(
        from: const Coord(4, 1),
        to: const Coord(4, 0),
        pieceType: PieceType.king,
        capturedPiece: null,
        color: PieceColor.red,
      );
      final notation = MoveNotation.toText(board.pieces, move);
      expect(notation, contains('退'));
    });

    test('should use 平 for horizontal move', () {
      final move = MoveRecord(
        from: const Coord(4, 3),
        to: const Coord(5, 3),
        pieceType: PieceType.king,
        capturedPiece: null,
        color: PieceColor.red,
      );
      final notation = MoveNotation.toText(board.pieces, move);
      expect(notation, contains('平'));
    });
  });

  group('MoveQuality', () {
    test('should return empty mark for best move (diff >= -5)', () {
      expect(MoveQuality.getMark(0), '');
      expect(MoveQuality.getMark(-3), '');
      expect(MoveQuality.getMark(-5), ''); // boundary
    });

    test('should return ★ for good move (-30 <= diff < -5)', () {
      expect(MoveQuality.getMark(-6), '★');
      expect(MoveQuality.getMark(-30), '★'); // boundary
    });

    test('should return ✓ for ok move (-70 <= diff < -30)', () {
      expect(MoveQuality.getMark(-31), '✓');
      expect(MoveQuality.getMark(-70), '✓'); // boundary
    });

    test('should return ✗ for bad move (-100 <= diff < -70)', () {
      expect(MoveQuality.getMark(-71), '✗');
      expect(MoveQuality.getMark(-100), '✗'); // boundary
    });

    test('should return ✗✗ for very bad move (diff < -100)', () {
      expect(MoveQuality.getMark(-101), '✗✗');
      expect(MoveQuality.getMark(-200), '✗✗');
    });

    test('should return null color for best move (diff >= -5)', () {
      expect(MoveQuality.getColor(0), isNull);
      expect(MoveQuality.getColor(-5), isNull); // boundary
    });

    test('should return green color for good move (-30 <= diff < -5)', () {
      expect(MoveQuality.getColor(-6), 'green');
      expect(MoveQuality.getColor(-30), 'green'); // boundary
    });

    test('should return blue color for ok move (-70 <= diff < -30)', () {
      expect(MoveQuality.getColor(-31), 'blue');
      expect(MoveQuality.getColor(-70), 'blue'); // boundary
    });

    test('should return red color for bad move (diff < -70)', () {
      expect(MoveQuality.getColor(-71), 'red');
      expect(MoveQuality.getColor(-150), 'red');
    });
  });
}
