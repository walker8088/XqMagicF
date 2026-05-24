/// 游戏模式
enum GameMode {
  /// 自由练习：从任意局面自由走子，可回溯、编辑
  free('Free', '自由练习'),

  /// 引擎辅助：引擎实时分析，显示箭头提示最佳着法
  engineAssist('EngineAssist', '引擎辅助'),

  /// 人机对战：引擎与人类玩家对抗
  engineFight('EngineFight', '人机对战'),

  /// 杀法挑战：内置排局，红先胜挑战
  engineEndGame('EngineEndGame', '杀法挑战'),

  /// 连线分析：连接云库获取实时评估
  engineOnline('EngineOnline', '连线分析');

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
