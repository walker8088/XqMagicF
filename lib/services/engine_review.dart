import 'dart:async';

import 'package:magicf/services/engine_manager.dart';
import 'package:magicf/services/uci_engine.dart';

/// 引擎复盘：单步着法评估结果
class EngineReviewMove {
  EngineReviewMove({
    required this.moveNumber,
    required this.moveICCS,
    required this.moveChinese,
    required this.fen,
    this.bestMoveICCS,
    this.bestScore,
    this.playedScore,
    this.depth = 0,
    this.pv = const [],
    this.isMate = false,
    this.nodes = 0,
    this.timeMs = 0,
  });

  final int moveNumber;
  final String moveICCS;
  final String moveChinese;
  final String fen;
  final String? bestMoveICCS;
  final int? bestScore;
  final int? playedScore;
  final int depth;
  final List<String> pv;
  final bool isMate;
  final int nodes;
  final int timeMs;

  /// 与最佳着法的分数差
  int get diff {
    if (playedScore == null || bestScore == null) return 0;
    return playedScore! - bestScore!;
  }

  /// 着法质量标记
  String get qualityMark {
    if (playedScore == null) return '?';
    final d = diff;
    if (d >= -5) return '';
    if (d >= -30) return '★';
    if (d >= -70) return '✓';
    if (d >= -100) return '✗';
    return '✗✗';
  }
}

/// 引擎复盘结果
class EngineReviewResult {
  EngineReviewResult({
    required this.startFen,
    required this.moves,
    this.engineName = '',
  });

  final String startFen;
  final List<EngineReviewMove> moves;
  final String engineName;

  int get totalMoves => moves.length;
  int get accuracyMoves => moves.where((m) => m.diff >= -30).length;
  int get badMoves => moves.where((m) => m.diff < -100).length;

  double get averageDiff {
    if (moves.isEmpty) return 0.0;
    return moves.map((m) => m.diff).reduce((a, b) => a + b) / moves.length;
  }
}

/// 引擎复盘服务 - 通过 EngineManager 进行逐着分析
class EngineReviewService {
  EngineReviewService({EngineManager? manager}) : _manager = manager;

  final EngineManager? _manager;
  bool _isRunning = false;

  bool get isRunning => _isRunning;

  /// 取消复盘
  void cancel() {
    _isRunning = false;
  }

  /// 复盘对局
  Future<EngineReviewResult?> reviewGame({
    required List<String> fenList,
    required List<String> playedMoveICCS,
    List<String>? playedMoveChinese,
    int depth = 15,
    int timeMs = 2000,
    void Function(int current, int total)? onProgress,
  }) async {
    if (_manager == null || !_manager!.isReady) return null;
    if (fenList.isEmpty || playedMoveICCS.isEmpty) return null;

    _isRunning = true;
    final moveCount = playedMoveICCS.length;
    if (fenList.length < moveCount) return null;

    final reviewMoves = <EngineReviewMove>[];

    for (int i = 0; i < moveCount; i++) {
      if (!_isRunning) return null;

      final positionFen = fenList[i];
      final playedICCS = playedMoveICCS[i];
      final playedChinese =
          playedMoveChinese != null && i < playedMoveChinese.length
          ? playedMoveChinese[i]
          : playedICCS;

      // 通过 EngineManager 分析当前局面
      await _manager!.analyzeByDepth(fen: positionFen, depth: depth);

      // 等待分析完成
      final info = await _waitForAnalysisResult();

      if (info != null) {
        final playedMoveInfo =
            info.pv.contains(playedICCS) || info.bestMoveICCS == playedICCS;
        final playedScore = playedMoveInfo ? info.score : null;

        reviewMoves.add(
          EngineReviewMove(
            moveNumber: i + 1,
            moveICCS: playedICCS,
            moveChinese: playedChinese,
            fen: positionFen,
            bestMoveICCS: info.bestMoveICCS,
            bestScore: info.score,
            playedScore: playedScore,
            depth: info.depth,
            pv: info.pv,
            isMate: info.isMate,
            nodes: info.nodes,
            timeMs: info.timeMs,
          ),
        );
      }

      onProgress?.call(i + 1, moveCount);
    }

    _isRunning = false;

    return EngineReviewResult(
      startFen: fenList.first,
      moves: reviewMoves,
      engineName: _manager!.engineName,
    );
  }

  Future<EngineInfo?> _waitForAnalysisResult({int timeoutMs = 30000}) async {
    final sw = Stopwatch()..start();
    EngineInfo? lastInfo;

    while (sw.elapsedMilliseconds < timeoutMs) {
      if (!_isRunning) return null;
      await Future.delayed(const Duration(milliseconds: 100));

      final infos = _manager!.allInfos;
      if (infos.isNotEmpty) {
        lastInfo = infos.firstWhere(
          (info) => info.multipv == 1,
          orElse: () => infos.first,
        );
        // 如果深度达到要求，返回结果
        if (lastInfo.depth >= _manager!.depth) {
          return lastInfo;
        }
      }

      // 如果引擎已经停止思考（状态变为 ready），说明分析完成
      if (_manager!.isReady && lastInfo != null && lastInfo.depth > 0) {
        return lastInfo;
      }
    }

    return lastInfo;
  }
}
