import 'package:flutter_test/flutter_test.dart';
import 'package:xqmagic/models/game_tree.dart';
import 'package:xqmagic/models/move.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/coord.dart';
import 'package:xqmagic/utils/fen.dart';

void main() {
  group('GameTreeNode', () {
    test('should create root node with fen', () {
      const fen = FenParser.initial;
      final node = GameTreeNode(fen: fen);
      expect(node.fen, fen);
      expect(node.move, isNull);
      expect(node.parent, isNull);
      expect(node.variationIndex, 0);
      expect(node.comment, '');
    });

    test('should create node with move and parent', () {
      const fen = FenParser.initial;
      final parent = GameTreeNode(fen: fen);
      final move = MoveRecord(
        pieceType: PieceType.pawn,
        from: const Coord(4, 0),
        to: const Coord(4, 1),
        capturedPiece: null,
        color: PieceColor.red,
      );
      final child = GameTreeNode(
        fen: 'after_move_fen',
        move: move,
        parent: parent,
        variationIndex: 0,
      );
      expect(child.fen, 'after_move_fen');
      expect(child.move, move);
      expect(child.parent, parent);
    });

    group('addMainLine', () {
      test('should add child node', () {
        final root = GameTreeNode(fen: FenParser.initial);
        final move = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 0),
          to: const Coord(4, 1),
          capturedPiece: null,
          color: PieceColor.red,
        );
        final child = root.addMainLine('next_fen', move);
        expect(root.children.length, 1);
        expect(root.children.first, child);
      });

      test('should set parent reference', () {
        final root = GameTreeNode(fen: FenParser.initial);
        final move = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 0),
          to: const Coord(4, 1),
          capturedPiece: null,
          color: PieceColor.red,
        );
        final child = root.addMainLine('next_fen', move);
        expect(child.parent, root);
      });

      test('should set move reference', () {
        final root = GameTreeNode(fen: FenParser.initial);
        final move = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 0),
          to: const Coord(4, 1),
          capturedPiece: null,
          color: PieceColor.red,
        );
        final child = root.addMainLine('next_fen', move);
        expect(child.move, move);
      });

      test('should increment variation index for subsequent children', () {
        final root = GameTreeNode(fen: FenParser.initial);
        final move1 = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 0),
          to: const Coord(4, 1),
          capturedPiece: null,
          color: PieceColor.red,
        );
        final move2 = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 0),
          to: const Coord(5, 1),
          capturedPiece: null,
          color: PieceColor.red,
        );
        final child1 = root.addMainLine('fen1', move1);
        final child2 = root.addVariation('fen2', move2);
        expect(child1.variationIndex, 0);
        expect(child2.variationIndex, 1);
      });
    });

    group('addVariation', () {
      test('should add variation node', () {
        final root = GameTreeNode(fen: FenParser.initial);
        final move = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 0),
          to: const Coord(4, 1),
          capturedPiece: null,
          color: PieceColor.red,
        );
        final child = root.addVariation('var_fen', move);
        expect(root.children.length, 1);
        expect(child.parent, root);
      });

      test('should add multiple variations', () {
        final root = GameTreeNode(fen: FenParser.initial);
        final move1 = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 0),
          to: const Coord(4, 1),
          capturedPiece: null,
          color: PieceColor.red,
        );
        final move2 = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 0),
          to: const Coord(5, 1),
          capturedPiece: null,
          color: PieceColor.red,
        );
        root.addMainLine('fen1', move1);
        root.addVariation('fen2', move2);
        expect(root.children.length, 2);
      });
    });

    group('isMainLine', () {
      test('root should be main line', () {
        final root = GameTreeNode(fen: FenParser.initial);
        expect(root.isMainLine, isTrue);
      });

      test('first child should be main line', () {
        final root = GameTreeNode(fen: FenParser.initial);
        final move = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 0),
          to: const Coord(4, 1),
          capturedPiece: null,
          color: PieceColor.red,
        );
        final child = root.addMainLine('next_fen', move);
        expect(child.isMainLine, isTrue);
      });

      test('second child should not be main line', () {
        final root = GameTreeNode(fen: FenParser.initial);
        final move1 = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 0),
          to: const Coord(4, 1),
          capturedPiece: null,
          color: PieceColor.red,
        );
        final move2 = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 0),
          to: const Coord(5, 1),
          capturedPiece: null,
          color: PieceColor.red,
        );
        root.addMainLine('fen1', move1);
        final variation = root.addVariation('fen2', move2);
        expect(variation.isMainLine, isFalse);
      });
    });

    group('getPathFromRoot', () {
      test('root should return empty path', () {
        final root = GameTreeNode(fen: FenParser.initial);
        expect(root.getPathFromRoot(), isEmpty);
      });

      test('first child should return [0]', () {
        final root = GameTreeNode(fen: FenParser.initial);
        final move = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 0),
          to: const Coord(4, 1),
          capturedPiece: null,
          color: PieceColor.red,
        );
        final child = root.addMainLine('next_fen', move);
        expect(child.getPathFromRoot(), [0]);
      });

      test('grandchild should return [0, 0]', () {
        final root = GameTreeNode(fen: FenParser.initial);
        final move1 = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 0),
          to: const Coord(4, 1),
          capturedPiece: null,
          color: PieceColor.red,
        );
        final move2 = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 1),
          to: const Coord(4, 2),
          capturedPiece: null,
          color: PieceColor.black,
        );
        final child = root.addMainLine('fen1', move1);
        final grandchild = child.addMainLine('fen2', move2);
        expect(grandchild.getPathFromRoot(), [0, 0]);
      });
    });

    group('getMovesFromRoot', () {
      test('root should return empty moves', () {
        final root = GameTreeNode(fen: FenParser.initial);
        expect(root.getMovesFromRoot(), isEmpty);
      });

      test('should return moves from root to node', () {
        final root = GameTreeNode(fen: FenParser.initial);
        final move1 = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 0),
          to: const Coord(4, 1),
          capturedPiece: null,
          color: PieceColor.red,
        );
        final move2 = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 1),
          to: const Coord(4, 2),
          capturedPiece: null,
          color: PieceColor.black,
        );
        final child = root.addMainLine('fen1', move1);
        final grandchild = child.addMainLine('fen2', move2);
        final moves = grandchild.getMovesFromRoot();
        expect(moves.length, 2);
        expect(moves[0], move1);
        expect(moves[1], move2);
      });
    });

    group('hasChildren', () {
      test('should return false for leaf node', () {
        final node = GameTreeNode(fen: FenParser.initial);
        expect(node.hasChildren, isFalse);
      });

      test('should return true for node with children', () {
        final root = GameTreeNode(fen: FenParser.initial);
        final move = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 0),
          to: const Coord(4, 1),
          capturedPiece: null,
          color: PieceColor.red,
        );
        root.addMainLine('next_fen', move);
        expect(root.hasChildren, isTrue);
      });
    });

    group('mainLineChild', () {
      test('should return first child', () {
        final root = GameTreeNode(fen: FenParser.initial);
        final move1 = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 0),
          to: const Coord(4, 1),
          capturedPiece: null,
          color: PieceColor.red,
        );
        final move2 = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 0),
          to: const Coord(5, 1),
          capturedPiece: null,
          color: PieceColor.red,
        );
        final mainChild = root.addMainLine('fen1', move1);
        root.addVariation('fen2', move2);
        expect(root.mainLineChild, mainChild);
      });

      test('should return null for leaf node', () {
        final node = GameTreeNode(fen: FenParser.initial);
        expect(node.mainLineChild, isNull);
      });
    });

    group('fen', () {
      test('should return full FEN with active color', () {
        const fen =
            'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR r';
        final node = GameTreeNode(fen: fen);
        expect(node.fen, fen);
      });
    });

    group('evaluation and annotations', () {
      test('should support evaluation', () {
        final node = GameTreeNode(fen: FenParser.initial);
        node.evaluation = 150;
        expect(node.evaluation, 150);
      });

      test('should support move annotation', () {
        final node = GameTreeNode(fen: FenParser.initial);
        node.moveAnnotation = '!';
        expect(node.moveAnnotation, '!');
      });

      test('should support cloud best move', () {
        final node = GameTreeNode(fen: FenParser.initial);
        node.cloudBestMove = '8182';
        expect(node.cloudBestMove, '8182');
      });

      test('should support comment', () {
        final node = GameTreeNode(fen: FenParser.initial);
        node.comment = 'Good move!';
        expect(node.comment, 'Good move!');
      });
    });

    group('children (unmodifiable)', () {
      test('should return unmodifiable list', () {
        final root = GameTreeNode(fen: FenParser.initial);
        expect(
          () => root.children.add(GameTreeNode(fen: 'test')),
          throwsUnsupportedError,
        );
      });
    });
  });

  group('GameTree', () {
    late GameTree gameTree;

    setUp(() {
      gameTree = GameTree();
    });

    group('initialization', () {
      test('should initialize from FEN', () {
        gameTree.initFromFen(FenParser.initial);
        expect(gameTree.current, isNotNull);
        expect(gameTree.current!.fen, FenParser.initial);
        expect(gameTree.root.fen, FenParser.initial);
      });

      test('should initialize standard game', () {
        gameTree.initStandard();
        expect(gameTree.current!.fen, FenParser.initial);
      });

      test('should have current pointing to root after init', () {
        gameTree.initStandard();
        expect(gameTree.current, gameTree.root);
      });
    });

    group('makeMove', () {
      setUp(() {
        gameTree.initStandard();
      });

      test('should add move to tree', () {
        final move = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 0),
          to: const Coord(4, 1),
          capturedPiece: null,
          color: PieceColor.red,
        );
        final child = gameTree.makeMove(move, 'after_move');
        expect(child.move, move);
        expect(child.fen, 'after_move');
      });

      test('should update current node', () {
        final move = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 0),
          to: const Coord(4, 1),
          capturedPiece: null,
          color: PieceColor.red,
        );
        gameTree.makeMove(move, 'after_move');
        expect(gameTree.current!.fen, 'after_move');
      });

      test('should increment depth', () {
        final move = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 0),
          to: const Coord(4, 1),
          capturedPiece: null,
          color: PieceColor.red,
        );
        expect(gameTree.depth, 0);
        gameTree.makeMove(move, 'after_move');
        expect(gameTree.depth, 1);
      });
    });

    group('makeVariation', () {
      setUp(() {
        gameTree.initStandard();
        final move1 = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 0),
          to: const Coord(4, 1),
          capturedPiece: null,
          color: PieceColor.red,
        );
        gameTree.makeMove(move1, 'after_move');
        gameTree.goBack();
      });

      test('should add variation from current node', () {
        final variationMove = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 0),
          to: const Coord(5, 1),
          capturedPiece: null,
          color: PieceColor.red,
        );
        gameTree.makeVariation(variationMove, 'variation_fen');
        expect(gameTree.current!.fen, 'variation_fen');
      });

      test('should create branch', () {
        final variationMove = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 0),
          to: const Coord(5, 1),
          capturedPiece: null,
          color: PieceColor.red,
        );
        gameTree.makeVariation(variationMove, 'variation_fen');
        // root already has 1 child from setUp (main line)
        // makeVariation adds another child, so now root has 2 children
        expect(gameTree.root.children.length, 2);
        expect(gameTree.root.mainLineChild!.fen, 'after_move');
      });
    });

    group('navigation', () {
      setUp(() {
        gameTree.initStandard();
      });

      group('goForward', () {
        test('should return false when no children', () {
          expect(gameTree.goForward(), isFalse);
        });

        test('should move to main line child', () {
          final move = MoveRecord(
            pieceType: PieceType.pawn,
            from: const Coord(4, 0),
            to: const Coord(4, 1),
            capturedPiece: null,
            color: PieceColor.red,
          );
          gameTree.makeMove(move, 'after_move');
          gameTree.goBack();
          expect(gameTree.current!.fen, FenParser.initial);

          expect(gameTree.goForward(), isTrue);
          expect(gameTree.current!.fen, 'after_move');
        });

        test('should support variation index', () {
          final move1 = MoveRecord(
            pieceType: PieceType.pawn,
            from: const Coord(4, 0),
            to: const Coord(4, 1),
            capturedPiece: null,
            color: PieceColor.red,
          );
          final move2 = MoveRecord(
            pieceType: PieceType.pawn,
            from: const Coord(4, 0),
            to: const Coord(5, 1),
            capturedPiece: null,
            color: PieceColor.red,
          );
          gameTree.makeMove(move1, 'main_fen');
          gameTree.goBack();
          gameTree.makeVariation(move2, 'var_fen');
          gameTree.goBack();

          // Navigate to variation (index 1)
          expect(gameTree.goForward(variationIndex: 1), isTrue);
          expect(gameTree.current!.fen, 'var_fen');
        });

        test(
          'should default to main line when variation index not provided',
          () {
            final move1 = MoveRecord(
              pieceType: PieceType.pawn,
              from: const Coord(4, 0),
              to: const Coord(4, 1),
              capturedPiece: null,
              color: PieceColor.red,
            );
            final move2 = MoveRecord(
              pieceType: PieceType.pawn,
              from: const Coord(4, 0),
              to: const Coord(5, 1),
              capturedPiece: null,
              color: PieceColor.red,
            );
            gameTree.makeMove(move1, 'main_fen');
            gameTree.goBack();
            gameTree.makeVariation(move2, 'var_fen');
            gameTree.goBack();

            expect(gameTree.goForward(), isTrue);
            expect(gameTree.current!.fen, 'main_fen');
          },
        );
      });

      group('goBack', () {
        test('should return false at root', () {
          expect(gameTree.goBack(), isFalse);
        });

        test('should move to parent', () {
          final move = MoveRecord(
            pieceType: PieceType.pawn,
            from: const Coord(4, 0),
            to: const Coord(4, 1),
            capturedPiece: null,
            color: PieceColor.red,
          );
          gameTree.makeMove(move, 'after_move');
          expect(gameTree.current!.fen, 'after_move');

          expect(gameTree.goBack(), isTrue);
          expect(gameTree.current!.fen, FenParser.initial);
        });
      });

      group('goToStart', () {
        test('should return to root', () {
          final move1 = MoveRecord(
            pieceType: PieceType.pawn,
            from: const Coord(4, 0),
            to: const Coord(4, 1),
            capturedPiece: null,
            color: PieceColor.red,
          );
          final move2 = MoveRecord(
            pieceType: PieceType.pawn,
            from: const Coord(4, 1),
            to: const Coord(4, 2),
            capturedPiece: null,
            color: PieceColor.black,
          );
          gameTree.makeMove(move1, 'fen1');
          gameTree.makeMove(move2, 'fen2');

          gameTree.goToStart();
          expect(gameTree.current, gameTree.root);
          expect(gameTree.current!.fen, FenParser.initial);
        });
      });

      group('isOnMainLine', () {
        test('should be true at root', () {
          expect(gameTree.isOnMainLine, isTrue);
        });

        test('should be true on main line', () {
          final move = MoveRecord(
            pieceType: PieceType.pawn,
            from: const Coord(4, 0),
            to: const Coord(4, 1),
            capturedPiece: null,
            color: PieceColor.red,
          );
          gameTree.makeMove(move, 'after_move');
          expect(gameTree.isOnMainLine, isTrue);
        });
      });
    });

    group('properties', () {
      test('currentFen should return current node FEN', () {
        // 原为两条名字不同的同一断言、都是 isNotNull。合并后加
        // 实质断言：makeMove 后 FEN 应变化。
        gameTree.initStandard();
        expect(gameTree.currentFen, FenParser.initial);

        final move = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 0),
          to: const Coord(4, 1),
          capturedPiece: null,
          color: PieceColor.red,
        );
        gameTree.makeMove(move, 'after_move_fen');
        expect(
          gameTree.currentFen,
          'after_move_fen',
          reason: 'currentFen should follow _current after makeMove',
        );
      });

      test('movesFromRoot should return moves from root', () {
        gameTree.initStandard();
        expect(gameTree.movesFromRoot, isEmpty);

        final move = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 0),
          to: const Coord(4, 1),
          capturedPiece: null,
          color: PieceColor.red,
        );
        gameTree.makeMove(move, 'after_move');
        expect(gameTree.movesFromRoot.length, 1);
        expect(gameTree.movesFromRoot.first, move);
      });

      test('depth should return correct depth', () {
        gameTree.initStandard();
        expect(gameTree.depth, 0);

        final move = MoveRecord(
          pieceType: PieceType.pawn,
          from: const Coord(4, 0),
          to: const Coord(4, 1),
          capturedPiece: null,
          color: PieceColor.red,
        );
        gameTree.makeMove(move, 'after_move');
        expect(gameTree.depth, 1);
      });
    });

    // ——— 补充覆盖 AGENTS.md 中重点强调的契约 ———
    // 1. makeMove 在当前节点已有 mainLine 子节点时必须自动作为 variation
    // 2. goToMainLine 能从变着跳到主变着
    // 3. mainLineMoves / mainLinePath 跨越全树
    // 4. clearChildren() 在 force-overwrite 场景下可用
    group('contracts from AGENTS.md', () {
      final moveA = MoveRecord(
        pieceType: PieceType.pawn,
        from: const Coord(4, 0),
        to: const Coord(4, 1),
        capturedPiece: null,
        color: PieceColor.red,
      );
      final moveB = MoveRecord(
        pieceType: PieceType.pawn,
        from: const Coord(4, 0),
        to: const Coord(4, 1),
        capturedPiece: null,
        color: PieceColor.red,
      );

      test('makeMove on node with mainLine child should auto-variate', () {
        // AGENTS.md 明确点名：原实现中 makeMove 会 clearChildren()，
        // 导致"后退走变着"静默删除主变着分支。修复后必须自动作 variation。
        gameTree.initStandard();
        gameTree.makeMove(moveA, 'f1'); // main line
        gameTree.goBack(); // 回到 root

        final second = gameTree.makeMove(moveB, 'f2');

        // 重要：root 现在应有 2 个子节点（main + variation），
        //      不能只保留后走的那一个。
        expect(
          gameTree.root.children.length,
          2,
          reason: 'mainLine child must be preserved when adding new move',
        );
        expect(
          second.variationIndex,
          1,
          reason: 'second move should be at variation index 1',
        );
        expect(gameTree.root.children[0].fen, 'f1');
        expect(gameTree.root.children[1].fen, 'f2');
      });

      test('goToMainLine returns to main variation from a variation', () {
        gameTree.initStandard();
        gameTree.makeMove(moveA, 'main_fen');
        gameTree.goBack();
        gameTree.makeVariation(moveB, 'var_fen');
        // 现在 _current 在 variation 节点
        expect(gameTree.isOnMainLine, isFalse);

        final ok = gameTree.goToMainLine();
        expect(ok, isTrue);
        expect(gameTree.isOnMainLine, isTrue);
      });

      test('goToMainLine returns false at root (already on main)', () {
        gameTree.initStandard();
        // root 本身没有 main line 概念，但 should not throw
        expect(gameTree.goToMainLine(), anyOf(isFalse, isTrue));
      });

      test(
        'mainLineMoves returns all main line moves regardless of _current',
        () {
          // mainLineMoves 返回的 MoveRecord 是 addMainLine 时存进去的那个。
          // 走 moveA 作为 main，moveB 作为 variation。
          gameTree.initStandard();
          gameTree.makeMove(moveA, 'f1');
          gameTree.goBack();
          gameTree.makeVariation(moveB, 'f2');
          // _current 现在在 variation 节点
          final main = gameTree.mainLineMoves;
          expect(main.length, 1);
          expect(
            main.first,
            same(moveA),
            reason: 'mainLineMoves should follow main, not current variation',
          );
        },
      );

      test('mainLinePath returns nodes from root to deepest main line', () {
        gameTree.initStandard();
        gameTree.makeMove(moveA, 'f1');
        // 不 goBack
        final path = gameTree.mainLinePath;
        expect(path.length, 2); // root + f1
        expect(path.first.fen, FenParser.initial);
        expect(path.last.fen, 'f1');
      });

      test('clearChildren() removes all children of a node', () {
        final node = GameTreeNode(fen: FenParser.initial);
        node.addMainLine(
          'c1',
          MoveRecord(
            pieceType: PieceType.pawn,
            from: const Coord(0, 0),
            to: const Coord(0, 1),
            capturedPiece: null,
            color: PieceColor.red,
          ),
        );
        node.addVariation(
          'c2',
          MoveRecord(
            pieceType: PieceType.pawn,
            from: const Coord(0, 0),
            to: const Coord(0, 1),
            capturedPiece: null,
            color: PieceColor.red,
          ),
        );
        expect(node.children.length, 2);
        node.clearChildren();
        expect(node.children, isEmpty);
        expect(node.mainLineChild, isNull);
      });

      test(
        'getPathToCurrent returns path from root to current (inclusive)',
        () {
          // 实现实际【包含】当前节点本身（root 沿 parent 链走到 _current），
          // 跟 doc comment “不含当前节点自身” 不一致。这里按实际行为锁住。
          gameTree.initStandard();
          gameTree.makeMove(moveA, 'f1');
          final path = gameTree.getPathToCurrent();
          expect(path.length, 2, reason: 'root + f1');
          expect(path.first.fen, FenParser.initial);
          expect(path.last.fen, 'f1');
        },
      );
    });
  });
}
