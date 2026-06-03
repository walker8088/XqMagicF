import 'package:flutter/foundation.dart';
import 'package:xqmagic/data/endgame_puzzles.dart';
import 'package:xqmagic/game/analysis_service.dart';
import 'package:xqmagic/game/board_edit_controller.dart';
import 'package:xqmagic/game/game_controller.dart';
import 'package:xqmagic/game/game_engine.dart';
import 'package:xqmagic/game/game_state_manager.dart';
import 'package:xqmagic/models/board.dart';
import 'package:xqmagic/models/board_render_data.dart';
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

  // ──────────── 棋盘编辑状态 ────────────

  late final BoardEditController _editController;

  /// 进入棋盘编辑模式前保存的原始 FEN，供 [editCancel] 恢复使用。
  /// null 表示当前未处于编辑模式快照点。
  String? _editOriginalFen;

  PieceType get editPieceType => _editController.pieceType;
  PieceColor get editPieceColor => _editController.pieceColor;
  PieceColor get editSideToMove => _editController.sideToMove;
  bool get editPlacing => _editController.placing;
  bool get isBoardEditMode => _mode == GameMode.boardEdit;

  // ──────────── 初始化 ────────────

  void _init() {
    _controller = GameController();
    _editController = BoardEditController();

    _engineManager = EngineManager(logEnabled: true);
    _analysisService = AnalysisService(
      engineManager: _engineManager,
      cloudDB: CloudDBClient(),
    );
    _stateManager = GameStateManager();

    // 云库查询完成后通知 UI
    _analysisService.onCloudResultUpdated = notifyListeners;

    // 重要：不要直接监听 _engineManager 的 ChangeNotifier，因为配置变更
    // (setMultiPV / setAnalysisMode / ...) 也会触发 notifyListeners，
    // 会污染 writeAnalysisToNode。
    // 改用专门的 onAnalysisUpdated 回调，该回调仅在 EngineAnalysisUpdate /
    // EngineBestMove 事件时触发。
    _engineManager.onAnalysisUpdated = _onAnalysisChanged;
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

  /// 棋盘渲染数据（纯数据，供 ChessBoard widget 使用）
  BoardRenderData get boardRenderData => BoardRenderData(
    pieces: currentBoard.pieces.values.toList(),
    selectedPosition: selectedPosition,
    possibleMoves: possibleMoves,
    lastMove: lastMove,
    inCheckPosition: inCheckPosition,
  );

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

  // 返回当前节点的所有子节点（主变着 + 变着）。可能为空列表。
  // 重要：不要在 getter 中新建空列表（会造成首带变着下的不必要分配）——
  // 返回的是原列表的可空包装，调用方需自己 null check。
  /// 缓存当前局面的开局信息。仅在 FEN 变更时重新查询。
  ///
  /// 背景：之前每次 UI 重建都会调用该 getter 查表。虽然 OpeningBookService
  /// 内部有 LRU 缓存，但仍然是一次 HashMap 查询与字符串参数检查。
  OpeningInfo? _currentOpeningCache;
  String? _currentOpeningFen;

  OpeningInfo? get currentOpening {
    final fen = _controller.gameTree.currentFen;
    if (fen == null) {
      _currentOpeningCache = null;
      _currentOpeningFen = null;
      return null;
    }
    if (fen == _currentOpeningFen) return _currentOpeningCache;
    _currentOpeningFen = fen;
    _currentOpeningCache = OpeningBookService.instance.lookup(fen);
    return _currentOpeningCache;
  }

  // ──────────── 走子 ────────────

  void selectPiece(Coord pos) {
    // 棋盘编辑模式：委托给 editTap
    if (isBoardEditMode) {
      editTap(pos);
      return;
    }

    if (gameState == GameState.checkmate || gameState == GameState.draw) return;

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
      _stateManager.selectWithMoves(
        pos,
        _controller.getLegalMoves(pos).map((m) => m.to).toList(),
      );
    } else {
      _stateManager.clearSelection();
    }
  }

  /// 执行引擎推荐的着法。返回 true 表示走子成功。
  ///
  /// 是外部代码（包括 UI）的唯一入口：内部走子逻辑（如残局）和外部调用
  /// 都走该方法，避免 `playEngineMove` / `engineMove` 两个方法双重实现。
  bool engineMove(String iccs) {
    final ok = _controller.engineMove(iccs);
    if (ok) {
      _stateManager.clearSelection();
      _onMoveExecuted();
    }
    return ok;
  }

  bool manualMove(Coord from, Coord to) {
    final ok = _controller.manualMove(from, to);
    if (ok) {
      _stateManager.clearSelection();
      _onMoveExecuted();
    }
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
    _stateManager.showCloudPanel();
  }

  void hideLeftPanel() {
    _stateManager.hideLeftPanel();
  }

  /// 新局：重置控制器 + UI 状态 + 分析结果 + 引擎
  void newGame() {
    _controller.reset();
    _stateManager.reset();
    _analysisService.clearAnalysisResults();
    _engineManager.newGame();
    _onPositionLoaded();
  }

  void loadFromFen(String fen) {
    _controller.loadFromFen(fen);
    _stateManager.clearSelection();
    _onPositionLoaded();
  }

  // ──────────── 模式切换 ────────────

  void setMode(GameMode mode) {
    _mode = mode;
    // 在同一 setMode 周期内多次状态变更只会触发一次 UI 重建
    _stateManager.withBatchNotify(() {
      if (mode == GameMode.engineEndGame) {
        _stateManager.initPuzzle(EndgameCollection.basicEndgames.first);
        _loadPuzzle();
      } else if (mode == GameMode.engineOnline) {
        // 连线分析模式：手动触发云库查询
        final fen = _controller.gameTree.currentFen;
        if (fen != null) {
          _analysisService.queryCloud(fen);
        }
      } else if (mode == GameMode.boardEdit) {
        // 进入棋盘编辑模式：保存原始 FEN 以供 cancel 恢复，
        // 停止分析，清除选择，重置编辑偏好。
        _editOriginalFen = _controller.gameTree.currentFen;
        _analysisService.stopAnalysis();
        _stateManager.clearSelection();
        _editController.reset();
      }
    });
    notifyListeners();
  }

  // ──────────── 棋盘编辑操作 ────────────

  void setEditPieceType(PieceType type) {
    _editController.setPieceType(type);
    notifyListeners();
  }

  void setEditPieceColor(PieceColor color) {
    _editController.setPieceColor(color);
    notifyListeners();
  }

  void setEditSideToMove(PieceColor color) {
    _editController.setSideToMove(color);
    notifyListeners();
  }

  void setEditPlacing(bool placing) {
    _editController.setPlacing(placing);
    notifyListeners();
  }

  /// 编辑模式下的点击：放置或删除棋子
  void editTap(Coord pos) {
    if (!isBoardEditMode) return;
    _editController.tap(_controller.currentBoard, pos);
    _stateManager.clearSelection();
    notifyListeners();
  }

  /// 清空棋盘
  void editClearBoard() {
    _editController.clearBoard(_controller.currentBoard);
    _stateManager.clearSelection();
    notifyListeners();
  }

  /// 初始化标准局面
  void editInitStandard() {
    _editController.initStandard(_controller.currentBoard);
    _stateManager.clearSelection();
    notifyListeners();
  }

  /// 应用编辑：从当前棋盘生成 FEN 并开始新局
  void editApply() {
    final fen = _editController.toFen(_controller.currentBoard);
    _mode = GameMode.free;
    _controller.loadFromFen(fen);
    _stateManager.clearSelection();
    _analysisService.clearAnalysisResults();
    _engineManager.newGame();
    _onPositionLoaded();
    // Apply 后快照不再有意义（局面已被 FEN 覆写），释放防止误导
    _editOriginalFen = null;
  }

  /// 取消编辑：恢复到自由模式并恢复原始局面
  ///
  /// 之前在 setMode(boardEdit) 时保存的 FEN 在此复原棋盘。引擎、云库、
  /// 选择状态一并重置，保证“取消”语义与 UI 一致。
  void editCancel() {
    _mode = GameMode.free;
    if (_editOriginalFen != null) {
      _controller.loadFromFen(_editOriginalFen!);
      _stateManager.clearSelection();
      _analysisService.clearAnalysisResults();
      _engineManager.newGame();
      _onPositionLoaded();
    } else {
      _stateManager.clearSelection();
    }
    _editOriginalFen = null;
    notifyListeners();
  }

  void _loadPuzzle() {
    final puzzle = _stateManager.currentPuzzle;
    if (puzzle == null) return;

    _controller.loadFromFen(puzzle.fen);
    _stateManager.clearSelection();
    _analysisService.clearAnalysisResults();
    _engineManager.newGame();
    _onPositionLoaded();
  }

  // ──────────── 残局模式 ────────────

  void _handlePuzzleMove(Coord from, Coord to) {
    final piece = _controller.getPieceAt(from);
    if (piece == null) return;

    final puzzle = _stateManager.currentPuzzle;
    if (puzzle == null) return;

    if (_stateManager.puzzleSolutionIndex < puzzle.solution.length) {
      final expectedICCS = puzzle.solution[_stateManager.puzzleSolutionIndex];
      // 直接用坐标计算 ICCS，不需要构造完整的 MoveRecord
      final actualICCS = MoveNotation.iccsOf(from, to);

      if (actualICCS == expectedICCS) {
        _controller.manualMove(from, to);
        _stateManager.advancePuzzleSolution();
        _onMoveExecuted();

        if (!_stateManager.puzzleCompleted) {
          _playPuzzleEngineMove();
        }
      } else {
        _stateManager.clearSelection();
        notifyListeners();
      }
    }
  }

  void _playPuzzleEngineMove() {
    final puzzle = _stateManager.currentPuzzle;
    if (puzzle == null) return;

    if (_stateManager.puzzleSolutionIndex < puzzle.solution.length) {
      final iccs = puzzle.solution[_stateManager.puzzleSolutionIndex];
      if (_controller.engineMove(iccs)) {
        _stateManager.advancePuzzleSolution();
        _onMoveExecuted();
      }
    }
  }

  // ──────────── 辅助方法 ────────────

  List<MoveRecord> getLegalMoves(Coord from) => _controller.getLegalMoves(from);
  ChessPiece? getPieceAt(Coord pos) => _controller.getPieceAt(pos);

  /// 重置：仅重置棋盘和 UI 状态（不重启引擎、不清分析）
  ///
  /// 如需重置引擎和分析，请使用 [newGame]。
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

  /// 局面被外部加载（loadFromFen / newGame / editApply / 残局初始化）后
  /// 重新触发分析与节点质量评估，与 _onMoveExecuted 行为一致。
  void _onPositionLoaded() {
    _analysisService.onPositionChanged(
      _controller.gameTree.currentFen ?? '',
      _controller.gameTree.current,
    );
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

  void _onAnalysisChanged() {
    _analysisService.writeAnalysisToNode();
    notifyListeners();
  }

  @override
  void dispose() {
    // 重置回调，避免被多次调用
    _engineManager.onAnalysisUpdated = null;
    // 同样重置云库回调，防止 dispose 后云库查询完成仍调用到已 dispose 的
    // GameViewModel.notifyListeners()。
    _analysisService.onCloudResultUpdated = null;
    _stateManager.removeListener(_onStateChanged);
    _engineManager.dispose();
    _stateManager.dispose();
    super.dispose();
  }

  // ──────────── 启动 ────────────

  Future<void> _autoLoadEngine() async {
    final enginePath = AppSettings.instance.enginePath;
    if (enginePath.isNotEmpty && !_engineManager.isReady) {
      try {
        await loadEngine(enginePath);
      } catch (e, st) {
        // 自动加载失败不应该让 ViewModel 处于不一致状态，但也不应该向上抛
        // 静默 Future 异常（main / AppLogger 在更高层兜底）
        AppLogger.error('GameViewModel', '自动加载引擎失败: $enginePath\n$e\n$st');
      }
    }
  }
}
