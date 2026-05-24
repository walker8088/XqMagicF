/// LRU (Least Recently Used) 缓存
/// 用于缓存云库查询结果
class LRUCache<K, V> {
  LRUCache({this.maxSize = 10000});

  final int maxSize;
  final Map<K, V> _cache = {};
  final List<K> _order = [];

  int get size => _cache.length;

  /// 获取缓存值，同时更新 LRU 顺序
  V? get(K key) {
    if (!_cache.containsKey(key)) return null;
    _order.remove(key);
    _order.add(key);
    return _cache[key];
  }

  /// 放入缓存值
  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      _order.remove(key);
    } else if (_cache.length >= maxSize) {
      // 淘汰最久未使用的
      final oldest = _order.removeAt(0);
      _cache.remove(oldest);
    }
    _cache[key] = value;
    _order.add(key);
  }

  /// 是否包含键
  bool containsKey(K key) => _cache.containsKey(key);

  /// 清除缓存
  void clear() {
    _cache.clear();
    _order.clear();
  }

  /// 获取所有键
  Iterable<K> get keys => _cache.keys;

  /// 获取缓存命中率统计
  int _hits = 0;
  int _misses = 0;

  V? getWithStats(K key) {
    final value = get(key);
    if (value != null) {
      _hits++;
    } else {
      _misses++;
    }
    return value;
  }

  double get hitRate {
    final total = _hits + _misses;
    return total == 0 ? 0.0 : _hits / total;
  }

  void resetStats() {
    _hits = 0;
    _misses = 0;
  }
}
