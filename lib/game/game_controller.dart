import 'package:xqmagic/game/game_engine.dart';
import 'package:xqmagic/models/board.dart';
import 'package:xqmagic/models/chess_piece.dart';
import 'package:xqmagic/models/game_state.dart';
import 'package:xqmagic/models/game_tree.dart';
import 'package:xqmagic/models/move.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/coord.dart';
import 'package:xqmagic/utils/move_notation.dart';
import 'package:xqmagic/utils/sound_manager.dart';

/// 游戏控制器：管理走子执行、棋谱导航、游戏状态
///
/// 从 GameViewModel 中提取，职责单一：
/// - 走子合法性校验与执行
/// - 棋谱树导航（前进/后退/回到开头/回到主干）
/// - 游戏结束判定
/// - 音效触发
///
/// 不负责：
/// - 引擎分析触发（由 AnalysisService 负责）
/// - UI 交互状态管理（由 GameStateManager 负责）
/// - 云库查询（由 AnalysisService 负责）
class GameController {
  GameController() {
    gameTree = GameTree();
    gameTree.initStandard();
    engine = GameEngine(gameTree.current!.fen);
  }

  /// 游戏逻辑引擎
  late GameEngine engine;

  /// 棋谱树
  late GameTree gameTree;

  /// 上一步走法
  MoveRecord? lastMove;

  /// 游戏状态
  GameState gameState = GameState.playing;

  /// 音效开关
  bool soundEnabled = true;

  // ──────────── 访问器 ────────────

  PieceColor get currentTurn => engine.currentTurn;
  Board get currentBoard => engine.board;
  bool get canGoBack => gameTree.current?.parent != null;
  bool get canGoForward => gameTree.current?.hasChildren ?? false;
  int get depth => gameTree.depth;

  /// 将帅是否被将军及被将军位置
  Coord? get inCheckPosition {
    if (!engine.isInCheck(currentTurn)) return null;
    return engine.kingPosition;
  }

  // ──────────── 走子 ────────────

  /// 手动走子：校验合法性后执行。返回 true 表示走子成功
  bool manualMove(Coord from, Coord to) {
    if (gameState == GameState.checkmate) return false;

    final legalMoves = engine.getLegalMoves(from);
    if (!legalMoves.any((m) => m.to == to)) return false;

    final piece = engine.board.getPiece(from);
    if (piece == null) return false;

    final move = MoveRecord(
      from: from,
      to: to,
      pieceType: piece.type,
      capturedPiece: engine.board.getPiece(to),
      color: currentTurn,
    );
    _executeMove(move);
    return true;
  }

  /// 引擎走子：从 ICCS 解析并执行。返回 true 表示走子成功
  bool engineMove(String iccs) {
    if (gameState != GameState.playing) return false;

    try {
      final (from, to) = MoveNotation.fromICCS(iccs);
      final piece = engine.board.getPiece(from);
      if (piece == null) return false;
      if (piece.color != currentTurn) return false;

      final move = MoveRecord(
        from: from,
        to: to,
        pieceType: piece.type,
        capturedPiece: engine.board.getPiece(to),
        color: currentTurn,
      );
      _executeMove(move);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 不验证规则地直接走子（用于棋谱回放/导航时 force move）
  MoveRecord? forceNavigateMove(Coord from, Coord to) {
    final piece = engine.board.getPiece(from);
    final capturedPiece = engine.board.getPiece(to);
    if (piece == null) return null;

    final move = MoveRecord(
      from: from,
      to: to,
      pieceType: piece.type,
      capturedPiece: capturedPiece,
      color: piece.color,
    );
    engine.forceMove(from, to);
    return move;
  }

  // ──────────── 核心走子 ────────────

  void _executeMove(MoveRecord move) {
    final fenBefore = engine.currentFen;
    final boardBefore = Map<Coord, ChessPiece>.from(engine.board.pieces);

    // 走子前生成中文记谱
    String notation;
    try {
      notation = MoveNotation.toText(engine.board.pieces, move);
    } catch (_) {
      notation = MoveNotation.toICCS(move);
    }

    final nextTurn = move.color == PieceColor.red
        ? PieceColor.black
        : PieceColor.red;

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

    _checkGameEnd();
    _playMoveSound(moveWithState);
  }

  // ──────────── 导航 ────────────

  bool goForward({int? variationIndex}) {
    final ok = gameTree.goForward(variationIndex: variationIndex);
    if (ok) _syncAfterNavigate();
    return ok;
  }

  bool goBack() {
    final ok = gameTree.goBack();
    if (ok) _syncAfterNavigate();
    return ok;
  }

  bool goToStart() {
    final ok = gameTree.goToStart();
    if (ok) _syncAfterNavigate();
    return ok;
  }

  bool goToMainLine() {
    final ok = gameTree.goToMainLine();
    if (ok) _syncAfterNavigate();
    return ok;
  }

  void _syncAfterNavigate() {
    final fen = gameTree.currentFen;
    if (fen != null) {
      engine = GameEngine(fen);
    }
  }

  // ──────────── 局面管理 ────────────

  void syncEngineFromFen(String fen) {
    engine = GameEngine(fen);
  }

  void newGame() {
    reset();
  }

  void loadFromFen(String fen) {
    gameTree.initFromFen(fen);
    syncEngineFromFen(fen);
  }

  void reset() {
    gameTree.initStandard();
    engine = GameEngine(gameTree.current!.fen);
    lastMove = null;
    gameState = GameState.playing;
  }

  // ──────────── 辅助方法 ────────────

  List<MoveRecord> getLegalMoves(Coord from) => engine.getLegalMoves(from);
  ChessPiece? getPieceAt(Coord pos) => engine.board.getPiece(pos);

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

  // ──────────── 记谱序列（通过 GameTree） ────────────

  List<MoveRecord> get movesFromRoot => gameTree.movesFromRoot;
  List<MoveRecord> get mainLineMoves => gameTree.mainLineMoves;
  List<GameTreeNode> get mainLinePath => gameTree.mainLinePath;

  Map<int, int> get mainLineEvaluations {
    final path = gameTree.mainLinePath;
    final evals = <int, int>{};
    for (int i = 1; i < path.length; i++) {
      final node = path[i];
      if (node.evaluation != null) {
        evals[i - 1] = node.evaluation!;
      }
    }
    return evals;
  }

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

  List<String> get mainLineNotations =>
      MoveNotation.buildNotationsFromPath(gameTree.mainLinePath);

  List<String> get moveNotations =>
      MoveNotation.buildNotationsFromPath(gameTree.getPathToCurrent());
}
