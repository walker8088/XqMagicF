import 'package:flutter_test/flutter_test.dart';
import 'package:xqmagic/models/board.dart';
import 'package:xqmagic/models/chess_piece.dart';
import 'package:xqmagic/models/move.dart';
import 'package:xqmagic/utils/chinese_notation.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/coord.dart';

/// 坐标系统说明：
/// - col: 0-8, col=0 是最左边, col=8 是最右边
/// - row: 0-9, row=0 是红方底线, row=9 是黑方底线
/// - 红方纵线（从右到左）：col=8→一路, col=7→二路, ..., col=0→九路
/// - 黑方纵线（从右到左）：col=8→9路, col=7→8路, ..., col=0→1路
/// - 纵线编号 = 9 - col

void main() {
  group('ChineseNotation.normalizeCoord', () {
    test('红方坐标不变化', () {
      final coord = const Coord(4, 0);
      final result = ChineseNotation.normalizeCoord(coord, PieceColor.red);
      expect(result, coord);
    });

    test('黑方坐标旋转180度', () {
      final coord = const Coord(4, 9);
      final result = ChineseNotation.normalizeCoord(coord, PieceColor.black);
      expect(result.col, 4);
      expect(result.row, 0);
    });

    test('黑方车坐标旋转', () {
      final coord = const Coord(0, 9);
      final result = ChineseNotation.normalizeCoord(coord, PieceColor.black);
      expect(result.col, 8);
      expect(result.row, 0);
    });

    test('黑方炮坐标旋转', () {
      final coord = const Coord(1, 7);
      final result = ChineseNotation.normalizeCoord(coord, PieceColor.black);
      expect(result.col, 7);
      expect(result.row, 2);
    });
  });

  group('ChineseNotation.denormalizeCoord', () {
    test('红方坐标不变化', () {
      final coord = const Coord(4, 0);
      final result = ChineseNotation.denormalizeCoord(coord, PieceColor.red);
      expect(result, coord);
    });

    test('黑方坐标还原', () {
      final coord = const Coord(4, 0);
      final result = ChineseNotation.denormalizeCoord(coord, PieceColor.black);
      expect(result.col, 4);
      expect(result.row, 9);
    });

    test('normalize 和 denormalize 互逆', () {
      const original = Coord(1, 7);
      final normalized = ChineseNotation.normalizeCoord(original, PieceColor.black);
      final denormalized = ChineseNotation.denormalizeCoord(normalized, PieceColor.black);
      expect(denormalized, original);
    });
  });

  group('ChineseNotation.normalizeMove', () {
    test('红方走法不变化', () {
      final move = const MoveRecord(
        from: Coord(4, 0),
        to: Coord(4, 1),
        pieceType: PieceType.king,
        color: PieceColor.red,
      );
      final result = ChineseNotation.normalizeMove(move);
      expect(result.from, move.from);
      expect(result.to, move.to);
    });

    test('黑方走法坐标旋转', () {
      final move = const MoveRecord(
        from: Coord(1, 7),
        to: Coord(1, 4),
        pieceType: PieceType.cannon,
        color: PieceColor.black,
      );
      final result = ChineseNotation.normalizeMove(move);
      expect(result.from.col, 7);
      expect(result.from.row, 2);
      expect(result.to.col, 7);
      expect(result.to.row, 5);
    });
  });

  group('ChineseNotation.toText - 基本记谱', () {
    late Board board;

    setUp(() {
      board = Board();
      board.initialize();
    });

    test('炮二平五（红炮从二路平到五路，col=7→col=4）', () {
      // 二路 = col = 9-2 = 7
      final move = const MoveRecord(
        from: Coord(7, 2),
        to: Coord(4, 2),
        pieceType: PieceType.cannon,
        color: PieceColor.red,
      );
      final notation = ChineseNotation.toText(board.pieces, move);
      expect(notation, '炮二平五');
    });

    test('马8进7（黑马从8路进到7路，col=7→col=6）', () {
      // 黑方8路 = col = 8-1 = 7, 7路 = col = 7-1 = 6
      final move = const MoveRecord(
        from: Coord(7, 9),
        to: Coord(6, 7),
        pieceType: PieceType.knight,
        color: PieceColor.black,
      );
      final notation = ChineseNotation.toText(board.pieces, move);
      expect(notation, '马8进7');
    });

    test('车二进三（红车前进3步，col=7, row=0→row=3）', () {
      // 二路 = col=7
      final move = const MoveRecord(
        from: Coord(7, 0),
        to: Coord(7, 3),
        pieceType: PieceType.rook,
        color: PieceColor.red,
      );
      final notation = ChineseNotation.toText(board.pieces, move);
      expect(notation, '车二进三');
    });

    test('兵七进一（红兵前进1步，col=2, row=3→row=4）', () {
      // 七路 = col = 9-7 = 2, 红方前进 = row 增大
      final move = const MoveRecord(
        from: Coord(2, 3),
        to: Coord(2, 4),
        pieceType: PieceType.pawn,
        color: PieceColor.red,
      );
      final notation = ChineseNotation.toText(board.pieces, move);
      expect(notation, '兵七进一');
    });

    test('象3进5（黑象从3路进到5路，col=2→col=4）', () {
      // 黑方3路 = col = 3-1 = 2, 5路 = col = 5-1 = 4
      final move = const MoveRecord(
        from: Coord(2, 9),
        to: Coord(4, 7),
        pieceType: PieceType.bishop,
        color: PieceColor.black,
      );
      final notation = ChineseNotation.toText(board.pieces, move);
      expect(notation, '象3进5');
    });

    test('车一进一（红车前进1步，col=8, row=0→row=1）', () {
      // 一路 = col = 9-1 = 8
      final move = const MoveRecord(
        from: Coord(8, 0),
        to: Coord(8, 1),
        pieceType: PieceType.rook,
        color: PieceColor.red,
      );
      final notation = ChineseNotation.toText(board.pieces, move);
      expect(notation, '车一进一');
    });

    test('帅五进一（红帅前进1步）', () {
      final move = const MoveRecord(
        from: Coord(4, 0),
        to: Coord(4, 1),
        pieceType: PieceType.king,
        color: PieceColor.red,
      );
      final notation = ChineseNotation.toText(board.pieces, move);
      expect(notation, '帅五进一');
    });

    test('仕四进五（红仕斜进，col=5→col=4）', () {
      // 四路 = col = 9-4 = 5, 五路 = col = 9-5 = 4
      // 红仕在 col=5, row=0（四路）
      final move = const MoveRecord(
        from: Coord(5, 0),
        to: Coord(4, 1),
        pieceType: PieceType.advisor,
        color: PieceColor.red,
      );
      final notation = ChineseNotation.toText(board.pieces, move);
      expect(notation, '仕四进五');
    });
  });

  group('ChineseNotation.toText - 同线多子', () {
    late Board board;

    setUp(() {
      board = Board();
      board.clear();
    });

    test('同线双车 - 前车平五', () {
      // 两个红车在同一纵线（二路 col=7）
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.red, coord: const Coord(7, 2)));
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.red, coord: const Coord(7, 4)));

      // 前面的车（col=7, row=4）平移到五路
      final move = const MoveRecord(
        from: Coord(7, 4),
        to: Coord(4, 4),
        pieceType: PieceType.rook,
        color: PieceColor.red,
      );
      final notation = ChineseNotation.toText(board.pieces, move);
      expect(notation, '前车平五');
    });

    test('同线双车 - 后车平五', () {
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.red, coord: const Coord(7, 2)));
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.red, coord: const Coord(7, 4)));

      final move = const MoveRecord(
        from: Coord(7, 2),
        to: Coord(4, 2),
        pieceType: PieceType.rook,
        color: PieceColor.red,
      );
      final notation = ChineseNotation.toText(board.pieces, move);
      expect(notation, '后车平五');
    });

    test('单炮不需要前缀', () {
      board.putPiece(ChessPiece(type: PieceType.cannon, color: PieceColor.red, coord: const Coord(7, 2)));

      final move = const MoveRecord(
        from: Coord(7, 2),
        to: Coord(4, 2),
        pieceType: PieceType.cannon,
        color: PieceColor.red,
      );
      final notation = ChineseNotation.toText(board.pieces, move);
      expect(notation, '炮二平五');
      expect(notation.startsWith('前'), isFalse);
      expect(notation.startsWith('后'), isFalse);
    });

    test('不同纵线的同类型棋子不需要前缀', () {
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.red, coord: const Coord(8, 0)));
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.red, coord: const Coord(0, 0)));

      // 右车移动（一路 col=8）
      final move = const MoveRecord(
        from: Coord(8, 0),
        to: Coord(8, 3),
        pieceType: PieceType.rook,
        color: PieceColor.red,
      );
      final notation = ChineseNotation.toText(board.pieces, move);
      expect(notation, '车一进三');
      expect(notation.startsWith('前'), isFalse);
    });
  });

  group('ChineseNotation.toText - 繁体中文', () {
    late Board board;

    setUp(() {
      board = Board();
      board.initialize();
    });

    test('红方繁体记谱', () {
      final move = const MoveRecord(
        from: Coord(7, 2),
        to: Coord(4, 2),
        pieceType: PieceType.cannon,
        color: PieceColor.red,
      );
      final notation = ChineseNotation.toText(board.pieces, move, useSimpleText: false);
      expect(notation, '砲二平五');
    });

    test('黑方繁体记谱', () {
      final move = const MoveRecord(
        from: Coord(7, 9),
        to: Coord(6, 7),
        pieceType: PieceType.knight,
        color: PieceColor.black,
      );
      final notation = ChineseNotation.toText(board.pieces, move, useSimpleText: false);
      expect(notation, '馬8进7');
    });
  });

  group('ChineseNotation.toWXF', () {
    late Board board;

    setUp(() {
      board = Board();
      board.initialize();
    });

    test('炮二平五 → C2.5', () {
      final move = const MoveRecord(
        from: Coord(7, 2),
        to: Coord(4, 2),
        pieceType: PieceType.cannon,
        color: PieceColor.red,
      );
      final wxf = ChineseNotation.toWXF(board.pieces, move);
      expect(wxf, 'C2.5');
    });

    test('马8进7 → N8+7', () {
      final move = const MoveRecord(
        from: Coord(7, 9),
        to: Coord(6, 7),
        pieceType: PieceType.knight,
        color: PieceColor.black,
      );
      final wxf = ChineseNotation.toWXF(board.pieces, move);
      expect(wxf, 'N8+7');
    });

    test('车二进三 → R2+3', () {
      // 注意：初始棋盘红方二路(col=7)是马，不是车
      // 这里测试记谱转换逻辑，不考虑棋盘上是否有对应棋子
      final move = const MoveRecord(
        from: Coord(7, 0),
        to: Coord(7, 3),
        pieceType: PieceType.rook,
        color: PieceColor.red,
      );
      final wxf = ChineseNotation.toWXF(board.pieces, move);
      expect(wxf, 'R2+3');
    });

    test('车一进一 → R1+1', () {
      final move = const MoveRecord(
        from: Coord(8, 0),
        to: Coord(8, 1),
        pieceType: PieceType.rook,
        color: PieceColor.red,
      );
      final wxf = ChineseNotation.toWXF(board.pieces, move);
      expect(wxf, 'R1+1');
    });

    test('兵三平四 → P3.4', () {
      // 三路 = col = 9-3 = 6
      final move = const MoveRecord(
        from: Coord(6, 3),
        to: Coord(5, 3),
        pieceType: PieceType.pawn,
        color: PieceColor.red,
      );
      final wxf = ChineseNotation.toWXF(board.pieces, move);
      expect(wxf, 'P3.4');
    });

    test('黑方炮8进4 → C8+4', () {
      // 黑方8路 = col = 8-1 = 7
      final move = const MoveRecord(
        from: Coord(7, 7),
        to: Coord(7, 3),
        pieceType: PieceType.cannon,
        color: PieceColor.black,
      );
      final wxf = ChineseNotation.toWXF(board.pieces, move);
      expect(wxf, 'C8+4');
    });
  });

  group('ChineseNotation.toWXF - 同线多子', () {
    late Board board;

    setUp(() {
      board = Board();
      board.clear();
    });

    test('前车平五 → fR2.5', () {
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.red, coord: const Coord(7, 2)));
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.red, coord: const Coord(7, 4)));

      final move = const MoveRecord(
        from: Coord(7, 4),
        to: Coord(4, 4),
        pieceType: PieceType.rook,
        color: PieceColor.red,
      );
      final wxf = ChineseNotation.toWXF(board.pieces, move);
      expect(wxf, 'fR2.5');
    });

    test('后马退三 → bN2-3', () {
      board.putPiece(ChessPiece(type: PieceType.knight, color: PieceColor.red, coord: const Coord(7, 0)));
      board.putPiece(ChessPiece(type: PieceType.knight, color: PieceColor.red, coord: const Coord(7, 2)));

      // 后面的马（row=0）
      final move = const MoveRecord(
        from: Coord(7, 0),
        to: Coord(6, 2),
        pieceType: PieceType.knight,
        color: PieceColor.red,
      );
      final wxf = ChineseNotation.toWXF(board.pieces, move);
      expect(wxf.startsWith('b'), isTrue);
    });
  });

  group('ChineseNotation.fromWXF', () {
    late Board board;

    setUp(() {
      board = Board();
      board.initialize();
    });

    test('解析 C2.5 → (from, to)', () {
      final result = ChineseNotation.fromWXF(board.pieces, 'C2.5', PieceColor.red);
      expect(result, isNotNull);
      final (from, to) = result!;
      // WXF 纵线2 = col = 9-2 = 7
      expect(from.col, 7);
      expect(from.row, 2);
      expect(to.col, 4);
      expect(to.row, 2);
    });

    test('解析 N8+7 → (from, to)', () {
      // 黑方8路 = col = 8-1 = 7
      // 注意：fromWXF 需要棋盘上有对应的棋子
      // 初始棋盘黑方马在 col=7, row=9
      final result = ChineseNotation.fromWXF(board.pieces, 'N8+7', PieceColor.black);
      expect(result, isNotNull);
      final (from, to) = result!;
      expect(from.col, 7);
      expect(from.row, 9);
      // 马8进7：从8路进到7路，斜线移动
      expect(to.col, 6); // 7路 = col=7-1=6
      expect(to.row, 7); // 马走日，row变化2
    });

    test('解析无效格式返回 null', () {
      expect(ChineseNotation.fromWXF(board.pieces, 'X', PieceColor.red), isNull);
      expect(ChineseNotation.fromWXF(board.pieces, 'AB', PieceColor.red), isNull);
      expect(ChineseNotation.fromWXF(board.pieces, '', PieceColor.red), isNull);
    });

    test('解析 R1+3 → (from, to)', () {
      // 红方一路 = col = 9-1 = 8
      // 初始棋盘红方车在 col=8, row=0
      final result = ChineseNotation.fromWXF(board.pieces, 'R1+3', PieceColor.red);
      expect(result, isNotNull);
      final (from, to) = result!;
      expect(from.col, 8);
      expect(from.row, 0);
      expect(to.col, 8);
      expect(to.row, 3);
    });

    test('解析 P3.4 → (from, to)', () {
      final result = ChineseNotation.fromWXF(board.pieces, 'P3.4', PieceColor.red);
      expect(result, isNotNull);
      final (from, to) = result!;
      // 三路 = col=9-3=6
      expect(from.col, 6);
      expect(from.row, 3);
      expect(to.col, 5);
      expect(to.row, 3);
    });
  });

  group('ChineseNotation 综合测试 - 经典开局', () {
    late Board board;

    setUp(() {
      board = Board();
      board.initialize();
    });

    test('中炮局第一步：炮二平五', () {
      final move = const MoveRecord(
        from: Coord(7, 2),
        to: Coord(4, 2),
        pieceType: PieceType.cannon,
        color: PieceColor.red,
      );
      final notation = ChineseNotation.toText(board.pieces, move);
      final wxf = ChineseNotation.toWXF(board.pieces, move);
      expect(notation, '炮二平五');
      expect(wxf, 'C2.5');
    });

    test('黑方应着：马8进7', () {
      final move = const MoveRecord(
        from: Coord(7, 9),
        to: Coord(6, 7),
        pieceType: PieceType.knight,
        color: PieceColor.black,
      );
      final notation = ChineseNotation.toText(board.pieces, move);
      final wxf = ChineseNotation.toWXF(board.pieces, move);
      expect(notation, '马8进7');
      expect(wxf, 'N8+7');
    });

    test('黑方还架中炮：炮8平5', () {
      final move = const MoveRecord(
        from: Coord(7, 7),
        to: Coord(4, 7),
        pieceType: PieceType.cannon,
        color: PieceColor.black,
      );
      final notation = ChineseNotation.toText(board.pieces, move);
      final wxf = ChineseNotation.toWXF(board.pieces, move);
      expect(notation, '炮8平5');
      expect(wxf, 'C8.5');
    });
  });

  group('ChineseNotation 综合测试 - 黑方 normalize 验证', () {
    late Board board;

    setUp(() {
      board = Board();
      board.initialize();
    });

    test('黑方炮8进4 - normalize 后计算正确', () {
      // 黑方8路 = col = 8-1 = 7
      final move = const MoveRecord(
        from: Coord(7, 7),
        to: Coord(7, 3),
        pieceType: PieceType.cannon,
        color: PieceColor.black,
      );
      final notation = ChineseNotation.toText(board.pieces, move);
      expect(notation, '炮8进4');
    });

    test('黑方车9进1 - normalize 后计算正确', () {
      // 黑方9路 = col = 9-1 = 8
      final move = const MoveRecord(
        from: Coord(8, 9),
        to: Coord(8, 8),
        pieceType: PieceType.rook,
        color: PieceColor.black,
      );
      final notation = ChineseNotation.toText(board.pieces, move);
      expect(notation, '车9进1');
    });

    test('黑方卒3进1 - normalize 后计算正确', () {
      // 黑方3路 = col = 3-1 = 2
      final move = const MoveRecord(
        from: Coord(2, 6),
        to: Coord(2, 5),
        pieceType: PieceType.pawn,
        color: PieceColor.black,
      );
      final notation = ChineseNotation.toText(board.pieces, move);
      // 黑方前进 = row 减小 (6→5)
      expect(notation, '卒3进1');
    });
  });

  group('ChineseNotation 综合测试 - WXF round-trip', () {
    late Board board;

    setUp(() {
      board = Board();
      board.initialize();
    });

    test('炮二平五 round-trip: move → WXF → coords', () {
      final originalFrom = const Coord(7, 2);
      final originalTo = const Coord(4, 2);

      final move = MoveRecord(
        from: originalFrom,
        to: originalTo,
        pieceType: PieceType.cannon,
        color: PieceColor.red,
      );

      final wxf = ChineseNotation.toWXF(board.pieces, move);
      final result = ChineseNotation.fromWXF(board.pieces, wxf, PieceColor.red);

      expect(result, isNotNull);
      final (from, to) = result!;
      expect(from, originalFrom);
      expect(to, originalTo);
    });

    test('马8进7 round-trip: move → WXF → coords', () {
      final originalFrom = const Coord(7, 9);
      final originalTo = const Coord(6, 7);

      final move = MoveRecord(
        from: originalFrom,
        to: originalTo,
        pieceType: PieceType.knight,
        color: PieceColor.black,
      );

      final wxf = ChineseNotation.toWXF(board.pieces, move);
      // WXF: N8+7
      final result = ChineseNotation.fromWXF(board.pieces, wxf, PieceColor.black);

      expect(result, isNotNull);
      final (from, to) = result!;
      expect(from, originalFrom);
      expect(to, originalTo);
    });

    test('车一进三 round-trip: move → WXF → coords', () {
      // 一路 = col = 9-1 = 8
      final originalFrom = const Coord(8, 0);
      final originalTo = const Coord(8, 3);

      final move = MoveRecord(
        from: originalFrom,
        to: originalTo,
        pieceType: PieceType.rook,
        color: PieceColor.red,
      );

      final wxf = ChineseNotation.toWXF(board.pieces, move);
      // WXF: R1+3
      final result = ChineseNotation.fromWXF(board.pieces, wxf, PieceColor.red);

      expect(result, isNotNull);
      final (from, to) = result!;
      expect(from, originalFrom);
      expect(to, originalTo);
    });
  });

  group('ChineseNotation 综合测试 - 完整对局', () {
    late Board board;

    test('中炮对屏风马前几步', () {
      board = Board();
      board.initialize();

      // 1. 炮二平五
      var move = const MoveRecord(from: Coord(7, 2), to: Coord(4, 2), pieceType: PieceType.cannon, color: PieceColor.red);
      expect(ChineseNotation.toText(board.pieces, move), '炮二平五');
      board.movePiece(move.from, move.to);

      // 1... 马8进7
      move = const MoveRecord(from: Coord(7, 9), to: Coord(6, 7), pieceType: PieceType.knight, color: PieceColor.black);
      expect(ChineseNotation.toText(board.pieces, move), '马8进7');
      board.movePiece(move.from, move.to);

      // 2. 马二进三
      move = const MoveRecord(from: Coord(7, 0), to: Coord(6, 2), pieceType: PieceType.knight, color: PieceColor.red);
      expect(ChineseNotation.toText(board.pieces, move), '马二进三');
      board.movePiece(move.from, move.to);

      // 2... 车9平8
      move = const MoveRecord(from: Coord(8, 9), to: Coord(7, 9), pieceType: PieceType.rook, color: PieceColor.black);
      expect(ChineseNotation.toText(board.pieces, move), '车9平8');
    });
  });

  // ============================================================
  // 完整测试：红黑双方所有棋子类型的所有走法
  // 参考 cchess/tests/test_board_move.py
  // ============================================================

  group('全棋子覆盖 - 红方所有棋子', () {
    late Board board;

    setUp(() {
      board = Board();
      board.initialize();
    });

    group('红车(R)', () {
      test('车一进一（右车前进1步）', () {
        final move = const MoveRecord(from: Coord(8, 0), to: Coord(8, 1), pieceType: PieceType.rook, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '车一进一');
      });
      test('车一进三（右车前进3步）', () {
        final move = const MoveRecord(from: Coord(8, 0), to: Coord(8, 3), pieceType: PieceType.rook, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '车一进三');
      });
      test('车一退一（右车后退1步，从row=1退到row=0）', () {
        board.movePiece(Coord(8, 0), Coord(8, 1));
        final move = const MoveRecord(from: Coord(8, 1), to: Coord(8, 0), pieceType: PieceType.rook, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '车一退一');
      });
      test('车九进一（左车前进1步）', () {
        final move = const MoveRecord(from: Coord(0, 0), to: Coord(0, 1), pieceType: PieceType.rook, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '车九进一');
      });
      test('车九平八（左车平移）', () {
        final move = const MoveRecord(from: Coord(0, 0), to: Coord(1, 0), pieceType: PieceType.rook, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '车九平八');
      });
    });

    group('红马(N)', () {
      test('马二进三（右马前进）', () {
        final move = const MoveRecord(from: Coord(7, 0), to: Coord(6, 2), pieceType: PieceType.knight, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '马二进三');
      });
      test('马八进七（左马前进）', () {
        final move = const MoveRecord(from: Coord(1, 0), to: Coord(2, 2), pieceType: PieceType.knight, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '马八进七');
      });
      test('马二退三（右马后退，从col=7,row=2退到col=6,row=0）', () {
        board.movePiece(Coord(7, 0), Coord(7, 2));
        final move = const MoveRecord(from: Coord(7, 2), to: Coord(6, 0), pieceType: PieceType.knight, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '马二退三');
      });
      test('马八退七（左马后退，从col=1,row=2退到col=2,row=0）', () {
        board.movePiece(Coord(1, 0), Coord(1, 2));
        final move = const MoveRecord(from: Coord(1, 2), to: Coord(2, 0), pieceType: PieceType.knight, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '马八退七');
      });
      test('马八进六（左马跳到6路）', () {
        final move = const MoveRecord(from: Coord(1, 0), to: Coord(3, 1), pieceType: PieceType.knight, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '马八进六');
      });
    });

    group('红相(B)', () {
      test('相七进五（左相飞到中路）', () {
        final move = const MoveRecord(from: Coord(2, 0), to: Coord(4, 2), pieceType: PieceType.bishop, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '相七进五');
      });
      test('相三进五（右相飞到中路）', () {
        final move = const MoveRecord(from: Coord(6, 0), to: Coord(4, 2), pieceType: PieceType.bishop, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '相三进五');
      });
      test('相三退一（右相退到边路）', () {
        // 右相在file=3(col=6)，退到file=1(col=8)
        board.movePiece(Coord(6, 0), Coord(4, 2)); // 飞到中路
        board.movePiece(Coord(4, 2), Coord(6, 4)); // 飞到三路高位
        final move = const MoveRecord(from: Coord(6, 4), to: Coord(8, 2), pieceType: PieceType.bishop, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '相三退一');
      });
      test('相七退九（左相退到边路）', () {
        // 左相在file=7(col=2)，退到file=9(col=0)
        board.movePiece(Coord(2, 0), Coord(4, 2)); // 飞到中路
        board.movePiece(Coord(4, 2), Coord(2, 4)); // 飞到七路高位
        final move = const MoveRecord(from: Coord(2, 4), to: Coord(0, 2), pieceType: PieceType.bishop, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '相七退九');
      });
    });

    group('红仕(A)', () {
      test('仕四进五（右仕斜进到中路）', () {
        final move = const MoveRecord(from: Coord(5, 0), to: Coord(4, 1), pieceType: PieceType.advisor, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '仕四进五');
      });
      test('仕六进五（左仕斜进到中路）', () {
        final move = const MoveRecord(from: Coord(3, 0), to: Coord(4, 1), pieceType: PieceType.advisor, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '仕六进五');
      });
      test('仕五退四（中路仕退回右路）', () {
        board.movePiece(Coord(5, 0), Coord(4, 1));
        final move = const MoveRecord(from: Coord(4, 1), to: Coord(5, 0), pieceType: PieceType.advisor, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '仕五退四');
      });
      test('仕五退六（中路仕退回左路）', () {
        board.movePiece(Coord(3, 0), Coord(4, 1));
        final move = const MoveRecord(from: Coord(4, 1), to: Coord(3, 0), pieceType: PieceType.advisor, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '仕五退六');
      });
    });

    group('红帅(K)', () {
      test('帅五进一（帅前进1步）', () {
        final move = const MoveRecord(from: Coord(4, 0), to: Coord(4, 1), pieceType: PieceType.king, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '帅五进一');
      });
      test('帅五平四（帅平移到四路）', () {
        final move = const MoveRecord(from: Coord(4, 0), to: Coord(5, 0), pieceType: PieceType.king, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '帅五平四');
      });
      test('帅五平六（帅平移到六路）', () {
        final move = const MoveRecord(from: Coord(4, 0), to: Coord(3, 0), pieceType: PieceType.king, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '帅五平六');
      });
    });

    group('红炮(C)', () {
      test('炮二平五（右炮平到中路）', () {
        final move = const MoveRecord(from: Coord(7, 2), to: Coord(4, 2), pieceType: PieceType.cannon, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '炮二平五');
      });
      test('炮八平五（左炮平到中路）', () {
        final move = const MoveRecord(from: Coord(1, 2), to: Coord(4, 2), pieceType: PieceType.cannon, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '炮八平五');
      });
      test('炮二进四（右炮前进4步）', () {
        final move = const MoveRecord(from: Coord(7, 2), to: Coord(7, 6), pieceType: PieceType.cannon, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '炮二进四');
      });
      test('炮二退一（右炮后退1步）', () {
        final move = const MoveRecord(from: Coord(7, 2), to: Coord(7, 1), pieceType: PieceType.cannon, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '炮二退一');
      });
    });

    group('红兵(P)', () {
      test('兵一进一（右边兵前进）', () {
        final move = const MoveRecord(from: Coord(8, 3), to: Coord(8, 4), pieceType: PieceType.pawn, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '兵一进一');
      });
      test('兵三进一（三路兵前进）', () {
        final move = const MoveRecord(from: Coord(6, 3), to: Coord(6, 4), pieceType: PieceType.pawn, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '兵三进一');
      });
      test('兵七进一（七路兵前进）', () {
        final move = const MoveRecord(from: Coord(2, 3), to: Coord(2, 4), pieceType: PieceType.pawn, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '兵七进一');
      });
      test('兵五进一（中兵前进）', () {
        final move = const MoveRecord(from: Coord(4, 3), to: Coord(4, 4), pieceType: PieceType.pawn, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '兵五进一');
      });
      test('兵三平四（三路兵平移，已过河）', () {
        board.movePiece(Coord(6, 3), Coord(6, 5));
        final move = const MoveRecord(from: Coord(6, 5), to: Coord(5, 5), pieceType: PieceType.pawn, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '兵三平四');
      });
      test('兵三退一（三路兵后退）', () {
        board.movePiece(Coord(6, 3), Coord(6, 5));
        final move = const MoveRecord(from: Coord(6, 5), to: Coord(6, 4), pieceType: PieceType.pawn, color: PieceColor.red);
        expect(ChineseNotation.toText(board.pieces, move), '兵三退一');
      });
    });
  });

  group('全棋子覆盖 - 黑方所有棋子', () {
    late Board board;

    setUp(() {
      board = Board();
      board.initialize();
    });

    group('黑车(r)', () {
      test('车１进１（右车前进1步）', () {
        final move = const MoveRecord(from: Coord(0, 9), to: Coord(0, 8), pieceType: PieceType.rook, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '车1进1');
      });
      test('车１进３（右车前进3步）', () {
        final move = const MoveRecord(from: Coord(0, 9), to: Coord(0, 6), pieceType: PieceType.rook, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '车1进3');
      });
      test('车１退１（右车后退1步）', () {
        board.movePiece(Coord(0, 9), Coord(0, 8));
        final move = const MoveRecord(from: Coord(0, 8), to: Coord(0, 9), pieceType: PieceType.rook, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '车1退1');
      });
      test('车９进１（左车前进1步）', () {
        final move = const MoveRecord(from: Coord(8, 9), to: Coord(8, 8), pieceType: PieceType.rook, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '车9进1');
      });
      test('车９平８（左车平移）', () {
        final move = const MoveRecord(from: Coord(8, 9), to: Coord(7, 9), pieceType: PieceType.rook, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '车9平8');
      });
    });

    group('黑马(n)', () {
      test('马２进３（右马前进）', () {
        final move = const MoveRecord(from: Coord(1, 9), to: Coord(2, 7), pieceType: PieceType.knight, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '马2进3');
      });
      test('马８进７（左马前进）', () {
        final move = const MoveRecord(from: Coord(7, 9), to: Coord(6, 7), pieceType: PieceType.knight, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '马8进7');
      });
      test('马２退３（右马后退）', () {
        board.movePiece(Coord(1, 9), Coord(1, 7));
        final move = const MoveRecord(from: Coord(1, 7), to: Coord(2, 9), pieceType: PieceType.knight, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '马2退3');
      });
      test('马８退７（左马后退）', () {
        board.movePiece(Coord(7, 9), Coord(7, 7));
        final move = const MoveRecord(from: Coord(7, 7), to: Coord(6, 9), pieceType: PieceType.knight, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '马8退7');
      });
    });

    group('黑象(b)', () {
      test('象３进５（右象飞到中路）', () {
        final move = const MoveRecord(from: Coord(2, 9), to: Coord(4, 7), pieceType: PieceType.bishop, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '象3进5');
      });
      test('象７进５（左象飞到中路）', () {
        final move = const MoveRecord(from: Coord(6, 9), to: Coord(4, 7), pieceType: PieceType.bishop, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '象7进5');
      });
      test('象５退３（中路象退回右路）', () {
        board.movePiece(Coord(2, 9), Coord(4, 7));
        final move = const MoveRecord(from: Coord(4, 7), to: Coord(2, 9), pieceType: PieceType.bishop, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '象5退3');
      });
      test('象５退７（中路象退回左路）', () {
        board.movePiece(Coord(6, 9), Coord(4, 7));
        final move = const MoveRecord(from: Coord(4, 7), to: Coord(6, 9), pieceType: PieceType.bishop, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '象5退7');
      });
    });

    group('黑士(a)', () {
      test('士４进５（右士斜进到中路）', () {
        final move = const MoveRecord(from: Coord(3, 9), to: Coord(4, 8), pieceType: PieceType.advisor, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '士4进5');
      });
      test('士６进５（左士斜进到中路）', () {
        final move = const MoveRecord(from: Coord(5, 9), to: Coord(4, 8), pieceType: PieceType.advisor, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '士6进5');
      });
      test('士５退４（中路士退回右路）', () {
        board.movePiece(Coord(3, 9), Coord(4, 8));
        final move = const MoveRecord(from: Coord(4, 8), to: Coord(3, 9), pieceType: PieceType.advisor, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '士5退4');
      });
      test('士５退６（中路士退回左路）', () {
        board.movePiece(Coord(5, 9), Coord(4, 8));
        final move = const MoveRecord(from: Coord(4, 8), to: Coord(5, 9), pieceType: PieceType.advisor, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '士5退6');
      });
    });

    group('黑将(k)', () {
      test('将５进１（将前进1步）', () {
        final move = const MoveRecord(from: Coord(4, 9), to: Coord(4, 8), pieceType: PieceType.king, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '将5进1');
      });
      test('将５平４（将平移到4路）', () {
        final move = const MoveRecord(from: Coord(4, 9), to: Coord(3, 9), pieceType: PieceType.king, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '将5平4');
      });
      test('将５平６（将平移到6路）', () {
        final move = const MoveRecord(from: Coord(4, 9), to: Coord(5, 9), pieceType: PieceType.king, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '将5平6');
      });
    });

    group('黑炮(c)', () {
      test('炮８平５（左炮平到中路）', () {
        final move = const MoveRecord(from: Coord(7, 7), to: Coord(4, 7), pieceType: PieceType.cannon, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '炮8平5');
      });
      test('炮２平５（右炮平到中路）', () {
        final move = const MoveRecord(from: Coord(1, 7), to: Coord(4, 7), pieceType: PieceType.cannon, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '炮2平5');
      });
      test('炮８进４（左炮前进4步）', () {
        final move = const MoveRecord(from: Coord(7, 7), to: Coord(7, 3), pieceType: PieceType.cannon, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '炮8进4');
      });
      test('炮２进４（右炮前进4步）', () {
        final move = const MoveRecord(from: Coord(1, 7), to: Coord(1, 3), pieceType: PieceType.cannon, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '炮2进4');
      });
      test('炮８退１（左炮后退1步）', () {
        final move = const MoveRecord(from: Coord(7, 7), to: Coord(7, 8), pieceType: PieceType.cannon, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '炮8退1');
      });
    });

    group('黑卒(p)', () {
      test('卒１进１（右边卒前进）', () {
        final move = const MoveRecord(from: Coord(0, 6), to: Coord(0, 5), pieceType: PieceType.pawn, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '卒1进1');
      });
      test('卒３进１（三路卒前进）', () {
        final move = const MoveRecord(from: Coord(2, 6), to: Coord(2, 5), pieceType: PieceType.pawn, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '卒3进1');
      });
      test('卒７进１（七路卒前进）', () {
        final move = const MoveRecord(from: Coord(6, 6), to: Coord(6, 5), pieceType: PieceType.pawn, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '卒7进1');
      });
      test('卒５进１（中卒前进）', () {
        final move = const MoveRecord(from: Coord(4, 6), to: Coord(4, 5), pieceType: PieceType.pawn, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '卒5进1');
      });
      test('卒３平４（三路卒平移，已过河）', () {
        board.movePiece(Coord(2, 6), Coord(2, 4));
        final move = const MoveRecord(from: Coord(2, 4), to: Coord(3, 4), pieceType: PieceType.pawn, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '卒3平4');
      });
      test('卒３退１（三路卒后退）', () {
        board.movePiece(Coord(2, 6), Coord(2, 4));
        final move = const MoveRecord(from: Coord(2, 4), to: Coord(2, 5), pieceType: PieceType.pawn, color: PieceColor.black);
        expect(ChineseNotation.toText(board.pieces, move), '卒3退1');
      });
    });
  });

  // ============================================================
  // 异常 & 边界条件测试
  // ============================================================

  group('异常 & 边界 - 同线多子前缀（红方）', () {
    late Board board;

    setUp(() {
      board = Board();
      board.clear();
    });

    test('同线双车 - 前车进一（row 大的在前）', () {
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.red, coord: const Coord(7, 2)));
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.red, coord: const Coord(7, 4)));
      final move = const MoveRecord(from: Coord(7, 4), to: Coord(7, 5), pieceType: PieceType.rook, color: PieceColor.red);
      expect(ChineseNotation.toText(board.pieces, move), '前车进一');
    });

    test('同线双车 - 后车进一（row 小的在后）', () {
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.red, coord: const Coord(7, 2)));
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.red, coord: const Coord(7, 4)));
      final move = const MoveRecord(from: Coord(7, 2), to: Coord(7, 3), pieceType: PieceType.rook, color: PieceColor.red);
      expect(ChineseNotation.toText(board.pieces, move), '后车进一');
    });

    test('同线三兵 - 前兵平五（最多可有5个兵）', () {
      board.putPiece(ChessPiece(type: PieceType.pawn, color: PieceColor.red, coord: const Coord(4, 2)));
      board.putPiece(ChessPiece(type: PieceType.pawn, color: PieceColor.red, coord: const Coord(4, 4)));
      board.putPiece(ChessPiece(type: PieceType.pawn, color: PieceColor.red, coord: const Coord(4, 6)));
      // 前兵在col=4(row=6)，file=5，平到col=3(file=6) → 前兵平六
      final move = const MoveRecord(from: Coord(4, 6), to: Coord(3, 6), pieceType: PieceType.pawn, color: PieceColor.red);
      expect(ChineseNotation.toText(board.pieces, move), '前兵平六');
    });

    test('同线三兵 - 中兵平五', () {
      board.putPiece(ChessPiece(type: PieceType.pawn, color: PieceColor.red, coord: const Coord(4, 2)));
      board.putPiece(ChessPiece(type: PieceType.pawn, color: PieceColor.red, coord: const Coord(4, 4)));
      board.putPiece(ChessPiece(type: PieceType.pawn, color: PieceColor.red, coord: const Coord(4, 6)));
      // 中兵在col=4(row=4)，file=5，平到col=3(file=6) → 中兵平六
      final move = const MoveRecord(from: Coord(4, 4), to: Coord(3, 4), pieceType: PieceType.pawn, color: PieceColor.red);
      expect(ChineseNotation.toText(board.pieces, move), '中兵平六');
    });

    test('同线三兵 - 后兵平五', () {
      board.putPiece(ChessPiece(type: PieceType.pawn, color: PieceColor.red, coord: const Coord(4, 2)));
      board.putPiece(ChessPiece(type: PieceType.pawn, color: PieceColor.red, coord: const Coord(4, 4)));
      board.putPiece(ChessPiece(type: PieceType.pawn, color: PieceColor.red, coord: const Coord(4, 6)));
      // 后兵在col=4(row=2)，file=5，平到col=3(file=6) → 后兵平六
      final move = const MoveRecord(from: Coord(4, 2), to: Coord(3, 2), pieceType: PieceType.pawn, color: PieceColor.red);
      expect(ChineseNotation.toText(board.pieces, move), '后兵平六');
    });

    test('同线双马 - 前马进四', () {
      board.putPiece(ChessPiece(type: PieceType.knight, color: PieceColor.red, coord: const Coord(6, 0)));
      board.putPiece(ChessPiece(type: PieceType.knight, color: PieceColor.red, coord: const Coord(6, 2)));
      final move = const MoveRecord(from: Coord(6, 2), to: Coord(5, 4), pieceType: PieceType.knight, color: PieceColor.red);
      expect(ChineseNotation.toText(board.pieces, move), '前马进四');
    });

    test('同线双马 - 后马进四', () {
      board.putPiece(ChessPiece(type: PieceType.knight, color: PieceColor.red, coord: const Coord(6, 0)));
      board.putPiece(ChessPiece(type: PieceType.knight, color: PieceColor.red, coord: const Coord(6, 2)));
      final move = const MoveRecord(from: Coord(6, 0), to: Coord(5, 2), pieceType: PieceType.knight, color: PieceColor.red);
      expect(ChineseNotation.toText(board.pieces, move), '后马进四');
    });
  });

  group('异常 & 边界 - 同线多子前缀（黑方）', () {
    late Board board;

    setUp(() {
      board = Board();
      board.clear();
    });

    test('黑方同线双车 - 前车进1（row 小的在前）', () {
      // 黑方：row 越小越靠近红方（前方）
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.black, coord: const Coord(1, 9)));
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.black, coord: const Coord(1, 7)));
      final move = const MoveRecord(from: Coord(1, 7), to: Coord(1, 6), pieceType: PieceType.rook, color: PieceColor.black);
      expect(ChineseNotation.toText(board.pieces, move), '前车进1');
    });

    test('黑方同线双车 - 后车进1（row 大的在后）', () {
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.black, coord: const Coord(1, 9)));
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.black, coord: const Coord(1, 7)));
      final move = const MoveRecord(from: Coord(1, 9), to: Coord(1, 8), pieceType: PieceType.rook, color: PieceColor.black);
      expect(ChineseNotation.toText(board.pieces, move), '后车进1');
    });

    test('黑方同线双炮 - 前炮平5', () {
      board.putPiece(ChessPiece(type: PieceType.cannon, color: PieceColor.black, coord: const Coord(7, 9)));
      board.putPiece(ChessPiece(type: PieceType.cannon, color: PieceColor.black, coord: const Coord(7, 7)));
      final move = const MoveRecord(from: Coord(7, 7), to: Coord(4, 7), pieceType: PieceType.cannon, color: PieceColor.black);
      expect(ChineseNotation.toText(board.pieces, move), '前炮平5');
    });

    test('黑方同线双炮 - 后炮平5', () {
      board.putPiece(ChessPiece(type: PieceType.cannon, color: PieceColor.black, coord: const Coord(7, 9)));
      board.putPiece(ChessPiece(type: PieceType.cannon, color: PieceColor.black, coord: const Coord(7, 7)));
      final move = const MoveRecord(from: Coord(7, 9), to: Coord(4, 9), pieceType: PieceType.cannon, color: PieceColor.black);
      expect(ChineseNotation.toText(board.pieces, move), '后炮平5');
    });

    test('黑方不同纵线 - 不需要前缀', () {
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.black, coord: const Coord(0, 9)));
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.black, coord: const Coord(8, 9)));
      // 两个车在不同纵线，移动不需要前缀
      final move = const MoveRecord(from: Coord(8, 9), to: Coord(8, 8), pieceType: PieceType.rook, color: PieceColor.black);
      expect(ChineseNotation.toText(board.pieces, move), '车9进1');
      expect(ChineseNotation.toText(board.pieces, move).startsWith('前'), isFalse);
    });
  });

  group('异常 & 边界 - WXF round-trip 全覆盖', () {
    late Board board;

    setUp(() {
      board = Board();
      board.clear();
    });

    test('红车 round-trip: 车一进三', () {
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.red, coord: const Coord(8, 0)));
      final move = const MoveRecord(from: Coord(8, 0), to: Coord(8, 3), pieceType: PieceType.rook, color: PieceColor.red);
      final wxf = ChineseNotation.toWXF(board.pieces, move);
      expect(wxf, 'R1+3');
      final result = ChineseNotation.fromWXF(board.pieces, wxf, PieceColor.red);
      expect(result, isNotNull);
      final (from, to) = result!;
      expect(from, move.from);
      expect(to, move.to);
    });

    test('红马 round-trip: 马二进三', () {
      board.putPiece(ChessPiece(type: PieceType.knight, color: PieceColor.red, coord: const Coord(7, 0)));
      final move = const MoveRecord(from: Coord(7, 0), to: Coord(6, 2), pieceType: PieceType.knight, color: PieceColor.red);
      final wxf = ChineseNotation.toWXF(board.pieces, move);
      expect(wxf, 'N2+3');
      final result = ChineseNotation.fromWXF(board.pieces, wxf, PieceColor.red);
      expect(result, isNotNull);
      final (from, to) = result!;
      expect(from, move.from);
      expect(to, move.to);
    });

    test('红相 round-trip: 相七进五', () {
      board.putPiece(ChessPiece(type: PieceType.bishop, color: PieceColor.red, coord: const Coord(2, 0)));
      final move = const MoveRecord(from: Coord(2, 0), to: Coord(4, 2), pieceType: PieceType.bishop, color: PieceColor.red);
      final wxf = ChineseNotation.toWXF(board.pieces, move);
      expect(wxf, 'B7+5');
      final result = ChineseNotation.fromWXF(board.pieces, wxf, PieceColor.red);
      expect(result, isNotNull);
      final (from, to) = result!;
      expect(from, move.from);
      expect(to, move.to);
    });

    test('红仕 round-trip: 仕四进五', () {
      board.putPiece(ChessPiece(type: PieceType.advisor, color: PieceColor.red, coord: const Coord(5, 0)));
      final move = const MoveRecord(from: Coord(5, 0), to: Coord(4, 1), pieceType: PieceType.advisor, color: PieceColor.red);
      final wxf = ChineseNotation.toWXF(board.pieces, move);
      expect(wxf, 'A4+5');
      final result = ChineseNotation.fromWXF(board.pieces, wxf, PieceColor.red);
      expect(result, isNotNull);
      final (from, to) = result!;
      expect(from, move.from);
      expect(to, move.to);
    });

    test('红帅 round-trip: 帅五进一', () {
      board.putPiece(ChessPiece(type: PieceType.king, color: PieceColor.red, coord: const Coord(4, 0)));
      final move = const MoveRecord(from: Coord(4, 0), to: Coord(4, 1), pieceType: PieceType.king, color: PieceColor.red);
      final wxf = ChineseNotation.toWXF(board.pieces, move);
      expect(wxf, 'K5+1');
      final result = ChineseNotation.fromWXF(board.pieces, wxf, PieceColor.red);
      expect(result, isNotNull);
      final (from, to) = result!;
      expect(from, move.from);
      expect(to, move.to);
    });

    test('红炮 round-trip: 炮二平五', () {
      board.putPiece(ChessPiece(type: PieceType.cannon, color: PieceColor.red, coord: const Coord(7, 2)));
      final move = const MoveRecord(from: Coord(7, 2), to: Coord(4, 2), pieceType: PieceType.cannon, color: PieceColor.red);
      final wxf = ChineseNotation.toWXF(board.pieces, move);
      expect(wxf, 'C2.5');
      final result = ChineseNotation.fromWXF(board.pieces, wxf, PieceColor.red);
      expect(result, isNotNull);
      final (from, to) = result!;
      expect(from, move.from);
      expect(to, move.to);
    });

    test('红兵 round-trip: 兵七进一', () {
      board.putPiece(ChessPiece(type: PieceType.pawn, color: PieceColor.red, coord: const Coord(2, 3)));
      final move = const MoveRecord(from: Coord(2, 3), to: Coord(2, 4), pieceType: PieceType.pawn, color: PieceColor.red);
      final wxf = ChineseNotation.toWXF(board.pieces, move);
      expect(wxf, 'P7+1');
      final result = ChineseNotation.fromWXF(board.pieces, wxf, PieceColor.red);
      expect(result, isNotNull);
      final (from, to) = result!;
      expect(from, move.from);
      expect(to, move.to);
    });

    test('黑车 round-trip: 车9进1', () {
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.black, coord: const Coord(8, 9)));
      final move = const MoveRecord(from: Coord(8, 9), to: Coord(8, 8), pieceType: PieceType.rook, color: PieceColor.black);
      final wxf = ChineseNotation.toWXF(board.pieces, move);
      expect(wxf, 'R9+1');
      final result = ChineseNotation.fromWXF(board.pieces, wxf, PieceColor.black);
      expect(result, isNotNull);
      final (from, to) = result!;
      expect(from, move.from);
      expect(to, move.to);
    });

    test('黑马 round-trip: 马8进7', () {
      board.putPiece(ChessPiece(type: PieceType.knight, color: PieceColor.black, coord: const Coord(7, 9)));
      final move = const MoveRecord(from: Coord(7, 9), to: Coord(6, 7), pieceType: PieceType.knight, color: PieceColor.black);
      final wxf = ChineseNotation.toWXF(board.pieces, move);
      expect(wxf, 'N8+7');
      final result = ChineseNotation.fromWXF(board.pieces, wxf, PieceColor.black);
      expect(result, isNotNull);
      final (from, to) = result!;
      expect(from, move.from);
      expect(to, move.to);
    });

    test('黑炮 round-trip: 炮8平5', () {
      board.putPiece(ChessPiece(type: PieceType.cannon, color: PieceColor.black, coord: const Coord(7, 7)));
      final move = const MoveRecord(from: Coord(7, 7), to: Coord(4, 7), pieceType: PieceType.cannon, color: PieceColor.black);
      final wxf = ChineseNotation.toWXF(board.pieces, move);
      expect(wxf, 'C8.5');
      final result = ChineseNotation.fromWXF(board.pieces, wxf, PieceColor.black);
      expect(result, isNotNull);
      final (from, to) = result!;
      expect(from, move.from);
      expect(to, move.to);
    });

    test('黑卒 round-trip: 卒3进1', () {
      board.putPiece(ChessPiece(type: PieceType.pawn, color: PieceColor.black, coord: const Coord(2, 6)));
      final move = const MoveRecord(from: Coord(2, 6), to: Coord(2, 5), pieceType: PieceType.pawn, color: PieceColor.black);
      final wxf = ChineseNotation.toWXF(board.pieces, move);
      expect(wxf, 'P3+1');
      final result = ChineseNotation.fromWXF(board.pieces, wxf, PieceColor.black);
      expect(result, isNotNull);
      final (from, to) = result!;
      expect(from, move.from);
      expect(to, move.to);
    });
  });

  group('异常 & 边界 - WXF 解析异常处理', () {
    late Board board;

    setUp(() {
      board = Board();
      board.initialize();
    });

    test('空字符串返回 null', () {
      expect(ChineseNotation.fromWXF(board.pieces, '', PieceColor.red), isNull);
    });

    test('单字符返回 null', () {
      expect(ChineseNotation.fromWXF(board.pieces, 'C', PieceColor.red), isNull);
    });

    test('两个字符返回 null', () {
      expect(ChineseNotation.fromWXF(board.pieces, 'C2', PieceColor.red), isNull);
    });

    test('无效棋子字母返回 null', () {
      expect(ChineseNotation.fromWXF(board.pieces, 'X2.5', PieceColor.red), isNull);
    });

    test('无效纵线数字返回 null', () {
      expect(ChineseNotation.fromWXF(board.pieces, 'C0.5', PieceColor.red), isNull);
      expect(ChineseNotation.fromWXF(board.pieces, 'C10.5', PieceColor.red), isNull);
    });

    test('无效方向符号返回 null', () {
      expect(ChineseNotation.fromWXF(board.pieces, 'C2x5', PieceColor.red), isNull);
      expect(ChineseNotation.fromWXF(board.pieces, 'C2!5', PieceColor.red), isNull);
    });

    test('纵线超出棋盘范围找不到棋子返回 null', () {
      // 红方一路有车，但九路没有马
      expect(ChineseNotation.fromWXF(board.pieces, 'N9+7', PieceColor.red), isNull);
    });

    test('不存在的棋子类型返回 null', () {
      expect(ChineseNotation.fromWXF(board.pieces, 'Q2.5', PieceColor.red), isNull);
    });
  });

  group('异常 & 边界 - 繁体中文全覆盖', () {
    late Board board;

    setUp(() {
      board = Board();
      board.initialize();
    });

    test('红帅→将（繁体）', () {
      final move = const MoveRecord(from: Coord(4, 0), to: Coord(4, 1), pieceType: PieceType.king, color: PieceColor.red);
      // 红方繁体：帥
      expect(ChineseNotation.toText(board.pieces, move, useSimpleText: false), '帥五进一');
    });

    test('红仕→仕（繁体不变）', () {
      final move = const MoveRecord(from: Coord(5, 0), to: Coord(4, 1), pieceType: PieceType.advisor, color: PieceColor.red);
      expect(ChineseNotation.toText(board.pieces, move, useSimpleText: false), '仕四进五');
    });

    test('红相→相（繁体不变）', () {
      final move = const MoveRecord(from: Coord(2, 0), to: Coord(4, 2), pieceType: PieceType.bishop, color: PieceColor.red);
      expect(ChineseNotation.toText(board.pieces, move, useSimpleText: false), '相七进五');
    });

    test('红马→傌（繁体）', () {
      final move = const MoveRecord(from: Coord(7, 0), to: Coord(6, 2), pieceType: PieceType.knight, color: PieceColor.red);
      expect(ChineseNotation.toText(board.pieces, move, useSimpleText: false), '傌二进三');
    });

    test('红车→俥（繁体）', () {
      final move = const MoveRecord(from: Coord(8, 0), to: Coord(8, 1), pieceType: PieceType.rook, color: PieceColor.red);
      expect(ChineseNotation.toText(board.pieces, move, useSimpleText: false), '俥一进一');
    });

    test('红炮→砲（繁体）', () {
      final move = const MoveRecord(from: Coord(7, 2), to: Coord(4, 2), pieceType: PieceType.cannon, color: PieceColor.red);
      expect(ChineseNotation.toText(board.pieces, move, useSimpleText: false), '砲二平五');
    });

    test('红兵→兵（繁体不变）', () {
      final move = const MoveRecord(from: Coord(2, 3), to: Coord(2, 4), pieceType: PieceType.pawn, color: PieceColor.red);
      expect(ChineseNotation.toText(board.pieces, move, useSimpleText: false), '兵七进一');
    });

    test('黑将→將（繁体）', () {
      final move = const MoveRecord(from: Coord(4, 9), to: Coord(4, 8), pieceType: PieceType.king, color: PieceColor.black);
      expect(ChineseNotation.toText(board.pieces, move, useSimpleText: false), '將5进1');
    });

    test('黑士→士（繁体不变）', () {
      final move = const MoveRecord(from: Coord(3, 9), to: Coord(4, 8), pieceType: PieceType.advisor, color: PieceColor.black);
      expect(ChineseNotation.toText(board.pieces, move, useSimpleText: false), '士4进5');
    });

    test('黑象→象（繁体不变）', () {
      final move = const MoveRecord(from: Coord(2, 9), to: Coord(4, 7), pieceType: PieceType.bishop, color: PieceColor.black);
      expect(ChineseNotation.toText(board.pieces, move, useSimpleText: false), '象3进5');
    });

    test('黑马→馬（繁体）', () {
      final move = const MoveRecord(from: Coord(7, 9), to: Coord(6, 7), pieceType: PieceType.knight, color: PieceColor.black);
      expect(ChineseNotation.toText(board.pieces, move, useSimpleText: false), '馬8进7');
    });

    test('黑车→車（繁体）', () {
      final move = const MoveRecord(from: Coord(8, 9), to: Coord(8, 8), pieceType: PieceType.rook, color: PieceColor.black);
      expect(ChineseNotation.toText(board.pieces, move, useSimpleText: false), '車9进1');
    });

    test('黑炮→砲（繁体）', () {
      final move = const MoveRecord(from: Coord(7, 7), to: Coord(4, 7), pieceType: PieceType.cannon, color: PieceColor.black);
      expect(ChineseNotation.toText(board.pieces, move, useSimpleText: false), '砲8平5');
    });

    test('黑卒→卒（繁体不变）', () {
      final move = const MoveRecord(from: Coord(2, 6), to: Coord(2, 5), pieceType: PieceType.pawn, color: PieceColor.black);
      expect(ChineseNotation.toText(board.pieces, move, useSimpleText: false), '卒3进1');
    });
  });

  group('异常 & 边界 - 边界坐标', () {
    late Board board;

    setUp(() {
      board = Board();
      board.clear();
    });

    test('红方最左边 col=0 = 九路', () {
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.red, coord: const Coord(0, 0)));
      final move = const MoveRecord(from: Coord(0, 0), to: Coord(0, 1), pieceType: PieceType.rook, color: PieceColor.red);
      expect(ChineseNotation.toText(board.pieces, move), '车九进一');
      expect(ChineseNotation.toWXF(board.pieces, move), 'R9+1');
    });

    test('红方最右边 col=8 = 一路', () {
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.red, coord: const Coord(8, 0)));
      final move = const MoveRecord(from: Coord(8, 0), to: Coord(8, 1), pieceType: PieceType.rook, color: PieceColor.red);
      expect(ChineseNotation.toText(board.pieces, move), '车一进一');
      expect(ChineseNotation.toWXF(board.pieces, move), 'R1+1');
    });

    test('红方中路 col=4 = 五路', () {
      board.putPiece(ChessPiece(type: PieceType.king, color: PieceColor.red, coord: const Coord(4, 0)));
      final move = const MoveRecord(from: Coord(4, 0), to: Coord(4, 1), pieceType: PieceType.king, color: PieceColor.red);
      expect(ChineseNotation.toText(board.pieces, move), '帅五进一');
    });

    test('黑方最左边 col=0 = 1路', () {
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.black, coord: const Coord(0, 9)));
      final move = const MoveRecord(from: Coord(0, 9), to: Coord(0, 8), pieceType: PieceType.rook, color: PieceColor.black);
      expect(ChineseNotation.toText(board.pieces, move), '车1进1');
    });

    test('黑方最右边 col=8 = 9路', () {
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.black, coord: const Coord(8, 9)));
      final move = const MoveRecord(from: Coord(8, 9), to: Coord(8, 8), pieceType: PieceType.rook, color: PieceColor.black);
      expect(ChineseNotation.toText(board.pieces, move), '车9进1');
    });

    test('黑方中路 col=4 = 5路', () {
      board.putPiece(ChessPiece(type: PieceType.king, color: PieceColor.black, coord: const Coord(4, 9)));
      final move = const MoveRecord(from: Coord(4, 9), to: Coord(4, 8), pieceType: PieceType.king, color: PieceColor.black);
      expect(ChineseNotation.toText(board.pieces, move), '将5进1');
    });
  });

  group('异常 & 边界 - 过河卒/兵平移', () {
    late Board board;

    setUp(() {
      board = Board();
      board.clear();
    });

    test('红兵过河后左平（col 增大）', () {
      board.putPiece(ChessPiece(type: PieceType.pawn, color: PieceColor.red, coord: const Coord(4, 5)));
      // 五路兵平到四路
      final move = const MoveRecord(from: Coord(4, 5), to: Coord(5, 5), pieceType: PieceType.pawn, color: PieceColor.red);
      expect(ChineseNotation.toText(board.pieces, move), '兵五平四');
    });

    test('红兵过河后右平（col 减小）', () {
      board.putPiece(ChessPiece(type: PieceType.pawn, color: PieceColor.red, coord: const Coord(4, 5)));
      final move = const MoveRecord(from: Coord(4, 5), to: Coord(3, 5), pieceType: PieceType.pawn, color: PieceColor.red);
      expect(ChineseNotation.toText(board.pieces, move), '兵五平六');
    });

    test('黑卒过河后左平（col 减小）', () {
      board.putPiece(ChessPiece(type: PieceType.pawn, color: PieceColor.black, coord: const Coord(4, 4)));
      // 5路卒平到4路
      final move = const MoveRecord(from: Coord(4, 4), to: Coord(3, 4), pieceType: PieceType.pawn, color: PieceColor.black);
      expect(ChineseNotation.toText(board.pieces, move), '卒5平4');
    });

    test('黑卒过河后右平（col 增大）', () {
      board.putPiece(ChessPiece(type: PieceType.pawn, color: PieceColor.black, coord: const Coord(4, 4)));
      final move = const MoveRecord(from: Coord(4, 4), to: Coord(5, 4), pieceType: PieceType.pawn, color: PieceColor.black);
      expect(ChineseNotation.toText(board.pieces, move), '卒5平6');
    });
  });

  group('异常 & 边界 - normalize/denormalize 互逆验证', () {
    test('红方坐标 normalize 不变', () {
      final coord = const Coord(4, 3);
      final normalized = ChineseNotation.normalizeCoord(coord, PieceColor.red);
      expect(normalized, coord);
    });

    test('黑方坐标 normalize 旋转180度', () {
      final coord = const Coord(7, 9);
      final normalized = ChineseNotation.normalizeCoord(coord, PieceColor.black);
      expect(normalized.col, 1); // 8 - 7 = 1
      expect(normalized.row, 0); // 9 - 9 = 0
    });

    test('黑方 normalize + denormalize 回到原点', () {
      final original = const Coord(7, 9);
      final normalized = ChineseNotation.normalizeCoord(original, PieceColor.black);
      final denormalized = ChineseNotation.denormalizeCoord(normalized, PieceColor.black);
      expect(denormalized, original);
    });

    test('红方 denormalize 不变', () {
      final coord = const Coord(4, 3);
      final denormalized = ChineseNotation.denormalizeCoord(coord, PieceColor.red);
      expect(denormalized, coord);
    });

    test('黑方走法 normalize 后计算再 denormalize 回原坐标', () {
      final move = const MoveRecord(
        from: Coord(7, 9),
        to: Coord(6, 7),
        pieceType: PieceType.knight,
        color: PieceColor.black,
      );
      final normalized = ChineseNotation.normalizeMove(move);
      expect(normalized.from.col, 1);
      expect(normalized.from.row, 0);
      expect(normalized.to.col, 2);
      expect(normalized.to.row, 2);

      final denormFrom = ChineseNotation.denormalizeCoord(normalized.from, PieceColor.black);
      final denormTo = ChineseNotation.denormalizeCoord(normalized.to, PieceColor.black);
      expect(denormFrom, move.from);
      expect(denormTo, move.to);
    });
  });

  group('异常 & 边界 - 吃子记谱', () {
    late Board board;

    setUp(() {
      board = Board();
      board.clear();
    });

    test('红车吃子（车二进三吃黑马）', () {
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.red, coord: const Coord(7, 0)));
      board.putPiece(ChessPiece(type: PieceType.knight, color: PieceColor.black, coord: const Coord(7, 3)));
      final move = const MoveRecord(
        from: Coord(7, 0),
        to: Coord(7, 3),
        pieceType: PieceType.rook,
        color: PieceColor.red,
        capturedPiece: ChessPiece(type: PieceType.knight, color: PieceColor.black, coord: Coord(7, 3)),
      );
      // 中文记谱中吃子不特别标记，只显示走法
      expect(ChineseNotation.toText(board.pieces, move), '车二进三');
    });

    test('黑炮吃子（炮8进5打红车）', () {
      board.putPiece(ChessPiece(type: PieceType.cannon, color: PieceColor.black, coord: const Coord(7, 7)));
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.red, coord: const Coord(7, 2)));
      final move = const MoveRecord(
        from: Coord(7, 7),
        to: Coord(7, 2),
        pieceType: PieceType.cannon,
        color: PieceColor.black,
        capturedPiece: ChessPiece(type: PieceType.rook, color: PieceColor.red, coord: Coord(7, 2)),
      );
      expect(ChineseNotation.toText(board.pieces, move), '炮8进5');
    });

    test('红马吃子（马二进三吃黑卒）', () {
      board.putPiece(ChessPiece(type: PieceType.knight, color: PieceColor.red, coord: const Coord(7, 0)));
      board.putPiece(ChessPiece(type: PieceType.pawn, color: PieceColor.black, coord: const Coord(6, 2)));
      final move = const MoveRecord(
        from: Coord(7, 0),
        to: Coord(6, 2),
        pieceType: PieceType.knight,
        color: PieceColor.red,
        capturedPiece: ChessPiece(type: PieceType.pawn, color: PieceColor.black, coord: Coord(6, 2)),
      );
      expect(ChineseNotation.toText(board.pieces, move), '马二进三');
    });
  });

  group('异常 & 边界 - WXF 前缀 round-trip', () {
    late Board board;

    setUp(() {
      board = Board();
      board.clear();
    });

    test('fR2.5 前车平五 round-trip', () {
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.red, coord: const Coord(7, 2)));
      board.putPiece(ChessPiece(type: PieceType.rook, color: PieceColor.red, coord: const Coord(7, 4)));
      final move = const MoveRecord(from: Coord(7, 4), to: Coord(4, 4), pieceType: PieceType.rook, color: PieceColor.red);
      final wxf = ChineseNotation.toWXF(board.pieces, move);
      expect(wxf, 'fR2.5');
      final result = ChineseNotation.fromWXF(board.pieces, wxf, PieceColor.red);
      expect(result, isNotNull);
      final (from, to) = result!;
      expect(from, move.from);
      expect(to, move.to);
    });

    test('bN2-3 后马退三 round-trip', () {
      board.putPiece(ChessPiece(type: PieceType.knight, color: PieceColor.red, coord: const Coord(7, 0)));
      board.putPiece(ChessPiece(type: PieceType.knight, color: PieceColor.red, coord: const Coord(7, 2)));
      final move = const MoveRecord(from: Coord(7, 0), to: Coord(6, 2), pieceType: PieceType.knight, color: PieceColor.red);
      final wxf = ChineseNotation.toWXF(board.pieces, move);
      expect(wxf.startsWith('b'), isTrue);
      final result = ChineseNotation.fromWXF(board.pieces, wxf, PieceColor.red);
      expect(result, isNotNull);
      final (from, to) = result!;
      expect(from, move.from);
      expect(to, move.to);
    });
  });
}
