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
}

/// 残局集合
class EndgameCollection {
  static const List<EndgamePuzzle> dreamOfDivine = [
    // 梦入神机 - 部分经典残局
    EndgamePuzzle(
      id: 'dream_001',
      name: '一马擒单士',
      collection: '梦入神机',
      fen: '9/4k4/9/9/9/9/4K4/3N5 r',
      solution: ['4546'],
      difficulty: 1,
    ),
    EndgamePuzzle(
      id: 'dream_002',
      name: '双杯献酒',
      collection: '梦入神机',
      fen: '3akab2/4n4/2c6/p1p1p1p1p/9/9/P1P1P1P1P/2C1C4/4N4/2BAKAB2 r',
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
      fen: '4k4/9/1c5c1/3pp3p/9/9/P3PP3/1C5C1/9/3AK4 r',
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
      fen: '9/4k4/9/9/9/9/9/9/4K4/4R4 r',
      solution: ['5152'],
      difficulty: 1,
    ),
    EndgamePuzzle(
      id: 'basic_002',
      name: '双车错杀',
      collection: '基础杀法',
      fen: '9/9/9/9/9/9/9/4k4/4R4/3KR4 r',
      solution: ['4252'],
      difficulty: 1,
    ),
    EndgamePuzzle(
      id: 'basic_003',
      name: '马后炮',
      collection: '基础杀法',
      fen: '4k4/9/9/9/9/9/4K4/4n4/9/2C1R4 r',
      solution: ['5354'],
      difficulty: 1,
    ),
    EndgamePuzzle(
      id: 'basic_004',
      name: '铁门栓',
      collection: '基础杀法',
      fen: '4k4/9/9/9/9/9/9/4K4/4R4/4N4 r',
      solution: ['5152'],
      difficulty: 1,
    ),
    EndgamePuzzle(
      id: 'basic_005',
      name: '天地炮',
      collection: '基础杀法',
      fen: '4k4/4c4/9/9/9/9/9/4K4/9/4C4 r',
      solution: ['5141'],
      difficulty: 2,
    ),
    EndgamePuzzle(
      id: 'basic_006',
      name: '重炮杀',
      collection: '基础杀法',
      fen: '4k4/9/9/9/9/9/9/4K4/9/2C2C3 r',
      solution: ['3135'],
      difficulty: 1,
    ),
    EndgamePuzzle(
      id: 'basic_007',
      name: '卧槽马杀',
      collection: '基础杀法',
      fen: '4k4/9/9/9/9/9/9/4K4/4N4/9 r',
      solution: ['5365'],
      difficulty: 1,
    ),
    EndgamePuzzle(
      id: 'basic_008',
      name: '挂角马杀',
      collection: '基础杀法',
      fen: '4k4/9/9/9/9/9/9/4K4/4n4/9 r',
      solution: ['5335'],
      difficulty: 1,
    ),
    EndgamePuzzle(
      id: 'basic_009',
      name: '双马饮泉',
      collection: '基础杀法',
      fen: '4k4/9/9/9/9/9/9/4K4/4N4/3N5 r',
      solution: ['5365'],
      difficulty: 2,
    ),
    EndgamePuzzle(
      id: 'basic_010',
      name: '车马冷着',
      collection: '基础杀法',
      fen: '4k4/9/9/9/9/9/9/4K4/4R4/3N5 r',
      solution: ['5365'],
      difficulty: 3,
    ),
  ];

  /// 获取所有残局
  static List<EndgamePuzzle> getAll() {
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

  /// 获取指定索引的残局
  static EndgamePuzzle? getById(String id) {
    return getAll().firstWhere(
      (p) => p.id == id,
      orElse: () => throw StateError('Not found'),
    );
  }
}
