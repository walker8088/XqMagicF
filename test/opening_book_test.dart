import 'package:flutter_test/flutter_test.dart';
import 'package:xqmagic/services/opening_book.dart';

void main() {
  group('OpeningBookService.lookup', () {
    setUpAll(() {
      // Trigger singleton initialization.
      OpeningBookService.instance;
    });

    test('内部 _openingBook 至少应有一个开局（验证 FEN 转换逻辑）', () {
      // 至少 1 个开局说明 _openingBook 已正确加载。
      expect(OpeningBookService.instance.size, greaterThan(0));
    });

    test('lookup 应该能命中使用 r 格式的 FEN（开局库内部约定）', () {
      // 初始局面，红方走子，内部存储为 r 格式。
      const initialFenR =
          'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR r';
      final result = OpeningBookService.instance.lookup(initialFenR);
      expect(result, isNotNull, reason: 'r 格式 FEN 应能直接命中开局库');
    });

    test('lookup 应该把 UCI 标准的 w 格式 FEN 归一化为 r 格式后命中开局库', () {
      // FenParser.generate 产出的就是 w 格式。
      const initialFenW =
          'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w';
      final result = OpeningBookService.instance.lookup(initialFenW);
      expect(
        result,
        isNotNull,
        reason: 'w 格式 FEN 归一化后应能命中开局库（修复前的 bug 是永远 miss）',
      );
    });

    test('lookup 缺失走子方的 FEN 时应默认补 r 并命中开局库', () {
      // 没有走子方字段的 FEN：归一化时应该补上 ' r'。
      const fenNoColor =
          'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR';
      final result = OpeningBookService.instance.lookup(fenNoColor);
      expect(result, isNotNull, reason: '缺失走子方时默认补 r 仍能命中');
    });

    test('lookup 未知局面应返回 null（确保前面的命中是真的命中）', () {
      // 一个明显不在开局库中的局面。
      const unknownFen =
          'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR b';
      // 等待一下: 黑方走子的初始局面也不在开局库中（开局库只覆盖红方先手）。
      final result = OpeningBookService.instance.lookup(unknownFen);
      expect(result, isNull, reason: '黑方先手的初始局面不在开局库中');
    });
  });
}
