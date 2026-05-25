import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xqmagic/services/engine_review.dart';
import 'package:xqmagic/viewmodels/game_viewmodel.dart';
import 'review_shared.dart';

/// 引擎复盘面板：对当前棋谱进行引擎逐着分析评估
class EngineReviewPanel extends StatelessWidget {
  const EngineReviewPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameViewModel>(
      builder: (context, vm, _) {
        return Container(
          decoration: const BoxDecoration(color: Color(0xFF2E1A0E)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, vm),
              const Divider(color: Color(0xFFF5DEB3), height: 1),
              if (vm.engineReviewProgress != null) _buildProgress(vm),
              if (vm.engineReviewResult != null)
                _buildResult(context, vm.engineReviewResult!, vm),
              if (vm.engineReviewResult == null &&
                  vm.engineReviewProgress == null)
                _buildEmpty(context, vm),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, GameViewModel vm) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          const Icon(Icons.smart_toy, color: Color(0xFFF5DEB3), size: 18),
          const SizedBox(width: 6),
          const Text(
            '引擎复盘',
            style: TextStyle(
              color: Color(0xFFF5DEB3),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (vm.engineReviewProgress != null)
            TextButton.icon(
              onPressed: vm.cancelEngineReview,
              icon: const Icon(Icons.cancel, size: 14),
              label: const Text('取消', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          if (vm.engineReviewProgress == null)
            TextButton.icon(
              onPressed: vm.movesFromRoot.isNotEmpty && vm.engineManager.isReady
                  ? vm.startEngineReview
                  : null,
              icon: const Icon(Icons.play_arrow, size: 14),
              label: const Text('开始复盘', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFF5DEB3),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          if (vm.engineReviewResult != null)
            TextButton.icon(
              onPressed: vm.clearEngineReview,
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('清除', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white54,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgress(GameViewModel vm) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: vm.engineReviewProgress,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4FC3F7)),
          ),
          const SizedBox(height: 4),
          Text(
            '引擎分析中... ${(vm.engineReviewProgress! * 100).toInt()}%',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, GameViewModel vm) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.smart_toy, size: 40, color: Colors.white24),
            const SizedBox(height: 8),
            const Text(
              '加载引擎后点击"开始复盘"\n引擎将逐着深度分析',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (!vm.engineManager.isReady)
              Text(
                vm.engineManager.hasError
                    ? '引擎错误: ${vm.engineManager.error}'
                    : '引擎未加载，请先在设置中配置引擎',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 11),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(
    BuildContext context,
    EngineReviewResult result,
    GameViewModel vm,
  ) {
    final depthSetting = vm.engineManager.depth;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReviewSummary(
            totalMoves: result.totalMoves,
            accuracyMoves: result.accuracyMoves,
            badMoves: result.badMoves,
            averageDiff: result.averageDiff,
          ),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: result.moves.length,
              itemBuilder: (context, index) {
                final move = result.moves[index];
                return _buildMoveTile(move, vm, depthSetting);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoveTile(EngineReviewMove move, GameViewModel vm, int depth) {
    // 构建最佳着法提示
    String? bestMoveHint;
    if (move.bestMoveICCS != null) {
      bestMoveHint = '推荐: ${move.bestMoveICCS}';
      if (move.bestScore != null) {
        bestMoveHint += '  (${move.bestScore})';
      }
    }

    // 引擎特有的额外信息
    final extraInfo = <Widget>[
      Text(
        'D:${move.depth}',
        style: const TextStyle(color: Colors.white38, fontSize: 10),
      ),
    ];
    if (move.pv.isNotEmpty) {
      extraInfo.add(
        Text(
          ' PV: ${move.pv.take(3).join(" ")}',
          style: const TextStyle(
            color: Colors.white24,
            fontSize: 10,
            fontFamily: 'monospace',
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    return ReviewMoveTile(
      moveNumber: move.moveNumber,
      moveChinese: move.moveChinese,
      diff: move.diff,
      qualityMark: move.qualityMark,
      bestMoveHint: bestMoveHint,
      extraInfo:
          extraInfo.isNotEmpty
              ? Row(children: extraInfo)
              : null,
      onTap: () => _jumpToMove(move.moveNumber, vm),
    );
  }

  void _jumpToMove(int moveNumber, GameViewModel vm) {
    final moves = vm.movesFromRoot;
    if (moveNumber <= moves.length) {
      vm.goToStart();
      for (int i = 0; i < moveNumber - 1; i++) {
        if (vm.canGoForward) vm.goForward();
      }
    }
  }
}
