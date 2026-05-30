import 'package:flutter/foundation.dart';
import 'package:xqmagic/data/endgame_puzzles.dart';
import 'package:xqmagic/game/game_engine.dart';
import 'package:xqmagic/game/game_state_manager.dart';
import 'package:xqmagic/models/board.dart';
import 'package:xqmagic/models/chess_piece.dart';
import 'package:xqmagic/models/game_state.dart';
import 'package:xqmagic/models/game_mode.dart';
import 'package:xqmagic/models/game_tree.dart';
import 'package:xqmagic/models/move.dart';
import 'package:xqmagic/models/panel_type.dart';
import 'package:xqmagic/services/cloud_db.dart';
import 'package:xqmagic/services/engine_manager.dart';
import 'package:xqmagic/services/engine.dart';
import 'package:xqmagic/services/opening_book.dart';
import 'package:xqmagic/utils/app_logger.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/coord.dart';
import 'package:xqmagic/utils/fen.dart';
import 'package:xqmagic/utils/move_notation.dart';
import 'package:xqmagic/utils/move_quality_assessor.dart';
import 'package:xqmagic/utils/sound_manager.dart';
import 'package:xqmagic/utils/app_settings.dart';

/// 游戏视图模型：协调所有游戏逻辑，管理 UI 状态
///
/// 职责：
/// - 走子规则（手动/引擎）
/// - 导航（前进/后退）
/// - 触发引擎分析 + 云库查询
/// - 管理 UI 交互状态（棋子选择、面板等）
class GameViewModel extends ChangeNotifier {
  GameViewModel() {
    _init();
  }

  // ──────────── 核心游戏状态 ────────────

  /// 游戏逻辑引擎
  late GameEngine engine;

  /// 棋谱树
  late GameTree gameTree;

  /// 上一步走法
  MoveRecord? lastMove;

  /// 游戏状态
  GameState gameState = GameState.playing;

  // ──────────── 管理器实例 ────────────

  /// UI 状态管理器
  late final GameStateManager _stateManager;

  /// 引擎管理器
  late final EngineManager _engineManager;

  /// 云库客户端
  late final CloudDBClient _cloudDB;

  /// 云库查询结果
  CloudQueryResult? _cloudResult;
  CloudQueryResult? get cloudResult => _cloudResult;

  /// 是否正在查询云库
  bool _isCloudQuerying = false;

  // ──────────── 游戏模式 ────────────

  /// 当前游戏模式
  GameMode _mode = GameMode.free;
  GameMode get mode => _mode;

  /// 音效开关
  bool soundEnabled = true;

  // ──────────── 初始化 ────────────

  void _init() {
    gameTree = GameTree();
    gameTree.initStandard();
    engine = GameEngine(gameTree.current!.fen);

    _engineManager = EngineManager(logEnabled: true);
    _cloudDB = CloudDBClient();
    _stateManager = GameStateManager();

    // 监听管理器状态变化
    _engineManager.addListener(_onEngineChanged);
    _stateManager.addListener(_onStateChanged);
    _engineManager.addListener(_onAnalysisChanged);

    // 初始查询
    final fen = gameTree.currentFen;
    if (fen != null) {
      queryCloud(fen);
    }

    _autoLoadEngine();
  }

  // ────────────────── 走子入口 ──────────────────

  /// 手动走子：校验合法性后执行
  /// 返回 true 表示走子成功
  bool manualMove(Coord from, Coord to) {
    if (gameState == GameState.checkmate) return false;

    final legalMoves = engine.getLegalMoves(from);
    if (!legalMoves.any((m) => m.to == to)) return false;

    final piece = _getPieceAt(from);
    if (piece == null) return false;

    final move = MoveRecord(
      from: from,
      to: to,
      pieceType: piece.type,
      capturedPiece: _getPieceAt(to),
      color: currentTurn,
    );
    _executeMove(move);
    return true;
  }

  /// 引擎走子：从 ICCS 解析并执行
  /// 返回 true 表示走子成功
  bool engineMove(String iccs) {
    if (gameState != GameState.playing) return false;

    try {
      final (from, to) = MoveNotation.fromICCS(iccs);
      final piece = _getPieceAt(from);
      if (piece == null) return false;

      // 校验走棋方一致性
      if (piece.color != currentTurn) return false;

      final move = MoveRecord(
        from: from,
        to: to,
        pieceType: piece.type,
        capturedPiece: _getPieceAt(to),
        color: currentTurn,
      );
      _executeMove(move);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 执行引擎走子（桥接 UI → ViewModel）
  void playEngineMove(String iccs) {
    final ok = engineMove(iccs);
    if (ok) {
      _stateManager.clearSelection();
    }
  }

  // ────────────────── 核心走子 ──────────────────

  void _executeMove(MoveRecord move) {
    // 走子前保存状态（用于记谱显示和引擎/云库查询）
    final fenBefore = engine.currentFen;
    final boardBefore = Map<Coord, ChessPiece>.from(engine.board.pieces);

    // 走子前生成中文记谱
    String notation;
    try {
      notation = MoveNotation.toText(engine.board.pieces, move);
    } catch (_) {
      notation = MoveNotation.formatICCS(MoveNotation.toICCS(move));
    }
    // 设置下一步走子方
    final nextTurn = move.color == PieceColor.red
        ? PieceColor.black
        : PieceColor.red;

    // 执行走子 + 切换回合
    engine.forceMove(move.from, move.to);
    final fenAfter = engine.currentFen;
    final boardAfter = Map<Coord, ChessPiece>.from(engine.board.pieces);

    final moveWithState = move
        .withNotation(notation)
        .withNextColor(nextTurn)
        .withBoardState(
          boardBefore: boardBefore,
          boardAfter: boardAfter,
          fenBefore: fenBefore,
          fenAfter: fenAfter,
        );

    gameTree.makeMove(moveWithState, fenAfter);

    lastMove = moveWithState;

    // 清除旧分析结果
    clearAnalysisResults();

    // 检查游戏结束
    _checkGameEnd();

    notifyListeners();

    // 播放音效
    _playMoveSound(moveWithState);

    // 触发分析
    _onMoveExecuted();
  }

  // ────────────────── 导航 ──────────────────

  bool goForward({int? variationIndex}) {
    final ok = gameTree.goForward(variationIndex: variationIndex);
    if (ok) {
      _syncAfterNavigate();
      _stateManager.clearSelection();
    }
    return ok;
  }

  bool goBack() {
    final ok = gameTree.goBack();
    if (ok) {
      _syncAfterNavigate();
      _stateManager.clearSelection();
    }
    return ok;
  }

  bool goToStart() {
    final ok = gameTree.goToStart();
    if (ok) {
      _syncAfterNavigate();
      _stateManager.clearSelection();
    }
    return ok;
  }

  bool goToMainLine() {
    final ok = gameTree.goToMainLine();
    if (ok) {
      _syncAfterNavigate();
      _stateManager.clearSelection();
    }
    return ok;
  }

  bool get canGoBack => gameTree.current?.parent != null;
  bool get canGoForward => gameTree.current?.hasChildren ?? false;
  int get depth => gameTree.depth;

  void _syncAfterNavigate() {
    final fen = gameTree.currentFen;
    if (fen != null) {
      engine = GameEngine(fen);
    }
    clearAnalysisResults();
    notifyListeners();
    _onMoveExecuted();
  }

  // ────────────────── 走子执行回调 ──────────────────

  void _onMoveExecuted() {
    // 有 lastMove 且 fenAfter 与当前局面一致时用它；导航后 lastMove 可能过期，需用 gameTree.currentFen
    final currentFen = gameTree.currentFen;
    final fen = (lastMove?.fenAfter != null && lastMove?.fenAfter == currentFen)
        ? lastMove!.fenAfter
        : currentFen;
    AppLogger.debug('GameViewModel', '_onMoveExecuted FEN: $fen');
    analyzePosition(fen);
  }

  // ────────────────── 局面分析（引擎 + 云库） ──────────────────

  /// 触发位置分析（引擎 + 云库）
  void analyzePosition(String? fen) {
    if (fen == null) return;
    _engineManager.analyze(fen: fen);
    _queryCloudForPosition(fen);
  }

  void _queryCloudForPosition(String fen) {
    _isCloudQuerying = true;
    notifyListeners();

    _cloudDB
        .query(fen)
        .then((result) {
          _cloudResult = result;
          _isCloudQuerying = false;
          notifyListeners();
        })
        .catchError((error) {
          _isCloudQuerying = false;
          notifyListeners();
        });
  }

  /// 停止引擎分析
  Future<void> stopAnalysis() async {
    await _engineManager.cancelAnalysis();
    notifyListeners();
  }

  /// 清除分析结果
  void clearAnalysisResults() {
    _engineManager.clearAnalysisResults();
    _cloudResult = null;
    notifyListeners();
  }

  /// 清除云库查询结果
  void clearCloudResult() {
    _cloudResult = null;
    notifyListeners();
  }

  /// 手动触发云库查询
  Future<void> queryCloud(String fen) async {
    _isCloudQuerying = true;
    notifyListeners();

    try {
      _cloudResult = await _cloudDB.query(fen);
    } catch (e) {
      AppLogger.debug('GameViewModel', 'Cloud query failed: $e');
    } finally {
      _isCloudQuerying = false;
      notifyListeners();
    }
  }

  // ────────────────── 导航回调 ──────────────────

  /// UI 状态变化回调
  void _onStateChanged() {
    notifyListeners();
  }

  /// 引擎变化回调
  void _onEngineChanged() {
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
      MoveQualityAssessor.assess(current);
    }

    notifyListeners();
  }

  // ────────────────── 管理器访问器 ──────────────────

  /// UI 状态管理器
  GameStateManager get stateManager => _stateManager;

  /// 引擎管理器
  EngineManager get engineManager => _engineManager;

  // ──────────── 游戏引擎访问器 ────────────

  PieceColor get currentTurn => engine.currentTurn;
  Board get currentBoard => engine.board;

  // ──────────── 分析结果访问器 ────────────

  /// 获取当前最佳着法
  String? get engineBestMove => _engineManager.getCurrentBestMove();

  /// 获取当前评分
  int? get engineScore => _engineManager.getCurrentScore();

  /// 获取所有分析信息
  List<EngineInfo> get engineInfos => _engineManager.allInfos;
  bool get isAnalyzing => _engineManager.isAnalyzing;
  bool get isCloudQuerying => _isCloudQuerying;
  int get cloudCacheSize => _cloudDB.cache.size;

  /// 将帅是否被将军及被将军位置
  Coord? get inCheckPosition {
    if (!engine.isInCheck(currentTurn)) return null;
    return engine.kingPosition;
  }

  // ──────────── UI 状态访问器 ────────────

  Coord? get selectedPosition => _stateManager.selectedPosition;
  List<Coord> get possibleMoves => _stateManager.possibleMoves;
  String? get bestMoveHint => _stateManager.bestMoveHint;
  PanelType get leftPanel => _stateManager.leftPanel;
  bool get isCloudPanelVisible => _stateManager.isCloudPanelVisible;

  // ──────────── 引擎配置访问器 ────────────

  EngineAnalysisMode get analysisMode => _engineManager.analysisMode;
  PriorityMode get priorityMode => _engineManager.priorityMode;
  int get multiPV => _engineManager.multiPV;
  bool get isEngineReady => _engineManager.isReady;
  bool get isEngineThinking => _engineManager.isThinking;

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
    syncEngineFromFen(puzzle.fen);
    _stateManager.clearSelection();
    notifyListeners();
  }

  // ──────────── 引擎配置方法 ────────────

  void setAnalysisMode(EngineAnalysisMode mode) {
    _engineManager.setAnalysisMode(mode);
  }

  void setPriorityMode(PriorityMode mode) {
    _engineManager.setPriorityMode(mode);
  }

  void setMultiPV(int count) {
    _engineManager.setMultiPV(count);
  }

  // ──────────── 棋子选择 ────────────

  void selectPiece(Coord pos) {
    if (gameState == GameState.checkmate) return;

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

    final piece = _getPieceAt(pos);

    // 已选棋子 → 执行走棋
    if (_stateManager.selectedPosition != null &&
        _stateManager.possibleMoves.contains(pos)) {
      final ok = manualMove(_stateManager.selectedPosition!, pos);
      if (ok) {
        _stateManager.clearSelection();
      }
      return;
    }

    // 选择己方棋子
    if (piece != null && piece.color == currentTurn) {
      _stateManager.selectPosition(pos);
      _stateManager.setPossibleMoves(
        getLegalMoves(pos).map((m) => m.to).toList(),
      );
    } else {
      _stateManager.clearSelection();
    }
  }

  // ──────────── 残局模式 ────────────

  void _handlePuzzleMove(Coord from, Coord to) {
    final piece = _getPieceAt(from);
    if (piece == null) return;

    final moveRecord = MoveRecord(
      from: from,
      to: to,
      pieceType: piece.type,
      capturedPiece: _getPieceAt(to),
      color: currentTurn,
    );

    final puzzle = _stateManager.currentPuzzle;
    if (puzzle == null) return;

    if (_stateManager.puzzleSolutionIndex < puzzle.solution.length) {
      final expectedICCS = puzzle.solution[_stateManager.puzzleSolutionIndex];
      final actualICCS = MoveNotation.toICCS(moveRecord);

      if (actualICCS == expectedICCS) {
        manualMove(from, to);
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
      engineMove(iccs);
      _stateManager.advancePuzzleSolution();
    }
  }

  // ──────────── 引擎管理 ────────────

  Future<bool> loadEngine(String enginePath) async {
    return _engineManager.loadEngine(enginePath: enginePath);
  }

  Future<void> unloadEngine() async {
    await _engineManager.unloadEngine();
  }

  Future<void> syncSettingsToEngine() async {
    await _engineManager.syncSettingsToEngine();
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
    reset();
    _stateManager.reset();
    clearAnalysisResults();
    _engineManager.newGame();
    notifyListeners();
  }

  void loadFromFen(String fen) {
    gameTree.initFromFen(fen);
    syncEngineFromFen(fen);
    _stateManager.clearSelection();
    notifyListeners();
  }

  // ──────────── 辅助方法 ────────────

  List<MoveRecord> getLegalMoves(Coord from) => engine.getLegalMoves(from);

  ChessPiece? getPieceAt(Coord pos) => engine.board.getPiece(pos);

  ChessPiece? _getPieceAt(Coord pos) => engine.board.getPiece(pos);

  void _checkGameEnd() {
    if (lastMove?.capturedPiece?.type == PieceType.king) {
      gameState = GameState.checkmate;
      return;
    }
    gameState = engine.isCheckmate(engine.currentTurn)
        ? GameState.checkmate
        : GameState.playing;
  }

  void _playMoveSound(MoveRecord move) {
    if (!soundEnabled) return;
    if (move.capturedPiece != null) {
      SoundManager.instance.playCapture();
    } else {
      SoundManager.instance.playMove();
    }
  }

  /// 重新同步引擎（从 FEN 重建引擎状态）
  void syncEngineFromFen(String fen) {
    engine = GameEngine(fen);
  }

  /// 重置为新局
  void reset() {
    gameTree.initStandard();
    engine = GameEngine(gameTree.current!.fen);
    lastMove = null;
    gameState = GameState.playing;
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

  /// 从节点路径构建记谱列表（通用方法）
  static List<String> _buildNotations(List<GameTreeNode> path) {
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

  List<String> get mainLineNotations => _buildNotations(gameTree.mainLinePath);

  List<String> get moveNotations =>
      _buildNotations(gameTree.getPathToCurrent());

  List<GameTreeNode> get variations => gameTree.current?.children ?? [];

  /// 开局信息
  OpeningInfo? get currentOpening {
    final fen = gameTree.currentFen;
    if (fen == null) return null;
    return OpeningBookService.instance.lookup(fen);
  }

  // ──────────── 启动 ────────────

  /// 启动时自动加载引擎
  Future<void> _autoLoadEngine() async {
    final enginePath = AppSettings.instance.enginePath;
    if (enginePath.isNotEmpty && !_engineManager.isReady) {
      await loadEngine(enginePath);
    }
  }
}
