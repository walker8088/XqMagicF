/// 游戏模式
enum GameMode {
  /// 自由练习：从任意局面自由走子，可回溯、编辑
  free('Free', '自由练习'),

  /// 人机对战：引擎与人类玩家对抗
  engineFight('EngineFight', '人机对战'),

  /// 杀法挑战：内置排局，红先胜挑战
  engineEndGame('EngineEndGame', '杀法挑战'),

  /// 连线分析：连接云库获取实时评估
  /// TODO: 未实现。云库查询已在 AnalysisService.queryCloud() 中提供，但
  /// 该模式尚未添加独立的 UI/逻辑处理。在 navigation_toolbar.dart 的
  /// ModeSelector 中可以看到该选项，但选择后无特殊行为。
  engineOnline('EngineOnline', '连线分析'),

  /// 棋盘编辑：自由增删棋子，编辑局面
  boardEdit('BoardEdit', '棋盘编辑');

  const GameMode(this.id, this.label);

  /// 模式标识
  final String id;

  /// 模式显示名称
  final String label;

  @override
  String toString() => label;
}

/// 引擎分析模式
enum EngineAnalysisMode {
  quick('快速', '快速模式', depth: 10, timeMs: 1000),
  deep('精准', '精准模式', depth: 20, timeMs: 5000),
  fight('对战', '挑战模式', depth: 15, timeMs: 3000);

  const EngineAnalysisMode(
    this.id,
    this.label, {
    required this.depth,
    required this.timeMs,
  });

  final String id;
  final String label;
  final int depth;
  final int timeMs;
}

/// 优先级模式（云库 vs 引擎）
enum PriorityMode {
  cloud('云库优先'),
  engine('引擎优先');

  const PriorityMode(this.label);
  final String label;
}
