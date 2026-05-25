import 'package:flutter_test/flutter_test.dart';
import 'package:xqmagic/services/cloud_db.dart';

void main() {
  group('CloudQueryResult.parseResponse', () {
    test('should parse standard opening position response', () {
      // 标准开局真实返回格式
      const body =
          'move:c3c4,score:1,rank:2,note:! (44-02),winrate:50.08|'
          'move:g3g4,score:1,rank:2,note:! (44-02),winrate:50.08|'
          'move:b2d2,score:0,rank:1,note:* (45-02),winrate:50.00|'
          'move:b2e2,score:0,rank:1,note:* (45-02),winrate:50.00|'
          'move:d0e1,score:-1,rank:1,note:* (44-07),winrate:49.92|'
          'move:b2b4,score:-8,rank:0,note:? (42-01),winrate:49.39';

      final result = CloudQueryResult.parseResponse(body, 'test_fen');

      expect(result, isNotNull);
      expect(result!.moves.length, 6);
      expect(result.bestMove, 'c3c4');
      expect(result.bestScore, 1);
      // 按 score 降序排列
      expect(result.moves[0].iccs, 'c3c4');
      expect(result.moves[0].score, 1);
      expect(result.moves[0].diff, 0);
      expect(result.moves[1].iccs, 'g3g4');
      expect(result.moves[1].score, 1);
      expect(result.moves[1].diff, 0);
      expect(result.moves[2].iccs, 'b2d2');
      expect(result.moves[2].score, 0);
      expect(result.moves[2].diff, -1);
      expect(result.moves[5].iccs, 'b2b4');
      expect(result.moves[5].score, -8);
      expect(result.moves[5].diff, -9);
    });

    test('should parse frequency from note field', () {
      const body =
          'move:a1a2,score:10,rank:2,note:! (128-05),winrate:55.30|'
          'move:b1b2,score:5,rank:1,note:* (64-03),winrate:52.10';

      final result = CloudQueryResult.parseResponse(body, 'test_fen');

      expect(result, isNotNull);
      expect(result!.moves[0].frequency, 128);
      expect(result.moves[1].frequency, 64);
    });

    test('should parse winrate as integer', () {
      const body =
          'move:a1a2,score:10,rank:2,note:! (10-01),winrate:55.30|'
          'move:b1b2,score:5,rank:1,note:* (10-01),winrate:49.92';

      final result = CloudQueryResult.parseResponse(body, 'test_fen');

      expect(result, isNotNull);
      expect(result!.moves[0].winRate, 55);
      expect(result.moves[1].winRate, 50);
    });

    test('should handle empty body', () {
      final result = CloudQueryResult.parseResponse('', 'test_fen');
      expect(result, isNull);
    });

    test('should handle body with only separators', () {
      final result = CloudQueryResult.parseResponse('|||', 'test_fen');
      expect(result, isNull);
    });

    test('should handle single move', () {
      const body = 'move:e3e4,score:50,rank:2,note:! (200-01),winrate:60.00';

      final result = CloudQueryResult.parseResponse(body, 'test_fen');

      expect(result, isNotNull);
      expect(result!.moves.length, 1);
      expect(result.bestMove, 'e3e4');
      expect(result.bestScore, 50);
      expect(result.moves[0].diff, 0);
    });

    test('should skip entries without move field', () {
      const body =
          'score:10,rank:2,note:! (10-01),winrate:55.00|'
          'move:e3e4,score:50,rank:2,note:! (100-01),winrate:60.00';

      final result = CloudQueryResult.parseResponse(body, 'test_fen');

      expect(result, isNotNull);
      expect(result!.moves.length, 1);
      expect(result.moves[0].iccs, 'e3e4');
    });

    test('should handle missing optional fields gracefully', () {
      const body = 'move:e3e4,score:50';

      final result = CloudQueryResult.parseResponse(body, 'test_fen');

      expect(result, isNotNull);
      expect(result!.moves.length, 1);
      expect(result.moves[0].iccs, 'e3e4');
      expect(result.moves[0].score, 50);
      expect(result.moves[0].winRate, 0);
      expect(result.moves[0].frequency, 0);
      expect(result.moves[0].diff, 0);
    });

    test('should handle negative scores', () {
      const body =
          'move:a1a2,score:-10,rank:0,note:? (5-01),winrate:40.00|'
          'move:b1b2,score:-50,rank:0,note:? (3-01),winrate:35.00|'
          'move:c1c2,score:-5,rank:1,note:* (10-01),winrate:45.00';

      final result = CloudQueryResult.parseResponse(body, 'test_fen');

      expect(result, isNotNull);
      expect(result!.bestScore, -5);
      expect(result.bestMove, 'c1c2');
      expect(result.moves[0].diff, 0);
      expect(result.moves[1].diff, -5);
      expect(result.moves[2].diff, -45);
    });

    test('should sort moves by score descending', () {
      const body =
          'move:z1z2,score:0,rank:1,note:* (10-01),winrate:50.00|'
          'move:a1a2,score:100,rank:2,note:! (50-01),winrate:70.00|'
          'move:m1m2,score:50,rank:1,note:* (30-01),winrate:60.00';

      final result = CloudQueryResult.parseResponse(body, 'test_fen');

      expect(result, isNotNull);
      expect(result!.moves[0].iccs, 'a1a2');
      expect(result.moves[0].score, 100);
      expect(result.moves[1].iccs, 'm1m2');
      expect(result.moves[1].score, 50);
      expect(result.moves[2].iccs, 'z1z2');
      expect(result.moves[2].score, 0);
    });

    test('should set position field correctly', () {
      const body = 'move:e3e4,score:10,rank:2,note:! (10-01),winrate:55.00';

      final result = CloudQueryResult.parseResponse(body, 'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1');

      expect(result, isNotNull);
      expect(
        result!.position,
        'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1',
      );
    });

    test('should handle whitespace in fields', () {
      const body = 'move:e3e4, score:10, rank:2, note:! (10-01), winrate:55.00';

      final result = CloudQueryResult.parseResponse(body, 'test_fen');

      expect(result, isNotNull);
      expect(result!.moves.length, 1);
      expect(result.moves[0].iccs, 'e3e4');
      expect(result.moves[0].score, 10);
    });

    test('should handle note without frequency pattern', () {
      const body =
          'move:e3e4,score:10,rank:2,note:!,winrate:55.00|'
          'move:f3f4,score:5,rank:1,note:good,winrate:52.00';

      final result = CloudQueryResult.parseResponse(body, 'test_fen');

      expect(result, isNotNull);
      expect(result!.moves[0].frequency, 0);
      expect(result.moves[1].frequency, 0);
    });

    test('should handle malformed entries and skip them', () {
      const body =
          'this is not valid|'
          'move:e3e4,score:10,rank:2,note:! (10-01),winrate:55.00|'
          'another invalid entry';

      final result = CloudQueryResult.parseResponse(body, 'test_fen');

      expect(result, isNotNull);
      expect(result!.moves.length, 1);
      expect(result.moves[0].iccs, 'e3e4');
    });

    test('should handle large score differences', () {
      const body =
          'move:a1a2,score:500,rank:2,note:! (100-01),winrate:80.00|'
          'move:b1b2,score:-500,rank:0,note:? (5-01),winrate:20.00';

      final result = CloudQueryResult.parseResponse(body, 'test_fen');

      expect(result, isNotNull);
      expect(result!.bestScore, 500);
      expect(result.moves[0].diff, 0);
      expect(result.moves[1].diff, -1000);
    });
  });
}
