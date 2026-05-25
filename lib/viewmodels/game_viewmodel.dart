import 'package:flutter/foundation.dart';
import 'package:xqmagic/data/endgame_puzzles.dart';
import 'package:xqmagic/game/game_engine.dart';
import 'package:xqmagic/models/board.dart';
import 'package:xqmagic/models/chess_piece.dart';
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
import 'package:xqmagic/utils/sound_manager.dart';

/// 游戏视图模型：管理 UI 状态
class GameViewModel extends ChangeNotifier {
  GameViewModel() {
    _init();
  }

  /// 棋谱树
  final GameTree gameTree = GameTree();

  /// 游戏逻辑引擎
  late GameEngine engine;

  /// 云库客户端
  final CloudDBClient cloudDB = CloudDBClient();

  /// 云库查询结果
  CloudQueryResult? cloudResult;

  /// 引擎管理器
  final EngineManager engineManager = EngineManager(logEnabled: true);

  /// 当前游戏模式
  GameMode _mode = GameMode.free;
  GameMode get mode => _mode;

  /// 当前引擎分析模式
  EngineAnalysisMode _analysisMode = EngineAnalysisMode.deep;
  EngineAnalysisMode get analysisMode => _analysisMode;

  /// 优先级模式
  PriorityMode _priorityMode = PriorityMode.engine;
  PriorityMode get priorityMode => _priorityMode;

  /// MultiPV 数量
  int _multiPV = 1;
  int get multiPV => _multiPV;

  /// 是否正在分析
  bool _isAnalyzing = false;
  bool get isAnalyzing => _isAnalyzing;

  /// 当前选中位置
  Coord? selectedPosition;
  List<Coord> possibleMoves = [];

  /// 上一步走法（用于高亮）
  MoveRecord? lastMove;

  /// 最佳着法提示（来自引擎或云库）
  String? bestMoveHint;

  /// 当前残局挑战
  EndgamePuzzle? currentPuzzle;
  int puzzleSolutionIndex = 0;
  bool puzzleCompleted = false;

  /// 音效开关
  bool soundEnabled = true;

  void _init() {
    gameTree.initStandard();
    engine = GameEngine(gameTree.current!.fen);

    // 监听云库查询结果
    cloudDB.addListener((result) {
      cloudResult = result;
      debugPrint(
        '[GameViewModel] 云库查询: ${result?.moves.length ?? 0} 条着法, '
        '最佳=${result?.bestMove ?? "无"}',
      );
      notifyListeners();
    });

    // 转发引擎状态变更通知到 UI
    engineManager.addListener(() {
      notifyListeners();
    });

    // 初始化时查询开局局面的云库结果
    _queryCloudForPosition();
  }

  /// 从棋谱树同步引擎状态
  void _syncEngineFromTree() {
    final fen = gameTree.currentFen;
    if (fen != null) {
      engine = GameEngine(fen);
    }
  }

  /// 当前回合方（委托给引擎）
  PieceColor get currentTurn => engine.currentTurn;

  /// 游戏状态
  GameState _state = GameState.playing;
  GameState get state => _state;

  /// 切换游戏模式
  void setMode(GameMode mode) {
    _mode = mode;
    if (mode == GameMode.engineEndGame) {
      currentPuzzle = EndgameCollection.basicEndgames.first;
      puzzleSolutionIndex = 0;
      puzzleCompleted = false;
      _loadPuzzle();
    }
    notifyListeners();
  }

  /// 加载残局
  void _loadPuzzle() {
    if (currentPuzzle == null) return;
    gameTree.initFromFen(currentPuzzle!.fen);
    _syncEngineFromTree();
    selectedPosition = null;
    possibleMoves = [];
    puzzleSolutionIndex = 0;
    puzzleCompleted = false;
    notifyListeners();
  }

  /// 设置分析模式
  void setAnalysisMode(EngineAnalysisMode mode) {
    _analysisMode = mode;
    notifyListeners();
  }

  /// 设置优先级模式
  void setPriorityMode(PriorityMode mode) {
    _priorityMode = mode;
    notifyListeners();
  }

  /// 设置 MultiPV
  void setMultiPV(int count) {
    _multiPV = count;
    notifyListeners();
  }

  /// 新局
  void newGame() {
    gameTree.initStandard();
    _syncEngineFromTree();
    selectedPosition = null;
    possibleMoves = [];
    lastMove = null;
    bestMoveHint = null;
    cloudResult = null;
    _state = GameState.playing;
    puzzleCompleted = false;
    puzzleSolutionIndex = 0;
    _isAnalyzing = false;
    engineManager.newGame();
    notifyListeners();
  }

  /// 编辑局面：从 FEN 加载
  void loadFromFen(String fen) {
    gameTree.initFromFen(fen);
    _syncEngineFromTree();
    selectedPosition = null;
    possibleMoves = [];
    lastMove = null;
    _state = GameState.playing;
    notifyListeners();
  }

  /// 选择棋子
  void selectPiece(Coord pos) {
    if (state == GameState.checkmate) return;

    // 残局模式：如果轮到人走且是红方，验证是否走的是解法中的着法
    if (_mode == GameMode.engineEndGame &&
        currentPuzzle != null &&
        !puzzleCompleted) {
      if (selectedPosition != null && possibleMoves.contains(pos)) {
        _handlePuzzleMove(selectedPosition!, pos);
        return;
      }
    }

    // 引擎对战模式：只允许走己方棋子
    if (_mode == GameMode.engineFight) {
      // 如果轮到引擎走，忽略
      // 这里简化处理，实际应由引擎控制
    }

    final piece = _getPieceAt(pos);

    // 如果已选棋子且点击的是可行位置，则走棋
    if (selectedPosition != null && possibleMoves.contains(pos)) {
      _movePiece(selectedPosition!, pos);
      return;
    }

    // 只选中当前回合方的棋子
    if (piece != null && piece.color == currentTurn) {
      selectedPosition = pos;
      possibleMoves = _getLegalMoves(pos).map((m) => m.to).toList();
      notifyListeners();
    } else {
      selectedPosition = null;
      possibleMoves = [];
      notifyListeners();
    }
  }

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

    // 检查是否是正确解法
    if (puzzleSolutionIndex < currentPuzzle!.solution.length) {
      final expectedICCS = currentPuzzle!.solution[puzzleSolutionIndex];
      final actualICCS = MoveNotation.toICCS(moveRecord);

      if (actualICCS == expectedICCS) {
        // 正确着法
        _executeMove(moveRecord);
        puzzleSolutionIndex++;

        if (puzzleSolutionIndex >= currentPuzzle!.solution.length) {
          puzzleCompleted = true;
          _state = GameState.checkmate;
        } else {
          // 引擎走下一步（黑方应着）
          _playPuzzleEngineMove();
        }
      } else {
        // 错误着法，不走棋
        selectedPosition = null;
        possibleMoves = [];
        notifyListeners();
      }
    }
  }

  void _playPuzzleEngineMove() {
    if (puzzleSolutionIndex < currentPuzzle!.solution.length) {
      final iccs = currentPuzzle!.solution[puzzleSolutionIndex];
      final (from, to) = MoveNotation.fromICCS(iccs);
      final piece = _getPieceAt(from);
      if (piece == null) return;
      final moveRecord = MoveRecord(
        from: from,
        to: to,
        pieceType: piece.type,
        capturedPiece: _getPieceAt(to),
        color: currentTurn,
      );
      _executeMove(moveRecord);
      puzzleSolutionIndex++;
    }
  }

  void _movePiece(Coord from, Coord to) {
    if (_state != GameState.playing) return;

    final piece = _getPieceAt(from);
    if (piece == null) return;

    final legalMoves = _getLegalMoves(from);
    final moveRecord = MoveRecord(
      from: from,
      to: to,
      pieceType: piece.type,
      capturedPiece: _getPieceAt(to),
      color: currentTurn,
    );

    if (!legalMoves.any((m) => m.to == to)) return;

    _executeMove(moveRecord);
  }

  void _executeMove(MoveRecord move) {
    // 走子前生成中文记谱（需要当前棋盘状态处理同线多子）
    final notation = MoveNotation.toText(engine.board.pieces, move);
    final moveWithNotation = move.withNotation(notation);

    // 在引擎上执行走子，然后记录新 FEN 到棋谱树
    engine.forceMove(move.from, move.to);
    final fenAfter = engine.currentFen;
    gameTree.makeMove(moveWithNotation, fenAfter);

    lastMove = moveWithNotation;
    selectedPosition = null;
    possibleMoves = [];
    bestMoveHint = null;
    cloudResult = null;

    _checkGameEnd();
    notifyListeners();

    _playMoveSound(moveWithNotation);
    _triggerAutoAnalysis();
  }

  /// 播放走子音效（与核心逻辑分离）
  void _playMoveSound(MoveRecord move) {
    if (!soundEnabled) return;
    if (move.capturedPiece != null) {
      SoundManager.instance.playCapture();
    } else {
      SoundManager.instance.playMove();
    }
  }

  /// 触发自动分析（云库/引擎）
  void _triggerAutoAnalysis() {
    // 云库查询：走子后自动查询
    if (_mode == GameMode.free || _mode == GameMode.engineOnline) {
      _queryCloudForPosition();
    }

    // 引擎分析
    if (_mode == GameMode.engineAssist || _mode == GameMode.engineOnline) {
      _triggerEngineAnalysis();
    }

    // 引擎对战
    if (_mode == GameMode.engineFight) {
      _triggerEngineFightMove();
    }
  }

  /// 获取合法走法（委托给引擎）
  List<MoveRecord> _getLegalMoves(Coord from) => engine.getLegalMoves(from);

  /// 获取当前棋盘（委托给引擎）
  Board get currentBoard => engine.board;

  /// 获取指定位置的棋子（委托给引擎）
  ChessPiece? _getPieceAt(Coord pos) => engine.board.getPiece(pos);

  /// 检查游戏是否结束
  void _checkGameEnd() {
    // 检查上一步是否吃掉了敌方的将/帅
    if (lastMove?.capturedPiece?.type == PieceType.king) {
      _state = GameState.checkmate;
      return;
    }

    if (engine.isCheckmate(engine.currentTurn)) {
      _state = GameState.checkmate;
    } else {
      _state = GameState.playing;
    }
  }

  /// 云库查询当前局面
  void _queryCloudForPosition() {
    final fen = gameTree.currentFen;
    if (fen == null) return;
    cloudDB.query(fen);
  }

  // === 引擎相关 ===

  /// 触发引擎分析当前局面
  Future<void> _triggerEngineAnalysis() async {
    final fen = gameTree.currentFen;
    if (fen == null) return;
    if (!engineManager.isReady) return;

    await engineManager.analyze(fen: fen);
  }

  /// 触发引擎对战走子
  Future<void> _triggerEngineFightMove() async {
    final fen = gameTree.currentFen;
    if (fen == null) return;
    if (!engineManager.isReady) return;

    final bestMove = await engineManager.getFightMove(fen: fen);
    if (bestMove != null && bestMove.isNotEmpty) {
      // 延迟一下再走子，模拟思考时间
      await Future.delayed(const Duration(milliseconds: 300));
      playEngineMove(bestMove);
    }
  }

  /// 执行引擎走子（ICCS 格式）
  void playEngineMove(String iccs) {
    if (_state != GameState.playing) return;

    try {
      final (from, to) = MoveNotation.fromICCS(iccs);
      final piece = _getPieceAt(from);
      if (piece == null) return;

      final moveRecord = MoveRecord(
        from: from,
        to: to,
        pieceType: piece.type,
        capturedPiece: _getPieceAt(to),
        color: currentTurn,
      );
      _executeMove(moveRecord);
    } catch (_) {
      // ICCS 解析失败，忽略
    }
  }

  /// 切换引擎分析开关
  Future<void> toggleAnalysis() async {
    if (_isAnalyzing) {
      // 停止分析
      if (engineManager.isThinking) {
        await engineManager.cancelAnalysis();
      }
      _isAnalyzing = false;
    } else {
      // 开始分析
      if (!engineManager.isReady) {
        // 引擎未就绪，尝试加载
        _isAnalyzing = false;
        notifyListeners();
        return;
      }
      _isAnalyzing = true;
      await _triggerEngineAnalysis();
    }
    notifyListeners();
  }

  /// 加载引擎
  Future<bool> loadEngine(String enginePath) async {
    // 加载前同步协议设置
    engineManager.setProtocol(AppSettings.instance.engineProtocol);
    final success = await engineManager.loadEngine(enginePath: enginePath);
    if (success) {
      // 加载成功自动切换到引擎辅助模式
      if (_mode == GameMode.free) {
        _mode = GameMode.engineAssist;
      }
      engineManager.setDepth(_analysisMode.depth);
      engineManager.setTimeMs(_analysisMode.timeMs);
      engineManager.setMultiPV(_multiPV);
    }
    notifyListeners();
    return success;
  }

  /// 卸载引擎
  Future<void> unloadEngine() async {
    _isAnalyzing = false;
    await engineManager.unloadEngine();
    notifyListeners();
  }

  /// 将 AppSettings 中的配置同步到运行中的引擎
  /// 在设置对话框保存后调用
  Future<void> syncSettingsToEngine() async {
    final settings = AppSettings.instance;
    engineManager.setProtocol(settings.engineProtocol);
    engineManager.setDepth(settings.engineDepth);
    engineManager.setThreads(settings.engineThreads);
    engineManager.setHash(settings.engineHash);
    engineManager.setSkillLevel(settings.engineSkillLevel);
    engineManager.setMultiPV(settings.multiPV);
    await engineManager.applyConfiguration();
  }

  /// 获取引擎最佳着法（用于显示箭头提示）
  String? get engineBestMove => engineManager.getCurrentBestMove();

  /// 获取引擎评估分数
  int? get engineScore => engineManager.getCurrentScore();

  /// 获取引擎所有 PV 线路
  List<EngineInfo> get engineInfos => engineManager.allInfos;

  // === 面板可见性 ===

  /// 当前显示的面板: 'none', 'cloud'
  String _leftPanel = 'cloud';
  String get leftPanel => _leftPanel;
  void showCloudPanel() {
    _leftPanel = _leftPanel == 'cloud' ? 'none' : 'cloud';
    notifyListeners();
  }

  void hideLeftPanel() {
    _leftPanel = 'none';
    notifyListeners();
  }

  bool get isCloudPanelVisible => _leftPanel == 'cloud';

  /// 云库是否正在查询中
  bool get isCloudQuerying => cloudDB.isQuerying;

  // === 导航操作 ===

  void _clearSelection() {
    selectedPosition = null;
    possibleMoves = [];
  }

  void _syncAndClear() {
    _syncEngineFromTree();
    _clearSelection();
    notifyListeners();
  }

  /// 前进一步
  bool goForward({int? variationIndex}) {
    final result = gameTree.goForward(variationIndex: variationIndex);
    if (result) _syncAndClear();
    return result;
  }

  /// 后退一步
  bool goBack() {
    final result = gameTree.goBack();
    if (result) _syncAndClear();
    return result;
  }

  /// 回到开始
  bool goToStart() {
    final result = gameTree.goToStart();
    if (result) _syncAndClear();
    return result;
  }

  /// 回到主变着
  bool goToMainLine() {
    final result = gameTree.goToMainLine();
    if (result) _syncAndClear();
    return result;
  }

  /// 是否有上一步
  bool get canGoBack => gameTree.current?.parent != null;

  /// 是否有下一步
  bool get canGoForward => gameTree.current?.hasChildren ?? false;

  /// 当前深度
  int get depth => gameTree.depth;

  /// 走法序列
  List<MoveRecord> get movesFromRoot => gameTree.movesFromRoot;

  /// 完整主变着线（不受当前导航位置影响）
  List<MoveRecord> get mainLineMoves => gameTree.mainLineMoves;

  /// 完整主变着线的中文记法
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

  /// 走法序列的中文记法（优先使用 MoveRecord 中已存储的记谱）
  List<String> get moveNotations {
    final path = gameTree.getPathToCurrent();
    final notations = <String>[];
    for (int i = 0; i < path.length - 1; i++) {
      final move = path[i + 1].move!;
      // 优先使用已存储的记谱，否则重新生成
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

  /// 当前节点的变着列表
  List<GameTreeNode> get variations => gameTree.current?.children ?? [];

  bool isPositionSelected(Coord pos) => selectedPosition == pos;
  bool isPossibleMove(Coord pos) => possibleMoves.contains(pos);

  // === 开局识别 ===

  /// 当前局面的 ECCO 开局信息（从开局库查询）
  OpeningInfo? get currentOpening {
    final fen = gameTree.currentFen;
    if (fen == null) return null;
    return OpeningBookService.instance.lookup(fen);
  }
}
