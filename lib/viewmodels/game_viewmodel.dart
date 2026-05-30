import 'package:flutter/foundation.dart';
import 'package:xqmagic/data/endgame_puzzles.dart';
import 'package:xqmagic/game/analysis_service.dart';
import 'package:xqmagic/game/game_controller.dart';
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
import 'package:xqmagic/utils/app_settings.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/coord.dart';
import 'package:xqmagic/utils/move_notation.dart';

/// 游戏视图模型：协调 GameController、AnalysisService、EngineManager 和 GameStateManager
///
/// 职责简化为：
/// - 持有各子模块引用（GameController、AnalysisService、EngineManager、GameStateManager）
/// - 监听子模块变化并通知 UI
/// - 处理残局模式（Puzzle）的特殊逻辑
/// - 暴露统一的 façade API 给 Widget
class GameViewModel extends ChangeNotifier {
  GameViewModel() {
    _init();
  }

  // ──────────── 子模块 ────────────

  late final GameController _controller;

  /// UI 状态管理器
  late final GameStateManager _stateManager;

  /// 引擎管理器
  late final EngineManager _engineManager;

  /// 局面分析服务
  late final AnalysisService _analysisService;

  // ──────────── 游戏模式 ────────────

  GameMode _mode = GameMode.free;
  GameMode get mode => _mode;

  /// 音效开关
  bool soundEnabled = true;

  // ──────────── 初始化 ────────────

  void _init() {
    _controller = GameController();

    _engineManager = EngineManager(logEnabled: true);
    _analysisService = AnalysisService(
      engineManager: _engineManager,
      cloudDB: CloudDBClient(),
    );
    _stateManager = GameStateManager();

    // 监听子模块状态变化 → 通知 UI
    _engineManager.addListener(_onEngineChanged);
    _engineManager.addListener(_onAnalysisChanged);
    _stateManager.addListener(_onStateChanged);

    // 初始云库查询
    final fen = _controller.gameTree.currentFen;
    if (fen != null) {
      _analysisService.queryCloud(fen);
    }

    _autoLoadEngine();
  }

  // ────────────────── 外部可见属性（保持 GameScreen 兼容） ──────────────────

  // GameController 代理
  GameEngine get engine => _controller.engine;
  GameTree get gameTree => _controller.gameTree;
  MoveRecord? get lastMove => _controller.lastMove;
  GameState get gameState => _controller.gameState;
  PieceColor get currentTurn => _controller.currentTurn;
  Board get currentBoard => _controller.currentBoard;
  bool get canGoBack => _controller.canGoBack;
  bool get canGoForward => _controller.canGoForward;
  int get depth => _controller.depth;
  Coord? get inCheckPosition => _controller.inCheckPosition;

  // StateManager 代理
  GameStateManager get stateManager => _stateManager;
  Coord? get selectedPosition => _stateManager.selectedPosition;
  List<Coord> get possibleMoves => _stateManager.possibleMoves;
  String? get bestMoveHint => _stateManager.bestMoveHint;
  PanelType get leftPanel => _stateManager.leftPanel;
  bool get isCloudPanelVisible => _stateManager.isCloudPanelVisible;

  // EngineManager 代理
  EngineManager get engineManager => _engineManager;
  EngineAnalysisMode get analysisMode => _engineManager.analysisMode;
  PriorityMode get priorityMode => _engineManager.priorityMode;
  int get multiPV => _engineManager.multiPV;
  bool get isEngineReady => _engineManager.isReady;
  bool get isEngineThinking => _engineManager.isThinking;

  // AnalysisService 代理
  CloudQueryResult? get cloudResult => _analysisService.cloudResult;
  bool get isCloudQuerying => _analysisService.isCloudQuerying;
  bool get isAnalyzing => _analysisService.isAnalyzing;
  String? get engineBestMove => _analysisService.bestMove;
  int? get engineScore => _analysisService.score;
  List<EngineInfo> get engineInfos => _analysisService.engineInfos;
  int get cloudCacheSize => _analysisService.cloudCacheSize;

  // ──────────── 记谱序列 ────────────

  List<MoveRecord> get movesFromRoot => _controller.movesFromRoot;
  List<MoveRecord> get mainLineMoves => _controller.mainLineMoves;
  Map<int, int> get mainLineEvaluations => _controller.mainLineEvaluations;
  Map<int, String> get mainLineAnnotations => _controller.mainLineAnnotations;
  List<String> get mainLineNotations => _controller.mainLineNotations;
  List<String> get moveNotations => _controller.moveNotations;

  List<GameTreeNode> get variations =>
      _controller.gameTree.current?.children ?? [];

  OpeningInfo? get currentOpening {
    final fen = _controller.gameTree.currentFen;
    if (fen == null) return null;
    return OpeningBookService.instance.lookup(fen);
  }

  // ──────────── 走子 ────────────

  void selectPiece(Coord pos) {
    if (gameState == GameState.checkmate) return;

    // 残局模式特殊处理
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
        _onMoveExecuted();
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

  void playEngineMove(String iccs) {
    final ok = _controller.engineMove(iccs);
    if (ok) {
      _stateManager.clearSelection();
      _onMoveExecuted();
    }
  }

  bool manualMove(Coord from, Coord to) {
    final ok = _controller.manualMove(from, to);
    if (ok) _onMoveExecuted();
    return ok;
  }

  bool engineMove(String iccs) {
    final ok = _controller.engineMove(iccs);
    if (ok) _onMoveExecuted();
    return ok;
  }

  // ──────────── 导航 ────────────

  bool goForward({int? variationIndex}) {
    final ok = _controller.goForward(variationIndex: variationIndex);
    if (ok) {
      _stateManager.clearSelection();
      _onNavigate();
    }
    return ok;
  }

  bool goBack() {
    final ok = _controller.goBack();
    if (ok) {
      _stateManager.clearSelection();
      _onNavigate();
    }
    return ok;
  }

  bool goToStart() {
    final ok = _controller.goToStart();
    if (ok) {
      _stateManager.clearSelection();
      _onNavigate();
    }
    return ok;
  }

  bool goToMainLine() {
    final ok = _controller.goToMainLine();
    if (ok) {
      _stateManager.clearSelection();
      _onNavigate();
    }
    return ok;
  }

  // ──────────── 引擎/分析操作 ────────────

  Future<void> stopAnalysis() async {
    await _analysisService.stopAnalysis();
    notifyListeners();
  }

  void clearAnalysisResults() {
    _analysisService.clearAnalysisResults();
    notifyListeners();
  }

  void clearCloudResult() {
    _analysisService.clearCloudResult();
    notifyListeners();
  }

  Future<void> queryCloud(String fen) async {
    await _analysisService.queryCloud(fen);
    notifyListeners();
  }

  // ──────────── 引擎配置 ────────────

  void setAnalysisMode(EngineAnalysisMode mode) {
    _engineManager.setAnalysisMode(mode);
  }

  void setPriorityMode(PriorityMode mode) {
    _engineManager.setPriorityMode(mode);
  }

  void setMultiPV(int count) {
    _engineManager.setMultiPV(count);
  }

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
    _controller.reset();
    _stateManager.reset();
    _analysisService.clearAnalysisResults();
    _engineManager.newGame();
    notifyListeners();
  }

  void loadFromFen(String fen) {
    _controller.loadFromFen(fen);
    _stateManager.clearSelection();
    notifyListeners();
  }

  // ──────────── 模式切换 ────────────

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

    _controller.gameTree.initFromFen(puzzle.fen);
    _controller.syncEngineFromFen(puzzle.fen);
    _stateManager.clearSelection();
    notifyListeners();
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
      notifyListeners();
    }
  }

  void _playPuzzleEngineMove() {
    final puzzle = _stateManager.currentPuzzle;
    if (puzzle == null) return;

    if (_stateManager.puzzleSolutionIndex < puzzle.solution.length) {
      final iccs = puzzle.solution[_stateManager.puzzleSolutionIndex];
      _controller.engineMove(iccs);
      _stateManager.advancePuzzleSolution();
      notifyListeners();
    }
  }

  // ──────────── 辅助方法 ────────────

  List<MoveRecord> getLegalMoves(Coord from) => _controller.getLegalMoves(from);
  ChessPiece? getPieceAt(Coord pos) => _controller.getPieceAt(pos);

  void syncEngineFromFen(String fen) {
    _controller.syncEngineFromFen(fen);
  }

  void reset() {
    _controller.reset();
    _stateManager.reset();
  }

  // ──────────── 回调 ────────────

  void _onMoveExecuted() {
    final currentFen = _controller.gameTree.currentFen;
    if (currentFen != null) {
      _analysisService.onPositionChanged(
        currentFen,
        _controller.gameTree.current,
      );
    }
    notifyListeners();
  }

  void _onNavigate() {
    _analysisService.clearAnalysisResults();
    final currentFen = _controller.gameTree.currentFen;
    if (currentFen != null) {
      _analysisService.onPositionChanged(
        currentFen,
        _controller.gameTree.current,
      );
    }
    notifyListeners();
  }

  void _onStateChanged() {
    notifyListeners();
  }

  void _onEngineChanged() {
    notifyListeners();
  }

  void _onAnalysisChanged() {
    _analysisService.writeAnalysisToNode(_controller.gameTree.current);
    notifyListeners();
  }

  // ──────────── 启动 ────────────

  Future<void> _autoLoadEngine() async {
    final enginePath = AppSettings.instance.enginePath;
    if (enginePath.isNotEmpty && !_engineManager.isReady) {
      await loadEngine(enginePath);
    }
  }
}
