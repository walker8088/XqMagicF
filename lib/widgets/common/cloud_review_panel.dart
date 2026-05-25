import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xqmagic/services/cloud_review.dart';
import 'package:xqmagic/viewmodels/game_viewmodel.dart';
import 'review_shared.dart';

/// 云库复盘面板：对当前棋谱进行云库逐着评估
class CloudReviewPanel extends StatelessWidget {
  const CloudReviewPanel({super.key});

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
              if (vm.cloudReviewProgress != null) _buildProgress(vm),
              if (vm.cloudReviewResult != null)
                _buildResult(context, vm.cloudReviewResult!, vm),
              if (vm.cloudReviewResult == null &&
                  vm.cloudReviewProgress == null)
                _buildEmpty(context),
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
          const Icon(Icons.cloud, color: Color(0xFFF5DEB3), size: 18),
          const SizedBox(width: 6),
          const Text(
            '云库复盘',
            style: TextStyle(
              color: Color(0xFFF5DEB3),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          if (vm.cloudReviewProgress != null)
            TextButton.icon(
              onPressed: vm.cancelCloudReview,
              icon: const Icon(Icons.cancel, size: 14),
              label: const Text('取消', style: TextStyle(fontSize: 11)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          if (vm.cloudReviewProgress == null)
            TextButton.icon(
              onPressed: vm.movesFromRoot.isNotEmpty
                  ? vm.startCloudReview
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
          if (vm.cloudReviewResult != null)
            TextButton.icon(
              onPressed: vm.clearCloudReview,
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
            value: vm.cloudReviewProgress,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF5DEB3)),
          ),
          const SizedBox(height: 4),
          Text(
            '正在复盘... ${(vm.cloudReviewProgress! * 100).toInt()}%',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return const Expanded(
      child: Center(
        child: Text(
          '打开棋谱后点击"开始复盘"\n云库将逐着评估走法质量',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildResult(
    BuildContext context,
    CloudReviewResult result,
    GameViewModel vm,
  ) {
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
                return _buildMoveTile(move, vm);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoveTile(CloudReviewMove move, GameViewModel vm) {
    // 仅偏离较大时显示推荐着法
    String? bestMoveHint;
    if (move.diff < -30 && move.bestMoveICCS != null) {
      bestMoveHint = '推荐: ${move.bestMoveICCS}  (评分: ${move.bestScore ?? "?"})';
    }

    return ReviewMoveTile(
      moveNumber: move.moveNumber,
      moveChinese: move.moveChinese,
      diff: move.diff,
      qualityMark: move.qualityMark,
      bestMoveHint: bestMoveHint,
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
