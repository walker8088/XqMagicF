import 'package:xqmagic/utils/app_logger.dart';
import 'package:http/http.dart' as http;
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/lru_cache.dart';

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

  /// 解析 chessdb.cn queryall 返回的文本响应
  ///
  /// 格式: move:c3c4,score:1,rank:2,note:! (44-02),winrate:50.08|move:...
  /// [moveColor] 当前走子方，用于将得分转换为红方视角
  static CloudQueryResult? parseResponse(
    String body,
    String position, {
    PieceColor moveColor = PieceColor.red,
  }) {
    if (body.isEmpty) return null;

    final moveStrings = body.split('|');
    if (moveStrings.isEmpty || moveStrings[0].isEmpty) return null;

    final moves = <CloudMoveInfo>[];
    int? bestScore;

    // 第一次遍历：找出最高分数（红方视角，chessdb.cn 已是红方视角）
    for (final moveStr in moveStrings) {
      final fields = _parseFields(moveStr.trim());
      if (fields == null) continue;
      final score = int.tryParse(fields['score'] ?? '0') ?? 0;
      if (bestScore == null || score > bestScore) {
        bestScore = score;
      }
    }

    // 第二次遍历：构建 CloudMoveInfo 列表（chessdb.cn 已是红方视角，无需转换）
    for (final moveStr in moveStrings) {
      final fields = _parseFields(moveStr.trim());
      if (fields == null) continue;

      final iccs = fields['move'] ?? '';
      if (iccs.isEmpty) continue;

      final score = int.tryParse(fields['score'] ?? '0') ?? 0;
      final winRate = (double.tryParse(fields['winrate'] ?? '0') ?? 0.0)
          .round();
      final frequency = _parseFrequency(fields['note']);
      final diff = score - bestScore!;

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

    if (moves.isEmpty) return null;

    moves.sort((a, b) => b.score.compareTo(a.score));

    return CloudQueryResult(
      position: position,
      moves: moves,
      bestMove: moves.first.iccs,
      bestScore: moves.first.score,
    );
  }

  static Map<String, String>? _parseFields(String moveStr) {
    try {
      final result = <String, String>{};
      final pairs = moveStr.split(',');
      for (final pair in pairs) {
        final colonIdx = pair.indexOf(':');
        if (colonIdx < 0) continue;
        final key = pair.substring(0, colonIdx).trim();
        final value = pair.substring(colonIdx + 1).trim();
        result[key] = value;
      }
      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }

  static int _parseFrequency(String? note) {
    if (note == null || note.isEmpty) return 0;
    try {
      final match = RegExp(r'\((\d+)-').firstMatch(note);
      if (match != null) {
        return int.parse(match.group(1)!);
      }
    } catch (_) {}
    return 0;
  }
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
    AppLogger.debug('CloudDB', '查询开始, FEN: $positionFen');

    if (useCache) {
      final cached = _cache.get(positionFen);
      if (cached != null) {
        AppLogger.debug('CloudDB', '命中缓存, ${cached.moves.length} 条着法');
        return cached;
      }
    }

    _isQuerying = true;

    try {
      final url = Uri.parse(
        baseUrl,
      ).replace(queryParameters: {'action': 'queryall', 'board': positionFen});
      AppLogger.debug('CloudDB', '请求 URL: $url');

      final response = await http.get(url).timeout(const Duration(seconds: 10));
      AppLogger.debug('CloudDB', '响应状态码: ${response.statusCode}');
      AppLogger.debug('CloudDB', '响应内容: ${response.body}');

      if (response.statusCode != 200) {
        AppLogger.warn('CloudDB', '请求失败, 状态码: ${response.statusCode}');
        _isQuerying = false;
        return null;
      }

      final result = _parseResponse(response.body, positionFen);
      if (result != null) {
        _cache.put(positionFen, result);
        AppLogger.debug(
          'CloudDB',
          '解析成功, ${result.moves.length} 条着法, 最佳=${result.bestMove}',
        );
      } else {
        AppLogger.warn('CloudDB', '解析结果为空');
      }

      for (final listener in List.from(_listeners)) {
        listener(result);
      }

      _isQuerying = false;
      return result;
    } catch (e, st) {
      AppLogger.error('CloudDB', '查询异常: $e');
      AppLogger.debug('CloudDB', '堆栈: $st');
      _isQuerying = false;
      return null;
    }
  }

  /// 从 FEN 字符串提取走子方
  static PieceColor _fenToMoveColor(String fen) {
    final parts = fen.split(' ');
    if (parts.length < 2) return PieceColor.red;
    return parts[1].toLowerCase() == 'r' ? PieceColor.red : PieceColor.black;
  }

  CloudQueryResult? _parseResponse(String body, String position) {
    AppLogger.debug('CloudDB', '开始解析文本响应, 长度: ${body.length}');
    final moveColor = _fenToMoveColor(position);
    final result = CloudQueryResult.parseResponse(
      body,
      position,
      moveColor: moveColor,
    );
    if (result != null) {
      AppLogger.debug(
        'CloudDB',
        '解析成功: ${result.moves.length} 条着法, 最佳=${result.bestMove}',
      );
    } else {
      AppLogger.warn('CloudDB', '解析结果为空');
    }
    return result;
  }

  void clearCache() {
    _cache.clear();
  }
}
