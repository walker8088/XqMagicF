import 'package:flutter_test/flutter_test.dart';
import 'package:xqmagic/game/board_edit_controller.dart';
import 'package:xqmagic/models/board.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/coord.dart';

void main() {
  group('BoardEditController', () {
    late Board board;
    late BoardEditController controller;

    setUp(() {
      board = Board();
      board.initialize();
      controller = BoardEditController();
    });

    group('初始状态', () {
      test('默认 pieceType/Color/SideToMove/placing', () {
        expect(controller.pieceType, PieceType.pawn);
        expect(controller.pieceColor, PieceColor.red);
        expect(controller.sideToMove, PieceColor.red);
        expect(controller.placing, isTrue);
      });
    });

    group('状态 setter', () {
      test('setPieceType 不影响其他字段', () {
        controller.setPieceType(PieceType.rook);
        expect(controller.pieceType, PieceType.rook);
        expect(controller.pieceColor, PieceColor.red); // 不变
      });

      test('setPlacing 切换放置/删除模式', () {
        controller.setPlacing(false);
        expect(controller.placing, isFalse);
        controller.setPlacing(true);
        expect(controller.placing, isTrue);
      });
    });

    group('tap (放置/删除)', () {
      test('放置模式：在空格放一颗红兵', () {
        controller.setPieceType(PieceType.pawn);
        controller.setPieceColor(PieceColor.red);
        // 找一个空格——红方底线 (0,0) 是车，但 (4,4) 应是空（中间楚河）
        // 用 (3,5) 确认是空格
        const pos = Coord(4, 5);
        expect(board.getPiece(pos), isNull);

        controller.tap(board, pos);
        final piece = board.getPiece(pos);
        expect(piece, isNotNull);
        expect(piece!.type, PieceType.pawn);
        expect(piece.color, PieceColor.red);
      });

      test('放置模式：覆盖已存在的棋子', () {
        const pos = Coord(0, 0); // 红方底线角——车
        expect(board.getPiece(pos)?.type, PieceType.rook);

        controller.setPieceType(PieceType.cannon);
        controller.tap(board, pos);

        final piece = board.getPiece(pos);
        expect(piece?.type, PieceType.cannon);
        expect(piece?.color, PieceColor.red);
      });

      test('删除模式：移除棋子', () {
        const pos = Coord(0, 0);
        expect(board.getPiece(pos), isNotNull);

        controller.setPlacing(false);
        controller.tap(board, pos);

        expect(board.getPiece(pos), isNull);
      });

      test('删除模式：空格无操作', () {
        controller.setPlacing(false);
        const emptyPos = Coord(4, 5);
        expect(board.getPiece(emptyPos), isNull);

        // 不应抛错
        controller.tap(board, emptyPos);
        expect(board.getPiece(emptyPos), isNull);
      });

      test('越界坐标静默忽略（依赖 Board.isValidPosition）', () {
        const outOfRange = Coord(-1, 0);
        // 不应抛错
        controller.tap(board, outOfRange);
      });
    });

    group('clearBoard / initStandard', () {
      test('clearBoard 清空所有棋子', () {
        expect(board.pieces.isNotEmpty, isTrue);
        controller.clearBoard(board);
        expect(board.pieces, isEmpty);
      });

      test('initStandard 重置为标准开局 + 红方走子', () {
        controller.clearBoard(board);
        controller.setSideToMove(PieceColor.black); // 先污染 sideToMove
        controller.initStandard(board);
        expect(board.pieces.isNotEmpty, isTrue);
        expect(controller.sideToMove, PieceColor.red); // 重置回红方
      });
    });

    group('toFen', () {
      test('生成含走子方的完整 FEN', () {
        controller.setSideToMove(PieceColor.black);
        final fen = controller.toFen(board);
        // FEN 标准：黑方走子用 ' b'
        expect(fen, endsWith(' b'));
      });

      test('清除棋盘后 FEN 表示空格', () {
        controller.clearBoard(board);
        final fen = controller.toFen(board);
        // 10 行空（9 9）+ FEN 走子方 w
        expect(fen, startsWith('9/9/9/9/9/9/9/9/9/9 '));
      });
    });

    group('reset', () {
      test('重置所有状态到默认', () {
        controller.setPieceType(PieceType.cannon);
        controller.setPieceColor(PieceColor.black);
        controller.setSideToMove(PieceColor.black);
        controller.setPlacing(false);

        controller.reset();

        expect(controller.pieceType, PieceType.pawn);
        expect(controller.pieceColor, PieceColor.red);
        expect(controller.sideToMove, PieceColor.red);
        expect(controller.placing, isTrue);
      });

      test('reset 不影响棋盘内容', () {
        expect(board.pieces.isNotEmpty, isTrue);
        controller.reset();
        expect(board.pieces.isNotEmpty, isTrue);
      });
    });

    group('board 引用独立性', () {
      test('换 board 后操作指向新 board', () {
        // 旧 board (4,0) 是红帅——在它上面覆盖一颗黑 king，验证修改旧 board
        controller.setPieceType(PieceType.cannon);
        controller.setPieceColor(PieceColor.black);
        controller.tap(board, const Coord(4, 0));
        expect(board.getPiece(const Coord(4, 0))?.color, PieceColor.black);

        // 新 board：完全独立
        final newBoard = Board();
        controller.setPieceType(PieceType.king);
        controller.setPieceColor(PieceColor.red);
        controller.tap(newBoard, const Coord(4, 4));

        // 旧 board (4,4) 应为空（不因 newBoard 操作被污染）
        expect(board.getPiece(const Coord(4, 4)), isNull);
        // 新 board (4,4) 应有红帅
        expect(newBoard.getPiece(const Coord(4, 4))?.type, PieceType.king);
      });

      test('模拟 GameController.reset() 重建 board 的场景', () {
        // 1) 用户在原 board 的空位 (3,5) 放一颗红兵
        controller.tap(board, const Coord(3, 5));
        expect(board.getPiece(const Coord(3, 5))?.type, PieceType.pawn);

        // 2) GameController.reset() 重建 board（模拟：丢弃旧 board，用新实例）
        final rebuiltBoard = Board();
        rebuiltBoard.initialize();
        // (3,5) 在原 board 上是用户放的兵，在新 board 上仍是空
        expect(rebuiltBoard.getPiece(const Coord(3, 5)), isNull);

        // 3) 再次 editTap：必须作用在新 board 上，不能写到旧 board
        controller.setPieceType(PieceType.knight);
        controller.tap(rebuiltBoard, const Coord(3, 5));

        // 新 board (3,5) 是红马
        expect(
          rebuiltBoard.getPiece(const Coord(3, 5))?.type,
          PieceType.knight,
        );
        // 旧 board (3,5) 仍是红兵（没有被 reset 误清）
        expect(board.getPiece(const Coord(3, 5))?.type, PieceType.pawn);
      });
    });
  });

  // ── FenParser.generate 走子方格式验证（防止回归） ──
  group('FenParser 与 BoardEditController 集成', () {
    test('默认红方走子 → FEN 以 " w" 结尾（FEN 标准）', () {
      final board = Board()..initialize();
      final controller = BoardEditController();
      final fen = controller.toFen(board);
      // 走子方格式：FEN 标准用 ' w'/' b'，与 ICCS/中文记谱的 r/b 不同
      expect(fen, endsWith(' w'));
    });
  });
}
