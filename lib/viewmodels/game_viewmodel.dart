import 'package:flutter/foundation.dart';
import 'package:xqmagic/data/endgame_puzzles.dart';
import 'package:xqmagic/game/analysis_service.dart';
import 'package:xqmagic/game/engine_config_manager.dart';
import 'package:xqmagic/game/game_controller.dart';
import 'package:xqmagic/game/game_engine.dart';
import 'package:xqmagic/game/game_state_manager.dart';
import 'package:xqmagic/models/board.dart';
import 'package:xqmagic/models/game_state.dart';
import 'package:xqmagic/models/game_mode.dart';
import 'package:xqmagic/models/game_tree.dart';
import 'package:xqmagic/models/move.dart';
import 'package:xqmagic/services/cloud_db.dart';
import 'package:xqmagic/services/engine_manager.dart';
import 'package:xqmagic/services/uci_engine.dart';
import 'package:xqmagic/services/opening_book.dart';
import 'package:xqmagic/utils/app_settings.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/move_notation.dart';
import 'package:xqmagic/utils/fen.dart';
import 'package:xqmagic/utils/coord.dart';

/// 游戏视图模型：协调各个管理器，管理 UI 状态
///
/// 职责：
/// - 协调 GameStateManager、EngineConfigManager、AnalysisService
/// - 管理游戏模式
/// - 处理 UI 交互逻辑
/// - 提供数据给 UI 层
class GameViewModel extends ChangeNotifier {
  GameViewModel() {
    _init();
  }

  // ──────────── 管理器实例 ────────────

  /// 走子控制器
  late final GameController _controller;

  /// UI 状态管理器
  late final GameStateManager _stateManager;

  /// 引擎配置管理器
  late final EngineConfigManager _engineConfig;

  /// 分析服务
  late final AnalysisService _analysisService;

  // ──────────── 游戏状态 ────────────

  /// 当前游戏模式
  GameMode _mode = GameMode.free;
  GameMode get mode => _mode;

  /// 音效开关
  bool soundEnabled = true;

  // ──────────── 初始化 ────────────

  void _init() {
    final gameTree = GameTree();
    gameTree.initStandard();
    final engine = GameEngine(gameTree.current!.fen);

    final engineManager = EngineManager(logEnabled: true);
    final cloudDB = CloudDBClient();

    // 初始化管理器
    _stateManager = GameStateManager();
    _engineConfig = EngineConfigManager(engineManager);
    _analysisService = AnalysisService(
      engineManager: engineManager,
      cloudDB: cloudDB,
    );

    // 初始化走子控制器
    _controller = GameController(
      engine: engine,
      gameTree: gameTree,
      engineManager: engineManager,
      onChanged: notifyListeners,
      soundEnabled: () => soundEnabled,
      onMoveExecuted: _onMoveExecuted,
    );

    // 监听管理器状态变化
    _stateManager.addListener(_onStateChanged);
    _engineConfig.addListener(_onEngineConfigChanged);
    _analysisService.addListener(_onAnalysisChanged);

    // 初始查询
    final fen = gameTree.currentFen;
    if (fen != null) {
      _analysisService.queryCloud(fen);
    }

    _autoLoadEngine();
  }

  /// 走子执行完成回调
  void _onMoveExecuted() {
    final fen = _controller.gameTree.currentFen;
    _analysisService.analyzePosition(fen);
  }

  /// UI 状态变化回调
  void _onStateChanged() {
    notifyListeners();
  }

  /// 引擎配置变化回调
  void _onEngineConfigChanged() {
    notifyListeners();
  }

  /// 分析结果变化回调：将引擎评分和最佳着法保存到当前节点
  void _onAnalysisChanged() {
    final current = gameTree.current;
    if (current == null) {
      notifyListeners();
      return;
    }

    // 保存引擎评分到当前节点（红方视角）
    final score = engineScore;
    if (score != null) {
      current.evaluation = score;
    }

    // 保存引擎最佳着法用于后续比较
    final best = engineBestMove;
    if (best != null) {
      current.engineBestMove = best;
    }

    // 如果当前节点有父节点（即不是根节点），评估该步的着法质量
    if (current.parent != null &&
        current.move != null &&
        current.moveAnnotation == null) {
      _assessMoveQuality(current);
    }

    notifyListeners();
  }

  /// 评估着法质量：比较实际着法与引擎推荐
  void _assessMoveQuality(GameTreeNode node) {
    final move = node.move!;
    final bestICCS = node.engineBestMove ?? '';
    if (bestICCS.isEmpty) return;

    final moveICCS = MoveNotation.toICCS(move);

    // 引擎评分变化：比较走子前后的评分
    final scoreAfter = node.evaluation;
    if (scoreAfter == null) return;

    // 获取走子前的评分（父节点的评分）
    final scoreBefore = node.parent?.evaluation;

    // 计算评分变化
    // 正数变化 = 红方更好，负数变化 = 黑方更好
    // 走子的颜色决定方向
    int scoreDiff;
    if (scoreBefore != null) {
      scoreDiff = scoreAfter - scoreBefore;
      // 黑方走子时，评分变化取反（黑方让红方分减少 = 黑方好）
      if (move.color == PieceColor.black) {
        scoreDiff = -scoreDiff;
      }
    } else {
      scoreDiff = 0;
    }

    // 如果与引擎推荐一致 → 好棋
    if (bestICCS == moveICCS) {
      node.moveAnnotation = '★';
      return;
    }

    // 根据评分变化判断着法质量
    // 评分变化阈值（厘）：-50 = 小失误, -150 = 大失误, -300 = 败着
    if (scoreDiff < -300) {
      node.moveAnnotation = '✗✗';
    } else if (scoreDiff < -150) {
      node.moveAnnotation = '✗';
    } else if (scoreDiff < -50) {
      node.moveAnnotation = '?';
    } else if (scoreDiff > 100) {
      node.moveAnnotation = '!';
    } else {
      node.moveAnnotation = '✓';
    }
  }

  /// 启动时自动加载引擎
  Future<void> _autoLoadEngine() async {
    final enginePath = AppSettings.instance.enginePath;
    if (enginePath.isNotEmpty && !_engineConfig.isEngineReady) {
      await loadEngine(enginePath);
    }
  }

  // ──────────── 管理器访问器 ────────────

  /// UI 状态管理器
  GameStateManager get stateManager => _stateManager;

  /// 引擎配置管理器
  EngineConfigManager get engineConfig => _engineConfig;

  /// 分析服务
  AnalysisService get analysisService => _analysisService;

  /// 走子控制器
  GameController get controller => _controller;

  // ──────────── 游戏引擎访问器 ────────────

  GameEngine get engine => _controller.engine;
  GameTree get gameTree => _controller.gameTree;
  EngineManager get engineManager => _controller.engineManager;
  PieceColor get currentTurn => _controller.currentTurn;
  MoveRecord? get lastMove => _controller.lastMove;
  GameState get state => _controller.gameState;
  Board get currentBoard => engine.board;

  // ──────────── 分析结果访问器 ────────────

  String? get engineBestMove => _analysisService.engineBestMove;
  int? get engineScore => _analysisService.engineScore;
  List<EngineInfo> get engineInfos => _analysisService.engineInfos;
  bool get isAnalyzing => _engineConfig.isAnalyzing;
  CloudQueryResult? get cloudResult => _analysisService.cloudResult;
  bool get isCloudQuerying => _analysisService.isCloudQuerying;
  int get cloudCacheSize => _analysisService.cloudCacheSize;

  // ──────────── UI 状态访问器 ────────────

  Coord? get selectedPosition => _stateManager.selectedPosition;
  List<Coord> get possibleMoves => _stateManager.possibleMoves;
  String? get bestMoveHint => _stateManager.bestMoveHint;
  String get leftPanel => _stateManager.leftPanel;
  bool get isCloudPanelVisible => _stateManager.isCloudPanelVisible;

  // ──────────── 引擎配置访问器 ────────────

  EngineAnalysisMode get analysisMode => _engineConfig.analysisMode;
  PriorityMode get priorityMode => _engineConfig.priorityMode;
  int get multiPV => _engineConfig.multiPV;
  bool get isEngineReady => _engineConfig.isEngineReady;
  bool get isEngineThinking => _engineConfig.isEngineThinking;

  // ──────────── 游戏模式 ────────────

  void setMode(GameMode mode) {
    _mode = mode;
    if (mode == GameMode.engineEndGame) {
      _stateManager.initPuzzle(EndgameCollection.basicEndgames.first);
      _loadPuzzle();
    }
    notifyListeners();
  }

  void _loadPuzzle() {
    final puzzle = _stateManager.currentPuzzle;
    if (puzzle == null) return;

    gameTree.initFromFen(puzzle.fen);
    _controller.syncEngineFromFen(puzzle.fen);
    _stateManager.clearSelection();
    notifyListeners();
  }

  // ──────────── 引擎配置方法 ────────────

  void setAnalysisMode(EngineAnalysisMode mode) {
    _engineConfig.setAnalysisMode(mode);
  }

  void setPriorityMode(PriorityMode mode) {
    _engineConfig.setPriorityMode(mode);
  }

  void setMultiPV(int count) {
    _engineConfig.setMultiPV(count);
  }

  // ──────────── 棋子选择 ────────────

  void selectPiece(Coord pos) {
    if (state == GameState.checkmate) return;

    // 残局模式
    if (_mode == GameMode.engineEndGame &&
        _stateManager.currentPuzzle != null &&
        !_stateManager.puzzleCompleted) {
      if (_stateManager.selectedPosition != null &&
          _stateManager.possibleMoves.contains(pos)) {
        _handlePuzzleMove(_stateManager.selectedPosition!, pos);
        return;
      }
    }

    final piece = _controller.getPieceAt(pos);

    // 已选棋子 → 执行走棋
    if (_stateManager.selectedPosition != null &&
        _stateManager.possibleMoves.contains(pos)) {
      final ok = _controller.manualMove(_stateManager.selectedPosition!, pos);
      if (ok) {
        _stateManager.clearSelection();
      }
      return;
    }

    // 选择己方棋子
    if (piece != null && piece.color == currentTurn) {
      _stateManager.selectPosition(pos);
      _stateManager.setPossibleMoves(
        _controller.getLegalMoves(pos).map((m) => m.to).toList(),
      );
    } else {
      _stateManager.clearSelection();
    }
  }

  /// 执行引擎走子（桥接 UI → Controller）
  void playEngineMove(String iccs) {
    final ok = _controller.engineMove(iccs);
    if (ok) {
      _stateManager.clearSelection();
    }
  }

  // ──────────── 残局模式 ────────────

  void _handlePuzzleMove(Coord from, Coord to) {
    final piece = _controller.getPieceAt(from);
    if (piece == null) return;

    final moveRecord = MoveRecord(
      from: from,
      to: to,
      pieceType: piece.type,
      capturedPiece: _controller.getPieceAt(to),
      color: currentTurn,
    );

    final puzzle = _stateManager.currentPuzzle;
    if (puzzle == null) return;

    if (_stateManager.puzzleSolutionIndex < puzzle.solution.length) {
      final expectedICCS = puzzle.solution[_stateManager.puzzleSolutionIndex];
      final actualICCS = MoveNotation.toICCS(moveRecord);

      if (actualICCS == expectedICCS) {
        _controller.manualMove(from, to);
        _stateManager.advancePuzzleSolution();

        if (!_stateManager.puzzleCompleted) {
          _playPuzzleEngineMove();
        }
      } else {
        _stateManager.clearSelection();
      }
    }
  }

  void _playPuzzleEngineMove() {
    final puzzle = _stateManager.currentPuzzle;
    if (puzzle == null) return;

    if (_stateManager.puzzleSolutionIndex < puzzle.solution.length) {
      final iccs = puzzle.solution[_stateManager.puzzleSolutionIndex];
      _controller.engineMove(iccs);
      _stateManager.advancePuzzleSolution();
    }
  }

  // ──────────── 导航 ────────────

  bool goForward({int? variationIndex}) {
    final ok = _controller.goForward(variationIndex: variationIndex);
    if (ok) {
      _stateManager.clearSelection();
    }
    return ok;
  }

  bool goBack() {
    final ok = _controller.goBack();
    if (ok) {
      _stateManager.clearSelection();
    }
    return ok;
  }

  bool goToStart() {
    final ok = _controller.goToStart();
    if (ok) {
      _stateManager.clearSelection();
    }
    return ok;
  }

  bool goToMainLine() {
    final ok = _controller.goToMainLine();
    if (ok) {
      _stateManager.clearSelection();
    }
    return ok;
  }

  bool get canGoBack => gameTree.current?.parent != null;
  bool get canGoForward => gameTree.current?.hasChildren ?? false;
  int get depth => gameTree.depth;

  // ──────────── 引擎管理 ────────────

  Future<bool> loadEngine(String enginePath) async {
    return _engineConfig.loadEngine(enginePath);
  }

  Future<void> unloadEngine() async {
    await _engineConfig.unloadEngine();
  }

  Future<void> syncSettingsToEngine() async {
    await _engineConfig.syncSettingsToEngine();
  }

  // ──────────── 面板控制 ────────────

  void showCloudPanel() {
    _stateManager.toggleCloudPanel();
  }

  void hideLeftPanel() {
    _stateManager.hideLeftPanel();
  }

  // ──────────── 新局 ────────────

  void newGame() {
    _controller.reset();
    _stateManager.reset();
    _analysisService.reset();
    notifyListeners();
  }

  void loadFromFen(String fen) {
    gameTree.initFromFen(fen);
    _controller.syncEngineFromFen(fen);
    _stateManager.clearSelection();
    notifyListeners();
  }

  // ──────────── 着法序列 ────────────

  List<MoveRecord> get movesFromRoot => gameTree.movesFromRoot;
  List<MoveRecord> get mainLineMoves => gameTree.mainLineMoves;

  /// 主变着线各步的引擎评分（索引 → 红方视角评分）
  Map<int, int> get mainLineEvaluations {
    final path = gameTree.mainLinePath;
    final evals = <int, int>{};
    // path[0] = 根节点（没有对应的走法）
    // path[i] = 第 i 步走法后的局面
    for (int i = 1; i < path.length; i++) {
      final node = path[i];
      if (node.evaluation != null) {
        evals[i - 1] = node.evaluation!;
      }
    }
    return evals;
  }

  /// 主变着线各步的着法质量标记（索引 → 标记）
  Map<int, String> get mainLineAnnotations {
    final path = gameTree.mainLinePath;
    final annotations = <int, String>{};
    for (int i = 1; i < path.length; i++) {
      final node = path[i];
      if (node.moveAnnotation != null && node.moveAnnotation!.isNotEmpty) {
        annotations[i - 1] = node.moveAnnotation!;
      }
    }
    return annotations;
  }

  List<String> get mainLineNotations {
    final path = gameTree.mainLinePath;
    final notations = <String>[];
    for (int i = 0; i < path.length - 1; i++) {
      final move = path[i + 1].move!;
      if (move.notation != null && move.notation!.isNotEmpty) {
        notations.add(move.notation!);
      } else {
        final boardBefore = Board();
        FenParser.parse(path[i].fen, boardBefore);
        notations.add(MoveNotation.toText(boardBefore.pieces, move));
      }
    }
    return notations;
  }

  List<String> get moveNotations {
    final path = gameTree.getPathToCurrent();
    final notations = <String>[];
    for (int i = 0; i < path.length - 1; i++) {
      final move = path[i + 1].move!;
      if (move.notation != null && move.notation!.isNotEmpty) {
        notations.add(move.notation!);
      } else {
        final boardBefore = Board();
        FenParser.parse(path[i].fen, boardBefore);
        notations.add(MoveNotation.toText(boardBefore.pieces, move));
      }
    }
    return notations;
  }

  List<GameTreeNode> get variations => gameTree.current?.children ?? [];

  /// 开局信息
  OpeningInfo? get currentOpening {
    final fen = gameTree.currentFen;
    if (fen == null) return null;
    return OpeningBookService.instance.lookup(fen);
  }
}
