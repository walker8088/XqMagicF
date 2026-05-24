import 'package:flutter/foundation.dart';
import 'package:magicf/data/endgame_puzzles.dart';
import 'package:magicf/game/game_engine.dart';
import 'package:magicf/game/move_validator.dart';
import 'package:magicf/models/board.dart';
import 'package:magicf/models/chess_piece.dart';
import 'package:magicf/models/game.dart';
import 'package:magicf/models/game_mode.dart';
import 'package:magicf/models/game_tree.dart';
import 'package:magicf/models/move.dart';
import 'package:magicf/services/cloud_db.dart';
import 'package:magicf/services/cloud_review.dart';
import 'package:magicf/services/engine_review.dart';
import 'package:magicf/services/engine_manager.dart';
import 'package:magicf/services/opening_book.dart';
import 'package:magicf/utils/constants.dart';
import 'package:magicf/utils/fen.dart';
import 'package:magicf/utils/move_notation.dart';
import 'package:magicf/utils/position.dart';
import 'package:magicf/utils/sound_manager.dart';

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

  /// 云库复盘
  CloudReviewResult? cloudReviewResult;
  double? cloudReviewProgress;
  final CloudReviewService _cloudReviewService = CloudReviewService();
  bool get isCloudReviewing => _cloudReviewService.isRunning;

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
  Position? selectedPosition;
  List<Position> possibleMoves = [];

  /// 上一步走法（用于高亮）
  MoveRecord? lastMove;

  /// 最佳着法提示（来自引擎或云库）
  String? bestMoveHint;

  /// 引擎复盘
  EngineReviewResult? engineReviewResult;
  double? engineReviewProgress;
  late final EngineReviewService _engineReviewService = EngineReviewService(
    manager: engineManager,
  );
  bool get isEngineReviewing => _engineReviewService.isRunning;

  /// 当前残局挑战
  EndgamePuzzle? currentPuzzle;
  int puzzleSolutionIndex = 0;
  bool puzzleCompleted = false;

  /// 音效开关
  bool soundEnabled = true;

  void _init() {
    gameTree.initStandard();
    _loadBoardFromTree();
    engine = GameEngine(gameTree.current!.fen);
  }

  /// 从棋谱树加载棋盘
  void _loadBoardFromTree() {
    final fen = gameTree.currentFen;
    if (fen != null) {
      final parts = fen.split(' ');
      _activeColor = parts.length > 1 && parts[1] == 'b'
          ? PieceColor.black
          : PieceColor.red;
    }
  }

  /// 当前回合方
  PieceColor _activeColor = PieceColor.red;
  PieceColor get currentTurn => _activeColor;

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
    _loadBoardFromTree();
    engine = GameEngine(gameTree.current!.fen);
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
    _loadBoardFromTree();
    engine = GameEngine(gameTree.current!.fen);
    selectedPosition = null;
    possibleMoves = [];
    lastMove = null;
    bestMoveHint = null;
    cloudResult = null;
    cloudReviewResult = null;
    cloudReviewProgress = null;
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
    _loadBoardFromTree();
    engine = GameEngine(fen);
    selectedPosition = null;
    possibleMoves = [];
    lastMove = null;
    cloudReviewResult = null;
    cloudReviewProgress = null;
    _state = GameState.playing;
    notifyListeners();
  }

  /// 选择棋子
  void selectPiece(Position pos) {
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

  void _handlePuzzleMove(Position from, Position to) {
    final moveRecord = MoveRecord(
      from: from,
      to: to,
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
      final moveRecord = MoveRecord(
        from: from,
        to: to,
        capturedPiece: _getPieceAt(to),
        color: currentTurn,
      );
      _executeMove(moveRecord);
      puzzleSolutionIndex++;
    }
  }

  void _movePiece(Position from, Position to) {
    final piece = _getPieceAt(from);
    if (piece == null) return;

    final legalMoves = _getLegalMoves(from);
    final moveRecord = MoveRecord(
      from: from,
      to: to,
      capturedPiece: _getPieceAt(to),
      color: currentTurn,
    );

    if (!legalMoves.any((m) => m.to == to)) return;

    _executeMove(moveRecord);
  }

  void _executeMove(MoveRecord move) {
    // 更新棋谱树
    final fenAfter = _simulateMove(move);
    gameTree.makeMove(move, fenAfter);

    lastMove = move;
    selectedPosition = null;
    possibleMoves = [];
    bestMoveHint = null;
    cloudResult = null;

    // 切换回合
    _activeColor = currentTurn == PieceColor.red
        ? PieceColor.black
        : PieceColor.red;

    _checkGameEnd();
    notifyListeners();

    // 播放音效
    if (move.capturedPiece != null) {
      SoundManager.instance.playCapture();
    } else {
      SoundManager.instance.playMove();
    }

    // 触发云库查询（如果需要）
    if (_priorityMode == PriorityMode.cloud &&
        (_mode == GameMode.free || _mode == GameMode.engineOnline)) {
      _queryCloudForPosition();
    }

    // 触发引擎分析（引擎辅助/连线模式）
    if (_mode == GameMode.engineAssist || _mode == GameMode.engineOnline) {
      _triggerEngineAnalysis();
    }

    // 引擎对战模式：引擎走棋
    if (_mode == GameMode.engineFight) {
      _triggerEngineFightMove();
    }
  }

  /// 模拟走子并返回新 FEN
  String _simulateMove(MoveRecord move) {
    final board = Board();
    FenParser.parse(gameTree.currentFen!, board);
    board.movePiece(move.from, move.to);
    final nextColor = currentTurn == PieceColor.red
        ? PieceColor.black
        : PieceColor.red;
    return FenParser.generate(board, nextColor);
  }

  List<MoveRecord> _getLegalMoves(Position from) {
    final piece = _getPieceAt(from);
    if (piece == null) return [];

    final board = Board();
    FenParser.parse(gameTree.currentFen!, board);

    final allPieces = board.pieces.values.toList();
    final obstacles = allPieces.map((p) => p.position).toList();
    final moves = <MoveRecord>[];

    for (int col = 0; col < AppConstants.boardCols; col++) {
      for (int row = 0; row < AppConstants.boardRows; row++) {
        final to = Position(col, row);
        final targetPiece = board.getPiece(to);
        if (targetPiece != null && targetPiece.color == piece.color) continue;

        final pieceObstacles = obstacles.where((p) => p != to).toList();
        if (MoveValidator.isValidMove(
          type: piece.type,
          color: piece.color,
          from: from,
          to: to,
          obstacles: pieceObstacles,
        )) {
          moves.add(
            MoveRecord(
              from: from,
              to: to,
              capturedPiece: targetPiece,
              color: piece.color,
            ),
          );
        }
      }
    }
    return moves;
  }

  /// 获取当前棋盘（从 FEN 解析）
  Board get currentBoard {
    final board = Board();
    final fen = gameTree.currentFen;
    if (fen != null) {
      FenParser.parse(fen, board);
    }
    return board;
  }

  ChessPiece? _getPieceAt(Position pos) {
    final board = Board();
    FenParser.parse(gameTree.currentFen!, board);
    return board.getPiece(pos);
  }

  void _checkGameEnd() {
    final board = Board();
    FenParser.parse(gameTree.currentFen!, board);

    final redGeneral = board.pieces.values.any(
      (p) => p.type == PieceType.general && p.color == PieceColor.red,
    );
    final blackGeneral = board.pieces.values.any(
      (p) => p.type == PieceType.general && p.color == PieceColor.black,
    );

    if (!redGeneral || !blackGeneral) {
      _state = GameState.checkmate;
    } else {
      _state = GameState.playing;
    }
  }

  /// 云库查询当前局面
  void _queryCloudForPosition() {
    final boardFen = gameTree.currentBoardFen;
    if (boardFen == null) return;
    cloudDB.query(boardFen);
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
    try {
      final (from, to) = MoveNotation.fromICCS(iccs);
      final piece = _getPieceAt(from);
      if (piece == null) return;

      final moveRecord = MoveRecord(
        from: from,
        to: to,
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
    final success = await engineManager.loadEngine(enginePath: enginePath);
    if (success) {
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

  /// 获取引擎最佳着法（用于显示箭头提示）
  String? get engineBestMove => engineManager.getCurrentBestMove();

  /// 获取引擎评估分数
  int? get engineScore => engineManager.getCurrentScore();

  // === 面板可见性 ===

  /// 当前显示的左侧面板: 'none', 'bookmark', 'library'
  String _leftPanel = 'none';
  String get leftPanel => _leftPanel;
  void showBookmarkPanel() {
    _leftPanel = _leftPanel == 'bookmark' ? 'none' : 'bookmark';
    notifyListeners();
  }

  void showLibraryPanel() {
    _leftPanel = _leftPanel == 'library' ? 'none' : 'library';
    notifyListeners();
  }

  void hideLeftPanel() {
    _leftPanel = 'none';
    notifyListeners();
  }

  bool get isBookmarkPanelVisible => _leftPanel == 'bookmark';
  bool get isLibraryPanelVisible => _leftPanel == 'library';

  // === 右侧面板模式 ===
  /// 'analysis' 或 'review'
  String _rightPanel = 'analysis';
  String get rightPanel => _rightPanel;
  void toggleRightPanel() {
    _rightPanel = _rightPanel == 'analysis' ? 'review' : 'analysis';
    notifyListeners();
  }

  bool get isAnalysisPanel => _rightPanel == 'analysis';
  bool get isReviewPanel => _rightPanel == 'review';

  // === 引擎复盘 ===

  /// 引擎复盘：从棋谱树根节点复盘到当前位置
  Future<void> startEngineReview() async {
    if (!engineManager.isReady) return;
    final moves = gameTree.movesFromRoot;
    if (moves.isEmpty) return;

    final fenList = <String>[];
    final iccsList = <String>[];
    final chineseList = <String>[];

    final path = <GameTreeNode>[];
    var tempNode = gameTree.current;
    while (tempNode != null) {
      path.add(tempNode);
      tempNode = tempNode.parent;
    }
    final pathRev = path.reversed.toList();

    for (int i = 0; i < pathRev.length - 1; i++) {
      fenList.add(pathRev[i].fen);
      final move = pathRev[i + 1].move!;
      iccsList.add(MoveNotation.toICCS(move));
      chineseList.add(MoveNotation.toChinese(move));
    }

    engineReviewProgress = 0.0;
    notifyListeners();

    final result = await _engineReviewService.reviewGame(
      fenList: fenList,
      playedMoveICCS: iccsList,
      playedMoveChinese: chineseList,
      depth: engineManager.depth,
      timeMs: engineManager.timeMs,
      onProgress: (current, total) {
        engineReviewProgress = total > 0 ? current / total : 0.0;
        notifyListeners();
      },
    );

    engineReviewResult = result;
    engineReviewProgress = null;
    notifyListeners();
  }

  /// 取消引擎复盘
  void cancelEngineReview() {
    _engineReviewService.cancel();
    engineReviewProgress = null;
    notifyListeners();
  }

  /// 清除引擎复盘结果
  void clearEngineReview() {
    engineReviewResult = null;
    notifyListeners();
  }

  /// 清除云库复盘结果
  void clearCloudReview() {
    cloudReviewResult = null;
    notifyListeners();
  }

  // === 导航操作 ===

  /// 前进一步
  bool goForward({int? variationIndex}) {
    final result = gameTree.goForward(variationIndex: variationIndex);
    if (result) {
      _loadBoardFromTree();
      selectedPosition = null;
      possibleMoves = [];
      notifyListeners();
    }
    return result;
  }

  /// 后退一步
  bool goBack() {
    final result = gameTree.goBack();
    if (result) {
      _loadBoardFromTree();
      selectedPosition = null;
      possibleMoves = [];
      notifyListeners();
    }
    return result;
  }

  /// 回到开始
  bool goToStart() {
    final result = gameTree.goToStart();
    if (result) {
      _loadBoardFromTree();
      selectedPosition = null;
      possibleMoves = [];
      notifyListeners();
    }
    return result;
  }

  /// 回到主变着
  bool goToMainLine() {
    final result = gameTree.goToMainLine();
    if (result) {
      _loadBoardFromTree();
      selectedPosition = null;
      possibleMoves = [];
      notifyListeners();
    }
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

  /// 当前节点的变着列表
  List<GameTreeNode> get variations => gameTree.current?.children ?? [];

  /// 云库复盘：从棋谱树根节点复盘到当前位置
  Future<void> startCloudReview() async {
    final moves = gameTree.movesFromRoot;
    if (moves.isEmpty) return;

    // 收集 FEN 列表和走法列表（从根节点遍历到当前节点）
    final fenList = <String>[];
    final iccsList = <String>[];
    final chineseList = <String>[];

    // 构建从根到当前的路径
    final path = <GameTreeNode>[];
    var tempNode = gameTree.current;
    while (tempNode != null) {
      path.add(tempNode);
      tempNode = tempNode.parent;
    }
    final pathRev = path.reversed.toList();

    // path[0] 是根节点，path[1] 是第一步后的节点，以此类推
    for (int i = 0; i < pathRev.length - 1; i++) {
      fenList.add(pathRev[i].fen);
      final move = pathRev[i + 1].move!;
      iccsList.add(MoveNotation.toICCS(move));
      chineseList.add(MoveNotation.toChinese(move));
    }

    cloudReviewProgress = 0.0;
    notifyListeners();

    final result = await _cloudReviewService.reviewGame(
      fenList: fenList,
      playedMoveICCS: iccsList,
      playedMoveChinese: chineseList,
      onProgress: (current, total) {
        cloudReviewProgress = total > 0 ? current / total : 0.0;
        notifyListeners();
      },
    );

    cloudReviewResult = result;
    cloudReviewProgress = null;
    notifyListeners();
  }

  /// 取消云库复盘
  void cancelCloudReview() {
    _cloudReviewService.cancel();
    cloudReviewProgress = null;
    notifyListeners();
  }

  bool isPositionSelected(Position pos) => selectedPosition == pos;
  bool isPossibleMove(Position pos) => possibleMoves.contains(pos);

  // === 开局识别 ===

  /// 当前局面的 ECCO 开局信息（从开局库查询）
  OpeningInfo? get currentOpening {
    final boardFen = gameTree.currentBoardFen;
    if (boardFen == null) return null;
    return OpeningBookService.instance.lookup(boardFen);
  }
}
