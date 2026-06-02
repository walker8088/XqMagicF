import 'package:flutter_test/flutter_test.dart';
import 'package:xqmagic/services/pgn_service.dart';

void main() {
  // 防止 PGN tokenizer bug 导致无限循环
  // 历史 bug：`*` 结果会让 tokenizer 死循环
  group('PGNService - 结果标记 tokenization', () {
    test('应正确解析 `*` 单独结果（ongoing），不卡死', () {
      const pgn = '''
[Event "Test"]
[Result "*"]

1. 炮二平五  马8进7 *

''';
      final result = PGNService().parse(pgn);
      // 不应该卡死：本次调用必须返回
      expect(result, isNotNull);
    });

    test('应正确解析 `1-0` 结果', () {
      const pgn = '''
[Event "Test"]
[Result "1-0"]

1. 炮二平五  马8进7 2. 马二进三  车9平8 3. 兵七进一  卒7进1 1-0
''';
      final result = PGNService().parse(pgn);
      expect(result, isNotNull);
      expect(result.games.length, 1);
      // 原断言 `result.toString().contains('red')` 脆：依赖 enum 默认 toString
      // 一旦重命名则退化。直接比 enum 值。
      expect(result.games.first.result, GameResult.redWin);
    });

    test('应正确解析 `0-1` 结果', () {
      const pgn = '''
[Event "Test"]
[Result "0-1"]

1. 炮二平五  马8进7 2. 马二进三  车9平8 3. 兵七进一  炮2进7 0-1
''';
      final result = PGNService().parse(pgn);
      expect(result, isNotNull);
      expect(result.games.length, 1);
    });

    test('应正确解析 `1/2-1/2` 和棋结果', () {
      const pgn = '''
[Event "Test"]
[Result "1/2-1/2"]

1. 炮二平五  马8进7 2. 马二进三  车9平8 3. 车一平二  卒7进1 1/2-1/2
''';
      final result = PGNService().parse(pgn);
      expect(result, isNotNull);
      expect(result.games.length, 1);
    });

    test('应能正确解析 PGN 表头（含中文与特殊字符）', () {
      // 旧 bug：`.*` 贪婪匹配在表头取值时可能越界
      const pgn = '''
[Event "测试对局"]
[Site "测试地点"]

1. 炮二平五  马8进七 *
''';
      final result = PGNService().parse(pgn);
      expect(result, isNotNull);
      expect(result.games.length, 1);
      expect(result.games.first.event, '测试对局');
      expect(result.games.first.site, '测试地点');
    });

    test('应能正确解析混合着法 + 注释 + NAG + 变着', () {
      // 原实现只断言 isNotNull、未检验真正解析结果。
      // 使用真实 ICCS 记法（h2e2 = 炮二平五,h7e7 = 炮8平5,h0g2 = 马二进三）。
      // PGN parser 内部走 ICCS，中文记法不在 pipeline 内。
      const pgn = '''
[Event "Complex"]
[Result "*"]

1. h2e2 {best move} h7e7 (1... h0g2) *
''';
      final result = PGNService().parse(pgn);
      expect(result, isNotNull);
      expect(result.games.length, 1);

      // result 头应被保留。
      expect(result.games.first.event, 'Complex');
      expect(result.games.first.result, GameResult.ongoing);

      // 重点：parse 不应崩溃。如果 pipeline 中任何阶段括沰、NAG、
      // 变着者都是 null/exception，这里会抓到。
      // 原实现仅 isNotNull 太弱。上面两项（event/result）是最低保证。
    });
  });

  group('PGNService - 错误处理', () {
    test('无效的 PGN 应返回错误而非崩溃', () {
      const pgn = 'this is not a pgn file';
      final result = PGNService().parse(pgn);
      // 应返回结果（即使没有任何对局），不抛异常
      expect(result, isNotNull);
    });
  });

  group('PGNService - write / writeSingle', () {
    test('应能序列化空棋谱树（仅写表头 + result）', () {
      final game = GameRecord(
        event: 'Test Event',
        site: 'Test Site',
        result: GameResult.ongoing,
      );
      final text = PGNService().writeSingle(game);
      expect(text, contains('[Event "Test Event"]'));
      expect(text, contains('[Site "Test Site"]'));
      expect(text, contains('*'));
    });

    test('序列化应能正确添加表头引号转义', () {
      final game = GameRecord(
        event: 'Game with "quotes"',
        result: GameResult.ongoing,
      );
      final text = PGNService().writeSingle(game);
      // 内部 " 应转义为 \"
      expect(text, contains(r'[Event "Game with \"quotes\""]'));
    });
  });
}
