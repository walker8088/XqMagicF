import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:magicf/utils/lru_cache.dart';

/// 云端棋库查询结果
class CloudQueryResult {
  CloudQueryResult({
    required this.position,
    required this.moves,
    required this.bestMove,
    this.bestScore = 0,
    this.isCache = false,
  });

  final String position;
  final List<CloudMoveInfo> moves;
  final String bestMove;
  final int bestScore;
  final bool isCache;
}

/// 云库着法信息
class CloudMoveInfo {
  CloudMoveInfo({
    required this.iccs,
    required this.score,
    required this.winRate,
    required this.frequency,
    required this.diff,
  });

  final String iccs;
  final int score;
  final int winRate;
  final int frequency;
  final int diff;

  String get qualityMark {
    if (diff >= -5) return '';
    if (diff >= -30) return '★';
    if (diff >= -70) return '✓';
    if (diff >= -100) return '✗';
    return '✗✗';
  }
}

/// 云端棋库客户端（chessdb.cn）
class CloudDBClient {
  CloudDBClient({LRUCache<String, CloudQueryResult>? cache})
    : _cache = cache ?? LRUCache<String, CloudQueryResult>(maxSize: 10000);

  static const String baseUrl = 'https://www.chessdb.cn/chessdb.php';

  final LRUCache<String, CloudQueryResult> _cache;

  LRUCache<String, CloudQueryResult> get cache => _cache;

  bool _isQuerying = false;
  bool get isQuerying => _isQuerying;

  final List<void Function(CloudQueryResult?)> _listeners = [];

  void addListener(void Function(CloudQueryResult?) listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function(CloudQueryResult?) listener) {
    _listeners.remove(listener);
  }

  /// 查询局面最佳着法
  Future<CloudQueryResult?> query(
    String positionFen, {
    bool useCache = true,
  }) async {
    if (useCache) {
      final cached = _cache.get(positionFen);
      if (cached != null) return cached;
    }

    _isQuerying = true;

    try {
      final url = Uri.parse('$baseUrl?action=queryall&board=$positionFen');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        _isQuerying = false;
        return null;
      }

      final result = _parseResponse(response.body, positionFen);

      if (result != null) {
        _cache.put(positionFen, result);
      }

      for (final listener in List.from(_listeners)) {
        listener(result);
      }

      _isQuerying = false;
      return result;
    } catch (_) {
      _isQuerying = false;
      return null;
    }
  }

  CloudQueryResult? _parseResponse(String body, String position) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['code'] != 'success') return null;

      final movesJson = json['moves'] as List<dynamic>;
      if (movesJson.isEmpty) return null;

      int? bestScore;
      for (final moveJson in movesJson) {
        final score = (moveJson['score'] as num).toInt();
        if (bestScore == null || score > bestScore) {
          bestScore = score;
        }
      }

      final moves = <CloudMoveInfo>[];
      for (final moveJson in movesJson) {
        final iccs = moveJson['move'] as String;
        final score = (moveJson['score'] as num).toInt();
        final winRate = (moveJson['winrate'] ?? 0) is String
            ? int.tryParse(moveJson['winrate'] as String) ?? 0
            : (moveJson['winrate'] as num?)?.toInt() ?? 0;
        final frequency = (moveJson['number'] ?? 0) is String
            ? int.tryParse(moveJson['number'] as String) ?? 0
            : (moveJson['number'] as num?)?.toInt() ?? 0;
        final diff = bestScore != null ? score - bestScore : 0;

        moves.add(
          CloudMoveInfo(
            iccs: iccs,
            score: score,
            winRate: winRate,
            frequency: frequency,
            diff: diff,
          ),
        );
      }

      moves.sort((a, b) => b.score.compareTo(a.score));

      return CloudQueryResult(
        position: position,
        moves: moves,
        bestMove: moves.first.iccs,
        bestScore: moves.first.score,
      );
    } catch (_) {
      return null;
    }
  }

  void clearCache() {
    _cache.clear();
  }
}
