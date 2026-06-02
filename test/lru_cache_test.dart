import 'package:flutter_test/flutter_test.dart';
import 'package:xqmagic/utils/lru_cache.dart';

void main() {
  group('LRUCache', () {
    late LRUCache<String, int> cache;

    setUp(() {
      cache = LRUCache<String, int>(maxSize: 3);
    });

    group('put and get', () {
      test('should store and retrieve values', () {
        cache.put('a', 1);
        expect(cache.get('a'), 1);
      });

      test('should return null for missing key', () {
        expect(cache.get('missing'), isNull);
      });

      test('should update existing value', () {
        cache.put('a', 1);
        cache.put('a', 10);
        expect(cache.get('a'), 10);
      });

      test('should store multiple values', () {
        cache.put('a', 1);
        cache.put('b', 2);
        cache.put('c', 3);
        expect(cache.get('a'), 1);
        expect(cache.get('b'), 2);
        expect(cache.get('c'), 3);
      });
    });

    group('LRU eviction', () {
      test('should evict least recently used when full', () {
        cache.put('a', 1);
        cache.put('b', 2);
        cache.put('c', 3);
        // Cache is full (maxSize: 3), adding 'd' should evict 'a'
        cache.put('d', 4);
        expect(cache.get('a'), isNull);
        expect(cache.get('b'), 2);
        expect(cache.get('c'), 3);
        expect(cache.get('d'), 4);
      });

      test('should update LRU order on get', () {
        cache.put('a', 1);
        cache.put('b', 2);
        cache.put('c', 3);
        // Access 'a' to make it most recently used
        cache.get('a');
        // Now adding 'd' should evict 'b' (least recently used)
        cache.put('d', 4);
        expect(cache.get('a'), 1); // 'a' was accessed, should still be there
        expect(cache.get('b'), isNull); // 'b' should be evicted
        expect(cache.get('c'), 3);
        expect(cache.get('d'), 4);
      });

      test('should evict correctly after multiple accesses', () {
        cache.put('a', 1);
        cache.put('b', 2);
        cache.put('c', 3);
        cache.get('a');
        cache.get('b');
        // Order now: c, a, b (b is most recent)
        cache.put('d', 4);
        expect(cache.get('a'), 1);
        expect(cache.get('b'), 2);
        expect(cache.get('c'), isNull); // 'c' was least recently used
        expect(cache.get('d'), 4);
      });

      test('should not evict when updating existing key', () {
        cache.put('a', 1);
        cache.put('b', 2);
        cache.put('c', 3);
        cache.put('a', 10); // Update 'a', should not increase size
        expect(cache.size, 3);
        expect(cache.get('a'), 10);
      });
    });

    group('size', () {
      test('should return correct size', () {
        expect(cache.size, 0);
        cache.put('a', 1);
        expect(cache.size, 1);
        cache.put('b', 2);
        expect(cache.size, 2);
      });

      test('should not exceed maxSize', () {
        cache.put('a', 1);
        cache.put('b', 2);
        cache.put('c', 3);
        cache.put('d', 4);
        expect(cache.size, 3);
      });
    });

    group('containsKey', () {
      test('should return true for existing key', () {
        cache.put('a', 1);
        expect(cache.containsKey('a'), isTrue);
      });

      test('should return false for missing key', () {
        expect(cache.containsKey('a'), isFalse);
      });

      test('should return false after eviction', () {
        cache.put('a', 1);
        cache.put('b', 2);
        cache.put('c', 3);
        cache.put('d', 4);
        expect(cache.containsKey('a'), isFalse);
      });
    });

    group('clear', () {
      test('should remove all entries', () {
        cache.put('a', 1);
        cache.put('b', 2);
        cache.clear();
        expect(cache.size, 0);
        expect(cache.get('a'), isNull);
        expect(cache.get('b'), isNull);
      });

      test('should allow reuse after clear', () {
        cache.put('a', 1);
        cache.clear();
        cache.put('b', 2);
        expect(cache.size, 1);
        expect(cache.get('b'), 2);
      });
    });

    group('keys', () {
      test('should return all keys', () {
        cache.put('a', 1);
        cache.put('b', 2);
        expect(cache.keys, containsAll(['a', 'b']));
      });

      test('should return empty iterable when cache is empty', () {
        expect(cache.keys.isEmpty, isTrue);
      });
    });

    group('default maxSize', () {
      test('should default to 10000', () {
        final defaultCache = LRUCache<String, int>();
        expect(defaultCache.maxSize, 10000);
      });
    });

    group('edge cases', () {
      test('should handle maxSize of 1', () {
        final smallCache = LRUCache<String, int>(maxSize: 1);
        smallCache.put('a', 1);
        smallCache.put('b', 2);
        expect(smallCache.get('a'), isNull);
        expect(smallCache.get('b'), 2);
        expect(smallCache.size, 1);
      });

      test('should handle null values via containsKey', () {
        final nullableCache = LRUCache<String, int?>();
        nullableCache.put('a', null);
        // get 返回 null 既可能是 missing 也可能是存了 null
        // 用 containsKey 区分
        expect(nullableCache.containsKey('a'), isTrue);
        expect(nullableCache.containsKey('missing'), isFalse);
      });

      test('get on null value should not evict the key (regression)', () {
        // 原实现的 bug：get 误用 remove 的返回值判定，
        // 会把存了 null 的键在第一次 get 时静默驱逐。
        // 修复后：键必须保留，且 hits 应递增。
        final cache = LRUCache<String, int?>();
        cache.put('a', null);
        // 多次 get 后键仍应存在
        expect(cache.get('a'), isNull);
        expect(
          cache.containsKey('a'),
          isTrue,
          reason: 'key must not be evicted',
        );
        expect(cache.get('a'), isNull);
        expect(
          cache.containsKey('a'),
          isTrue,
          reason: 'still present after 2nd get',
        );
        expect(cache.hitRate, 1.0, reason: 'all gets were hits');
      });

      test('hitRate should reflect hits and misses', () {
        final cache = LRUCache<String, int>();
        cache.put('a', 1);
        cache.get('a'); // hit
        cache.get('a'); // hit
        cache.get('b'); // miss
        expect(cache.hitRate, closeTo(2 / 3, 1e-9));
      });

      test('hitRate should be 0.0 when no operations performed', () {
        final cache = LRUCache<String, int>();
        expect(cache.hitRate, 0.0);
      });
    });
  });
}
