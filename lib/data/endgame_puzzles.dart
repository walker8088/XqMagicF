import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:xqmagic/utils/app_logger.dart';

/// 残局练习数据
/// 每个残局包含：名称、FEN 局面、解法（着法序列）
class EndgamePuzzle {
  const EndgamePuzzle({
    required this.id,
    required this.name,
    required this.collection,
    required this.fen,
    required this.solution,
    this.difficulty = 1,
    this.hint = '',
  });

  final String id;
  final String name;
  final String collection;
  final String fen;
  final List<String> solution; // ICCS 着法序列
  final int difficulty; // 1-5
  final String hint;

  /// 从 JSON Map 创建
  factory EndgamePuzzle.fromJson(Map<String, dynamic> json) {
    return EndgamePuzzle(
      id: json['id'] as String,
      name: json['name'] as String,
      collection: json['collection'] as String,
      fen: json['fen'] as String,
      solution: (json['solution'] as List).cast<String>(),
      difficulty: json['difficulty'] as int? ?? 1,
      hint: json['hint'] as String? ?? '',
    );
  }
}

/// 残局集合
///
/// 优先从 JSON 文件加载（[loadFromAsset]）；若文件不存在或解析失败，
/// 退回内置的硬编码数据（[basicEndgames] 等）。
class EndgameCollection {
  // ──────────── 运行时缓存 ────────────

  /// 从文件加载的残局列表（优先于硬编码数据）
  static List<EndgamePuzzle>? _loadedPuzzles;

  /// 是否已尝试加载（防止重复加载）
  static bool _loadAttempted = false;

  // ──────────── 文件加载 ────────────

  /// 默认资源文件路径
  static const defaultAssetPath = 'assets/data/endgame_puzzles.json';

  /// 从 Flutter asset 加载残局数据
  ///
  /// 加载成功后 [getAll] 等方法将返回文件数据；
  /// 失败时静默回退到内置硬编码数据，不抛异常。
  static Future<bool> loadFromAsset([String? assetPath]) async {
    final path = assetPath ?? defaultAssetPath;
    try {
      final jsonStr = await rootBundle.loadString(path);
      final loaded = _parseJson(jsonStr);
      if (loaded.isNotEmpty) {
        _loadedPuzzles = loaded;
        AppLogger.info('EndgameCollection', '从 $path 加载了 ${loaded.length} 个残局');
      }
      _loadAttempted = true;
      return loaded.isNotEmpty;
    } catch (e) {
      AppLogger.warn('EndgameCollection', '加载 $path 失败，使用内置数据: $e');
      _loadAttempted = true;
      return false;
    }
  }

  /// 从 JSON 字符串解析残局列表
  static List<EndgamePuzzle> _parseJson(String jsonStr) {
    final list = jsonDecode(jsonStr) as List;
    return list
        .map((e) => EndgamePuzzle.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 重置加载状态（用于测试或重新加载）
  static void reset() {
    _loadedPuzzles = null;
    _loadAttempted = false;
  }

  /// 当前是否已从文件加载
  static bool get isLoaded => _loadedPuzzles != null;

  // ──────────── 内置硬编码数据（fallback） ────────────

  static const List<EndgamePuzzle> dreamOfDivine = [
    // 梦入神机 - 部分经典残局
    EndgamePuzzle(
      id: 'dream_001',
      name: '一马擒单士',
      collection: '梦入神机',
      fen: '9/4k4/9/9/9/9/4K4/3N5 w',
      solution: ['4546'],
      difficulty: 1,
    ),
    EndgamePuzzle(
      id: 'dream_002',
      name: '双杯献酒',
      collection: '梦入神机',
      fen: '3akab2/4n4/2c6/p1p1p1p1p/9/9/P1P1P1P1P/2C1C4/4N4/2BAKAB2 w',
      solution: ['2327', '7879', '3835'],
      difficulty: 2,
    ),
  ];

  static const List<EndgamePuzzle> elegantChess = [
    // 适情雅趣 - 360局选编
    EndgamePuzzle(
      id: 'elegant_001',
      name: '七星聚会',
      collection: '适情雅趣',
      fen: '4k4/9/1c5c1/3pp3p/9/9/P3PP3/1C5C1/9/3AK4 w',
      solution: ['5262', '9888'],
      difficulty: 3,
    ),
  ];

  static const List<EndgamePuzzle> basicEndgames = [
    // 基础杀法练习
    EndgamePuzzle(
      id: 'basic_001',
      name: '单车必胜单士',
      collection: '基础杀法',
      fen: '9/4k4/9/9/9/9/9/9/4K4/4R4 w',
      solution: ['5152'],
      difficulty: 1,
    ),
    EndgamePuzzle(
      id: 'basic_002',
      name: '双车错杀',
      collection: '基础杀法',
      fen: '9/9/9/9/9/9/9/4k4/4R4/3KR4 w',
      solution: ['4252'],
      difficulty: 1,
    ),
    EndgamePuzzle(
      id: 'basic_003',
      name: '马后炮',
      collection: '基础杀法',
      fen: '4k4/9/9/9/9/9/4K4/4n4/9/2C1R4 w',
      solution: ['5354'],
      difficulty: 1,
    ),
    EndgamePuzzle(
      id: 'basic_004',
      name: '铁门栓',
      collection: '基础杀法',
      fen: '4k4/9/9/9/9/9/9/4K4/4R4/4N4 w',
      solution: ['5152'],
      difficulty: 1,
    ),
    EndgamePuzzle(
      id: 'basic_005',
      name: '天地炮',
      collection: '基础杀法',
      fen: '4k4/4c4/9/9/9/9/9/4K4/9/4C4 w',
      solution: ['5141'],
      difficulty: 2,
    ),
    EndgamePuzzle(
      id: 'basic_006',
      name: '重炮杀',
      collection: '基础杀法',
      fen: '4k4/9/9/9/9/9/9/4K4/9/2C2C3 w',
      solution: ['3135'],
      difficulty: 1,
    ),
    EndgamePuzzle(
      id: 'basic_007',
      name: '卧槽马杀',
      collection: '基础杀法',
      fen: '4k4/9/9/9/9/9/9/4K4/4N4/9 w',
      solution: ['5365'],
      difficulty: 1,
    ),
    EndgamePuzzle(
      id: 'basic_008',
      name: '挂角马杀',
      collection: '基础杀法',
      fen: '4k4/9/9/9/9/9/9/4K4/4n4/9 w',
      solution: ['5335'],
      difficulty: 1,
    ),
    EndgamePuzzle(
      id: 'basic_009',
      name: '双马饮泉',
      collection: '基础杀法',
      fen: '4k4/9/9/9/9/9/9/4K4/4N4/3N5 w',
      solution: ['5365'],
      difficulty: 2,
    ),
    EndgamePuzzle(
      id: 'basic_010',
      name: '车马冷着',
      collection: '基础杀法',
      fen: '4k4/9/9/9/9/9/9/4K4/4R4/3N5 w',
      solution: ['5365'],
      difficulty: 3,
    ),
  ];

  // ──────────── 查询方法 ────────────

  /// 获取所有残局（优先返回文件加载的数据，文件数据为空则 fallback）
  static List<EndgamePuzzle> getAll() {
    if (_loadedPuzzles != null && _loadedPuzzles!.isNotEmpty) {
      return _loadedPuzzles!;
    }
    return [...basicEndgames, ...dreamOfDivine, ...elegantChess];
  }

  /// 按集合筛选
  static List<EndgamePuzzle> getByCollection(String collection) {
    return getAll().where((p) => p.collection == collection).toList();
  }

  /// 按难度筛选
  static List<EndgamePuzzle> getByDifficulty(int difficulty) {
    return getAll().where((p) => p.difficulty == difficulty).toList();
  }

  /// 获取指定 ID 的残局
  static EndgamePuzzle? getById(String id) {
    final all = getAll();
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}
