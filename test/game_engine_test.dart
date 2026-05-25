import 'package:flutter_test/flutter_test.dart';
import 'package:xqmagic/game/game_engine.dart';
import 'package:xqmagic/models/board.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/coord.dart';
import 'package:xqmagic/utils/fen.dart';

void main() {
  group('GameEngine', () {
    group('Constructor & FEN parsing', () {
      test('should parse initial FEN correctly', () {
        const fen = FenParser.initial;
        final engine = GameEngine(fen);

        expect(engine.currentTurn, PieceColor.red);
        expect(engine.board.pieces.length, 32);
      });

      test('should parse FEN with black to move', () {
        const fen =
            'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR b';
        final engine = GameEngine(fen);
        expect(engine.currentTurn, PieceColor.black);
      });

      test('should parse custom FEN with fewer pieces', () {
        // Simple endgame: red general + black general only
        const fen = '4k4/9/9/9/9/9/9/9/9/4K4 r';
        final engine = GameEngine(fen);

        expect(engine.board.pieces.length, 2);
        expect(engine.currentTurn, PieceColor.red);
      });

      test('FEN round-trip: generate → parse → generate should match', () {
        final board = Board();
        board.initialize();

        final fen1 = FenParser.generate(board, PieceColor.red);
        final engine = GameEngine(fen1);
        final fen2 = engine.currentFen;

        expect(fen1, fen2);
      });

      test('should place pieces at correct coordinates from FEN', () {
        const fen = FenParser.initial;
        final engine = GameEngine(fen);

        // Red general at (4, 0)
        final redGeneral = engine.board.getPiece(const Coord(4, 0));
        expect(redGeneral, isNotNull);
        expect(redGeneral!.type, PieceType.king);
        expect(redGeneral.color, PieceColor.red);

        // Black general at (4, 9)
        final blackGeneral = engine.board.getPiece(const Coord(4, 9));
        expect(blackGeneral, isNotNull);
        expect(blackGeneral!.type, PieceType.king);
        expect(blackGeneral.color, PieceColor.black);

        // Red chariot at (0, 0)
        final redChariot = engine.board.getPiece(const Coord(0, 0));
        expect(redChariot, isNotNull);
        expect(redChariot!.type, PieceType.rook);
        expect(redChariot.color, PieceColor.red);
      });
    });

    group('getLegalMoves', () {
      test('initial position: red chariot at (0,0) can move forward', () {
        final engine = GameEngine(FenParser.initial);
        final moves = engine.getLegalMoves(const Coord(0, 0));

        expect(moves, isNotEmpty);
        // Chariot can move up file 0: (0,1), (0,2) are empty
        // (0,3) has own soldier, so can't go further
        // Can't move right: (1,0) has own horse
        expect(moves.any((m) => m.to == const Coord(0, 1)), isTrue);
        expect(moves.any((m) => m.to == const Coord(0, 2)), isTrue);
      });

      test('initial position: red cannon at (1,2) has moves along file', () {
        final engine = GameEngine(FenParser.initial);
        final moves = engine.getLegalMoves(const Coord(1, 2));

        // Cannon can move down to (1,1) — path clear
        // Can't move left: (0,2) has own elephant
        // Can't move right: (2,2) has own horse
        // Can move up: (1,3) is empty (soldiers at cols 0,2,4,6,8)
        expect(moves, isNotEmpty);
        expect(moves.any((m) => m.to == const Coord(1, 1)), isTrue);
        expect(moves.any((m) => m.to == const Coord(1, 3)), isTrue);
      });

      test('initial position: red horse at (1,0) has moves', () {
        final engine = GameEngine(FenParser.initial);
        final moves = engine.getLegalMoves(const Coord(1, 0));

        // Horse at (1,0) with leg at (0,1) can reach (0,2) — leg empty ✓
        // Horse at (1,0) with leg at (2,0) can reach... no, leg for (1,0)→(3,1) is (2,0) which has elephant. Blocked.
        // Horse at (1,0) with leg at (1,1) can reach (2,2) — leg empty ✓
        // Horse at (1,0) with leg at (0,1) can reach (0,2) — leg empty ✓
        expect(moves, isNotEmpty);
        expect(moves.any((m) => m.to == const Coord(0, 2)), isTrue);
        expect(moves.any((m) => m.to == const Coord(2, 2)), isTrue);
      });

      test('should return empty for opponent piece', () {
        final engine = GameEngine(FenParser.initial);
        // It's red's turn, getLegalMoves only returns moves for red
        final moves = engine.getLegalMoves(const Coord(0, 9));
        expect(moves, isEmpty);
      });

      test('should return empty for empty square', () {
        final engine = GameEngine(FenParser.initial);
        final moves = engine.getLegalMoves(const Coord(4, 4));
        expect(moves, isEmpty);
      });

      test('free chariot has many legal moves', () {
        // Place a red chariot in open space: (4, 4)
        const fen = '4k4/9/9/9/9/4R4/9/9/9/4K4 r';
        final engine = GameEngine(fen);
        final moves = engine.getLegalMoves(const Coord(4, 4));

        expect(moves.length, greaterThan(10));
        // Can move in all four directions
        expect(moves.any((m) => m.to.col == 4 && m.to.row > 4), isTrue);
        expect(moves.any((m) => m.to.col == 4 && m.to.row < 4), isTrue);
        expect(moves.any((m) => m.to.row == 4 && m.to.col > 4), isTrue);
        expect(moves.any((m) => m.to.row == 4 && m.to.col < 4), isTrue);
      });

      test('cannon can capture with exactly one mount', () {
        // Red cannon at (4,3), red soldier (mount) at (4,4),
        // black chariot (target) at (4,5)
        // FEN: row9=4k4, row5=4r4(r at 4,5), row4=4P4(P at 4,4), row3=4C4(C at 4,3), row0=4K4
        const fen = '4k4/9/9/9/4r4/4P4/4C4/9/9/4K4 b';
        final engine = GameEngine(fen);
        final redMoves = engine.getAllLegalMoves(PieceColor.red);

        // Cannon at (4,3) can capture chariot at (4,5) with mount at (4,4)
        expect(
          redMoves.any(
            (m) => m.from == const Coord(4, 3) && m.to == const Coord(4, 5),
          ),
          isTrue,
        );
      });
    });

    group('getAllLegalMoves', () {
      test('initial position: red has legal moves', () {
        final engine = GameEngine(FenParser.initial);
        final moves = engine.getAllLegalMoves(PieceColor.red);

        expect(moves, isNotEmpty);
        expect(moves.length, greaterThanOrEqualTo(5));
      });

      test('initial position: black has legal moves', () {
        const fen =
            'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR b';
        final engine = GameEngine(fen);
        final moves = engine.getAllLegalMoves(PieceColor.black);
        expect(moves, isNotEmpty);
      });

      test('minimal position: only generals, each has 2 moves (forward blocked by 飞将)', () {
        const fen = '4k4/9/9/9/9/9/9/9/9/4K4 r';
        final engine = GameEngine(fen);

        // Red general at (4,0): can move to (3,0), (5,0)
        // (4,1) is illegal: flying generals rule — would leave king in check
        final redMoves = engine.getAllLegalMoves(PieceColor.red);
        expect(redMoves.length, 2);

        // Black general at (4,9): can move to (3,9), (5,9)
        // (4,8) is illegal: same reason
        final blackMoves = engine.getAllLegalMoves(PieceColor.black);
        expect(blackMoves.length, 2);
      });
    });

    group('executeMove', () {
      test('valid move succeeds and switches turn', () {
        final engine = GameEngine(FenParser.initial);

        final result = engine.executeMove(const Coord(0, 0), const Coord(0, 1));

        expect(result, isTrue);
        expect(engine.currentTurn, PieceColor.black);

        final piece = engine.board.getPiece(const Coord(0, 1));
        expect(piece, isNotNull);
        expect(piece!.type, PieceType.rook);
        expect(piece.color, PieceColor.red);
        expect(engine.board.getPiece(const Coord(0, 0)), isNull);
      });

      test('valid capture succeeds', () {
        // Red chariot at (0,0) captures black soldier at (0,6)
        // Clear path: no pieces between (0,0) and (0,6)
        // FEN: row9=4k4, row3=p8(p at 0,6), row0=R6K1(R at 0,0, K at 7,0)
        const fenCapture = '4k4/9/9/p8/9/9/9/9/9/R6K1 r';
        final engine = GameEngine(fenCapture);

        final result = engine.executeMove(const Coord(0, 0), const Coord(0, 6));

        expect(result, isTrue);
        final piece = engine.board.getPiece(const Coord(0, 6));
        expect(piece, isNotNull);
        expect(piece!.type, PieceType.rook);
        expect(piece.color, PieceColor.red);
      });

      test('invalid move pattern fails', () {
        final engine = GameEngine(FenParser.initial);

        // Chariot cannot move diagonally
        final result = engine.executeMove(const Coord(0, 0), const Coord(1, 1));
        expect(result, isFalse);
        expect(engine.board.getPiece(const Coord(0, 0)), isNotNull);
      });

      test('cannot move opponent piece', () {
        final engine = GameEngine(FenParser.initial);

        // It's red's turn, try to move black's chariot
        final result = engine.executeMove(const Coord(0, 9), const Coord(0, 8));
        expect(result, isFalse);
      });

      test('cannot move from empty square', () {
        final engine = GameEngine(FenParser.initial);

        final result = engine.executeMove(const Coord(4, 4), const Coord(4, 5));
        expect(result, isFalse);
      });

      test('turn alternates correctly through multiple moves', () {
        final engine = GameEngine(FenParser.initial);

        expect(engine.currentTurn, PieceColor.red);
        engine.executeMove(const Coord(0, 0), const Coord(0, 1));
        expect(engine.currentTurn, PieceColor.black);
        engine.executeMove(const Coord(0, 9), const Coord(0, 8));
        expect(engine.currentTurn, PieceColor.red);
        engine.executeMove(const Coord(0, 1), const Coord(0, 2));
        expect(engine.currentTurn, PieceColor.black);
      });
    });

    group('isInCheck', () {
      test('initial position: neither side is in check', () {
        final engine = GameEngine(FenParser.initial);

        expect(engine.isInCheck(PieceColor.red), isFalse);
        expect(engine.isInCheck(PieceColor.black), isFalse);
      });

      test('red general attacked by black chariot (clear path)', () {
        // Black chariot at (4,3) attacking red general at (4,0)
        // FEN: row9=4k4, row3=4r4, row0=4K4
        const fen = '4k4/9/9/9/9/9/4r4/9/9/4K4 b';
        final engine = GameEngine(fen);

        expect(engine.isInCheck(PieceColor.red), isTrue);
        expect(engine.isInCheck(PieceColor.black), isFalse);
      });

      test('black general attacked by red chariot', () {
        // Red chariot at (4,7) attacking black general at (4,9)
        // FEN: row9=4k4, row2=4R4, row0=4K4
        const fen = '4k4/9/4R4/9/9/9/9/9/9/4K4 r';
        final engine = GameEngine(fen);

        expect(engine.isInCheck(PieceColor.black), isTrue);
        expect(engine.isInCheck(PieceColor.red), isFalse);
      });

      test('red general attacked by black cannon (with mount)', () {
        // Black cannon at (4,2), red soldier (mount) at (4,1),
        // red general at (4,0)
        // FEN: row9=4k4, row7=4c4(c at col4,our row2), row8=4P4(P at col4,our row1), row0=4K4
        const fen = '4k4/9/9/9/9/9/9/4c4/4P4/4K4 r';
        final engine = GameEngine(fen);

        expect(engine.isInCheck(PieceColor.red), isTrue);
      });

      test('red general attacked by black horse', () {
        // Black horse at (3,2) attacking red general at (4,0)
        // Horse move: (3,2)→(4,0), leg at (3,1) — empty
        // FEN: row9=4k4, row7=3n5(n at col3,our row2), row0=4K4
        const fen = '4k4/9/9/9/9/9/9/3n5/9/4K4 r';
        final engine = GameEngine(fen);

        expect(engine.isInCheck(PieceColor.red), isTrue);
      });

      test('attack blocked by intervening piece', () {
        // Black chariot at (4,5), red soldier (blocker, can't attack) at (4,1),
        // red general at (4,0). Red soldier hasn't crossed river (row 1 < 4),
        // so it can only move forward, not backward to attack the general.
        // FEN: row9=4k4, row5=4r4(r at 4,5), row1=4P4(P at 4,1), row0=4K4
        const fen = '4k4/9/9/9/4r4/9/9/9/4P4/4K4 r';
        final engine = GameEngine(fen);

        expect(engine.isInCheck(PieceColor.red), isFalse);
      });

      test('red general attacked by black soldier after crossing river', () {
        // Black soldier at (4,1) — crossed river (row<5 for black),
        // can move in any direction including to (4,0)
        const fen = '4k4/9/9/9/9/9/9/9/4p4/4K4 r';
        final engine = GameEngine(fen);

        expect(engine.isInCheck(PieceColor.red), isTrue);
      });

      test('cannon check fails without a mount', () {
        // Black cannon at (4,1), red general at (4,0)
        // No piece between them — cannon cannot attack
        const fen = '4k4/9/9/9/9/9/9/9/4c4/4K4 r';
        final engine = GameEngine(fen);

        expect(engine.isInCheck(PieceColor.red), isFalse);
      });
    });

    group('isCheckmate', () {
      test('initial position: not checkmate', () {
        final engine = GameEngine(FenParser.initial);
        expect(engine.isCheckmate(PieceColor.red), isFalse);
        expect(engine.isCheckmate(PieceColor.black), isFalse);
      });

      test('in check but has legal moves → not checkmate', () {
        // Black chariot at (4,3) attacking red general at (4,0)
        // General can escape to (3,0) or (5,0)
        const fen = '4k4/9/9/9/9/9/4r4/9/9/4K4 b';
        final engine = GameEngine(fen);

        expect(engine.isInCheck(PieceColor.red), isTrue);
        expect(engine.isCheckmate(PieceColor.red), isFalse);
      });

      test('not in check → not checkmate regardless of moves', () {
        final engine = GameEngine(FenParser.initial);
        expect(engine.isCheckmate(PieceColor.red), isFalse);
      });
    });

    group('isStalemate', () {
      test('initial position: not stalemate', () {
        final engine = GameEngine(FenParser.initial);
        expect(engine.isStalemate(PieceColor.red), isFalse);
        expect(engine.isStalemate(PieceColor.black), isFalse);
      });

      test('in check → not stalemate', () {
        const fen = '4k4/9/9/9/9/9/4r4/9/9/4K4 r';
        final engine = GameEngine(fen);

        expect(engine.isInCheck(PieceColor.red), isTrue);
        expect(engine.isStalemate(PieceColor.red), isFalse);
      });

      test('not in check with legal moves → not stalemate', () {
        final engine = GameEngine(FenParser.initial);
        expect(engine.isStalemate(PieceColor.red), isFalse);
      });
    });

    group('currentFen', () {
      test('returns valid FEN after moves', () {
        final engine = GameEngine(FenParser.initial);

        final fenBefore = engine.currentFen;
        engine.executeMove(const Coord(0, 0), const Coord(0, 1));
        final fenAfter = engine.currentFen;

        expect(fenBefore, isNot(fenAfter));

        // Parse the new FEN and verify the move was applied
        final board2 = Board();
        final activeColor = FenParser.parse(fenAfter, board2);
        expect(activeColor, PieceColor.black);
        expect(board2.getPiece(const Coord(0, 0)), isNull);
        expect(board2.getPiece(const Coord(0, 1))!.type, PieceType.rook);
      });

      test('FEN reflects piece captures', () {
        // Chariot at (0,0) captures soldier at (0,6) — clear path
        const fenCapture = '4k4/9/9/p8/9/9/9/9/9/R6K1 r';
        final engine = GameEngine(fenCapture);
        // FEN row 3 = our row 6: p8 → p at (0,6)
        // Our row 0: R6K1 → R at (0,0), K at (7,0)
        // Path from (0,0) to (0,6): (0,1)-(0,5) all empty. ✓
        engine.executeMove(const Coord(0, 0), const Coord(0, 6));

        final resultFen = engine.currentFen;
        final board2 = Board();
        FenParser.parse(resultFen, board2);

        expect(board2.getPiece(const Coord(0, 6))!.type, PieceType.rook);
        expect(board2.getPiece(const Coord(0, 6))!.color, PieceColor.red);
        expect(board2.pieces.length, 3); // k, R, K
      });
    });
  });
}
