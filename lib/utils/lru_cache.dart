import 'dart:collection';

/// LRU (Least Recently Used) 缓存
/// 用于缓存云库查询结果
///
/// 使用 [LinkedHashMap] 实现 O(1) 的 get/put 操作。
/// [LinkedHashMap] 维护插入顺序，访问时通过 remove+重新插入来刷新位置。
class LRUCache<K, V> {
  LRUCache({this.maxSize = 10000});

  final int maxSize;
  final LinkedHashMap<K, V> _cache = LinkedHashMap();

  int get size => _cache.length;

  /// 获取缓存值，同时更新 LRU 顺序
  V? get(K key) {
    if (!_cache.containsKey(key)) {
      _misses++;
      return null;
    }
    _hits++;
    // 先取出值，再决定是否 reinsert。**不能**依赖 `remove` 的返回值
    // 区分"键不存在"与"值为 null"——前者已被 containsKey 排除。
    // 原实现误用 remove 的返回值判断，导致存 null 的键会被静默驱逐。
    final V? value = _cache[key];
    if (value != null) {
      // LinkedHashMap 没有原地 reinsert API，必须 remove + put。
      // null 值跳过 reinsert（LRU 顺序对 null 不重要，且 put 不会产生意义）。
      _cache.remove(key);
      _cache[key] = value;
    }
    return value;
  }

  /// 放入缓存值
  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= maxSize) {
      // 淘汰最久未使用的（LinkedHashMap 的 first 即最旧的条目）
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  /// 是否包含键
  bool containsKey(K key) => _cache.containsKey(key);

  /// 清除缓存
  void clear() {
    _cache.clear();
  }

  /// 获取所有键
  Iterable<K> get keys => _cache.keys;

  /// 缓存命中率（0.0 - 1.0）
  double get hitRate {
    if (_hits + _misses == 0) return 0.0;
    return _hits / (_hits + _misses);
  }

  int _hits = 0;
  int _misses = 0;
}

/// 缓存统计信息
class CacheStats {
  const CacheStats({required this.size, required this.hitRate});

  final int size;
  final double hitRate;
}
