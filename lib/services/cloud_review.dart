import 'dart:async';

import 'package:xqmagic/services/cloud_db.dart';

/// 云库复盘：单步着法评估
class CloudReviewMove {
  CloudReviewMove({
    required this.moveNumber,
    required this.moveICCS,
    required this.moveChinese,
    required this.playedScore,
    required this.bestScore,
    required this.bestMoveICCS,
    required this.diff,
    required this.qualityMark,
    required this.fen,
  });

  /// 着法序号（从 1 开始）
  final int moveNumber;

  /// ICCS 坐标记法
  final String moveICCS;

  /// 中文记法
  final String moveChinese;

  /// 实际走法的云库评分
  final int? playedScore;

  /// 云库最佳着法评分
  final int? bestScore;

  /// 云库推荐的最佳着法
  final String? bestMoveICCS;

  /// 与最佳着法的分数差（playedScore - bestScore）
  final int diff;

  /// 着法质量标记（★ ✓ ✗ ✗✗）
  final String qualityMark;

  /// 走子前的局面 FEN
  final String fen;
}

/// 云库复盘结果
class CloudReviewResult {
  CloudReviewResult({required this.positionFen, required this.moves});

  /// 起始局面 FEN
  final String positionFen;

  /// 复盘着法列表
  final List<CloudReviewMove> moves;

  /// 总着法数
  int get totalMoves => moves.length;

  /// 准确着法数（偏离 ≤ 30 分）
  int get accuracyMoves => moves.where((m) => m.diff >= -30).length;

  /// 劣着数（偏离 > 100 分）
  int get badMoves => moves.where((m) => m.diff < -100).length;

  /// 平均偏离分
  double get averageDiff {
    if (moves.isEmpty) return 0.0;
    return moves.map((m) => m.diff).reduce((a, b) => a + b) / moves.length;
  }
}

/// 云库复盘服务
class CloudReviewService {
  CloudReviewService({CloudDBClient? client})
    : _client = client ?? CloudDBClient();

  final CloudDBClient _client;
  Completer<void>? _cancelCompleter;

  bool get isRunning => _cancelCompleter != null;

  /// 取消正在进行的复盘
  void cancel() {
    _cancelCompleter?.complete();
    _cancelCompleter = null;
  }

  /// 复盘对局
  ///
  /// [fenList] 局面 FEN 列表（N+1 个局面，对应 N 步棋）
  /// [playedMoveICCS] 实际走法 ICCS 列表（N 步）
  /// [playedMoveChinese] 实际走法中文记法列表（N 步，可选）
  /// [onProgress] 进度回调 (current, total)
  Future<CloudReviewResult?> reviewGame({
    required List<String> fenList,
    required List<String> playedMoveICCS,
    List<String>? playedMoveChinese,
    void Function(int current, int total)? onProgress,
  }) async {
    if (fenList.isEmpty || playedMoveICCS.isEmpty) return null;

    // 局面数应比走法数多 1
    final moveCount = playedMoveICCS.length;
    if (fenList.length < moveCount) return null;

    _cancelCompleter = Completer<void>();

    final reviewMoves = <CloudReviewMove>[];
    final startFen = fenList.first;

    try {
      for (int i = 0; i < moveCount; i++) {
        // 检查取消
        if (_cancelCompleter!.isCompleted) return null;

        final positionFen = fenList[i];
        final playedICCS = playedMoveICCS[i];
        final playedChinese =
            playedMoveChinese != null && i < playedMoveChinese.length
            ? playedMoveChinese[i]
            : playedICCS;

        // 查询云库
        final result = await _client.query(positionFen);

        if (result != null) {
          // 找到实际走法的评分
          final playedMoveInfo = result.moves
              .where((m) => m.iccs == playedICCS)
              .firstOrNull;
          final playedScore = playedMoveInfo?.score;

          final diff = playedScore != null ? playedScore - result.bestScore : 0;

          // 获取着法质量标记
          String qualityMark;
          if (playedScore == null) {
            qualityMark = '?';
          } else {
            qualityMark = _getQualityMark(diff);
          }

          reviewMoves.add(
            CloudReviewMove(
              moveNumber: i + 1,
              moveICCS: playedICCS,
              moveChinese: playedChinese,
              playedScore: playedScore,
              bestScore: result.bestScore,
              bestMoveICCS: result.bestMove,
              diff: diff,
              qualityMark: qualityMark,
              fen: positionFen,
            ),
          );
        }

        onProgress?.call(i + 1, moveCount);

        // 非最后一步时等待 500ms 限速
        if (i < moveCount - 1 && _cancelCompleter!.isCompleted == false) {
          await Future.any([
            Future.delayed(const Duration(milliseconds: 500)),
            _cancelCompleter!.future,
          ]);
        }
      }
    } finally {
      _cancelCompleter = null;
    }

    return CloudReviewResult(positionFen: startFen, moves: reviewMoves);
  }

  /// 获取着法质量标记
  String _getQualityMark(int diff) {
    if (diff >= -5) return '';
    if (diff >= -30) return '★';
    if (diff >= -70) return '✓';
    if (diff >= -100) return '✗';
    return '✗✗';
  }
}

/// List 扩展：firstOrNull
extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    for (final element in this) {
      return element;
    }
    return null;
  }
}
