import 'package:flutter/foundation.dart';
import 'package:xqmagic/game/game_engine.dart';
import 'package:xqmagic/models/chess_piece.dart';
import 'package:xqmagic/models/game_state.dart';
import 'package:xqmagic/models/game_tree.dart';
import 'package:xqmagic/models/move.dart';
import 'package:xqmagic/services/engine_manager.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/coord.dart';
import 'package:xqmagic/utils/move_notation.dart';
import 'package:xqmagic/utils/sound_manager.dart';

/// 走子控制器：专注于走子规则、合法性校验、状态切换
///
/// 职责：
/// - 手动走子 / 引擎走子 统一入口
/// - 导航走子（前进、后退、跳转）
/// - 走子后状态更新
///
/// 不负责：
/// - 分析触发（由 AnalysisService 处理）
/// - 云库查询（由 AnalysisService 处理）
/// - UI 状态管理（由 GameStateManager 处理）
class GameController {
  GameController({
    required GameEngine engine,
    required this.gameTree,
    required this.engineManager,
    required this.onChanged,
    required this.soundEnabled,
    this.onMoveExecuted,
  }) : engine = engine;

  /// 游戏逻辑引擎（棋盘状态 + 合法走法生成）
  GameEngine engine;

  /// 棋谱树
  final GameTree gameTree;

  /// 引擎管理器
  final EngineManager engineManager;

  /// 状态变化回调 → ViewModel.notifyListeners()
  final VoidCallback onChanged;

  /// 音效开关
  final bool Function() soundEnabled;

  /// 走子执行完成回调（用于触发分析等后续操作）
  final VoidCallback? onMoveExecuted;

  /// 上一步走法
  MoveRecord? lastMove;

  /// 游戏状态
  GameState gameState = GameState.playing;

  /// 当前回合方
  PieceColor get currentTurn => engine.currentTurn;

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

  // ────────────────── 核心走子 ──────────────────

  void _executeMove(MoveRecord move) {
    // 走子前生成中文记谱
    String notation;
    try {
      notation = MoveNotation.toText(engine.board.pieces, move);
    } catch (_) {
      notation = MoveNotation.formatICCS(MoveNotation.toICCS(move));
    }
    final moveWithNotation = move.withNotation(notation);

    // 执行走子 + 切换回合
    engine.forceMove(move.from, move.to);
    final fenAfter = engine.currentFen;
    gameTree.makeMove(moveWithNotation, fenAfter);

    lastMove = moveWithNotation;

    // 清除旧分析结果
    engineManager.clearAnalysisResults();

    // 检查游戏结束
    _checkGameEnd();

    onChanged();

    // 播放音效
    _playMoveSound(moveWithNotation);

    // 触发后续操作（如分析）
    onMoveExecuted?.call();
  }

  // ────────────────── 导航 ──────────────────

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
    engineManager.clearAnalysisResults();
    onChanged();

    // 触发后续操作（如分析）
    onMoveExecuted?.call();
  }

  // ────────────────── 辅助方法 ──────────────────

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
    if (!soundEnabled()) return;
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
    engineManager.newGame();
  }
}
