import 'package:flutter_test/flutter_test.dart';
import 'package:xqmagic/services/cloud_db.dart';
import 'package:xqmagic/utils/lru_cache.dart';

void main() {
  group('CloudQueryResult', () {
    test('should create with required fields', () {
      final result = CloudQueryResult(
        position: 'test_fen',
        moves: [],
        bestMove: '8182',
      );
      expect(result.position, 'test_fen');
      expect(result.moves, isEmpty);
      expect(result.bestMove, '8182');
      expect(result.bestScore, 0);
      expect(result.isCache, false);
    });

    test('should create with optional fields', () {
      final moveInfo = CloudMoveInfo(
        iccs: '8182',
        score: 100,
        winRate: 55,
        frequency: 1234,
        diff: 0,
      );
      final result = CloudQueryResult(
        position: 'test_fen',
        moves: [moveInfo],
        bestMove: '8182',
        bestScore: 100,
        isCache: true,
      );
      expect(result.bestScore, 100);
      expect(result.isCache, isTrue);
      expect(result.moves.length, 1);
    });
  });

  group('CloudMoveInfo', () {
    test('should create with all fields', () {
      final move = CloudMoveInfo(
        iccs: '8182',
        score: 100,
        winRate: 55,
        frequency: 1234,
        diff: -30,
      );
      expect(move.iccs, '8182');
      expect(move.score, 100);
      expect(move.winRate, 55);
      expect(move.frequency, 1234);
      expect(move.diff, -30);
    });

    group('qualityMark', () {
      test('should return empty for best move', () {
        final move = CloudMoveInfo(
          iccs: '8182',
          score: 100,
          winRate: 55,
          frequency: 1000,
          diff: 0,
        );
        expect(move.qualityMark, '');
      });

      test('should return ★ for good move', () {
        final move = CloudMoveInfo(
          iccs: '8182',
          score: 70,
          winRate: 50,
          frequency: 800,
          diff: -30,
        );
        expect(move.qualityMark, '★');
      });

      test('should return ✓ for ok move', () {
        final move = CloudMoveInfo(
          iccs: '8182',
          score: 30,
          winRate: 45,
          frequency: 500,
          diff: -70,
        );
        expect(move.qualityMark, '✓');
      });

      test('should return ✗ for bad move', () {
        final move = CloudMoveInfo(
          iccs: '8182',
          score: 0,
          winRate: 40,
          frequency: 200,
          diff: -100,
        );
        expect(move.qualityMark, '✗');
      });

      test('should return ✗✗ for very bad move', () {
        final move = CloudMoveInfo(
          iccs: '8182',
          score: -50,
          winRate: 30,
          frequency: 50,
          diff: -150,
        );
        expect(move.qualityMark, '✗✗');
      });

      test('should handle boundary values', () {
        // diff = -5 is still best (empty)
        expect(
          CloudMoveInfo(
            iccs: '8182',
            score: 95,
            winRate: 50,
            frequency: 1000,
            diff: -5,
          ).qualityMark,
          '',
        );

        // diff = -6 is good (★)
        expect(
          CloudMoveInfo(
            iccs: '8182',
            score: 94,
            winRate: 50,
            frequency: 1000,
            diff: -6,
          ).qualityMark,
          '★',
        );

        // diff = -31 is ok (✓)
        expect(
          CloudMoveInfo(
            iccs: '8182',
            score: 69,
            winRate: 50,
            frequency: 1000,
            diff: -31,
          ).qualityMark,
          '✓',
        );

        // diff = -71 is bad (✗)
        expect(
          CloudMoveInfo(
            iccs: '8182',
            score: 29,
            winRate: 50,
            frequency: 1000,
            diff: -71,
          ).qualityMark,
          '✗',
        );

        // diff = -101 is very bad (✗✗)
        expect(
          CloudMoveInfo(
            iccs: '8182',
            score: -1,
            winRate: 50,
            frequency: 1000,
            diff: -101,
          ).qualityMark,
          '✗✗',
        );
      });
    });
  });

  group('CloudDBClient', () {
    late CloudDBClient client;

    setUp(() {
      client = CloudDBClient();
    });

    test('should start with empty cache', () {
      expect(client.cache.size, 0);
    });

    test('should have correct base URL', () {
      expect(CloudDBClient.baseUrl, 'https://www.chessdb.cn/chessdb.php');
    });

    group('cache', () {
      test('should access underlying LRU cache', () {
        // The cache is exposed, we can check its properties
        expect(client.cache.maxSize, 10000);
      });
    });

    group('clearCache', () {
      test('should clear the cache', () {
        // 原实现是死测试：在空 cache 上调 clearCache()，再断言 size==0
        // （本来就是 0）。这里用构造器注入预填数据的 cache，才有意义。
        final prePopulated = LRUCache<String, CloudQueryResult>();
        prePopulated.put(
          'fen1',
          CloudQueryResult(position: 'fen1', moves: [], bestMove: ''),
        );
        prePopulated.put(
          'fen2',
          CloudQueryResult(position: 'fen2', moves: [], bestMove: ''),
        );
        final c = CloudDBClient(cache: prePopulated);
        expect(
          c.cache.size,
          2,
          reason: 'sanity: pre-populated cache has 2 items',
        );

        c.clearCache();
        expect(c.cache.size, 0);
        expect(prePopulated.keys, isEmpty);
      });
    });
  });
}
