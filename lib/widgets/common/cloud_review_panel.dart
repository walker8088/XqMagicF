import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:magicf/viewmodels/game_viewmodel.dart';
import 'package:magicf/services/cloud_review.dart';

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
              if (vm.cloudReviewResult != null) _buildResult(context, vm),
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

  Widget _buildResult(BuildContext context, GameViewModel vm) {
    final result = vm.cloudReviewResult!;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummary(result),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: result.moves.length,
              itemBuilder: (context, index) {
                final move = result.moves[index];
                return _MoveReviewTile(move: move, vm: vm);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(CloudReviewResult result) {
    final accuracy = result.totalMoves > 0
        ? (result.accuracyMoves / result.totalMoves * 100).toStringAsFixed(1)
        : '0.0';
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          _summaryItem('${result.totalMoves}', '总着法', Colors.white70),
          const SizedBox(width: 12),
          _summaryItem(accuracy, '准确率', Colors.green),
          const SizedBox(width: 12),
          _summaryItem(
            '${result.badMoves}',
            '劣着',
            result.badMoves > 0 ? Colors.red : Colors.white38,
          ),
          const SizedBox(width: 12),
          _summaryItem(
            result.averageDiff.toStringAsFixed(0),
            '平均偏离',
            result.averageDiff < -50 ? Colors.orange : Colors.white70,
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 10),
        ),
      ],
    );
  }
}

class _MoveReviewTile extends StatelessWidget {
  final CloudReviewMove move;
  final GameViewModel vm;

  const _MoveReviewTile({required this.move, required this.vm});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _jumpToMove(context),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // 着法序号
                  Text(
                    '${move.moveNumber}.',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 6),
                  // 实际走法
                  Text(
                    move.moveChinese,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const Spacer(),
                  // 质量标记
                  if (move.qualityMark.isNotEmpty)
                    _qualityBadge(move.qualityMark),
                  // 分数差
                  Text(
                    move.diff >= 0 ? '+${move.diff}' : '${move.diff}',
                    style: TextStyle(
                      color: _diffColor(move.diff),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              // 最佳着法提示（如果有偏离）
              if (move.diff < -30 && move.bestMoveICCS != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 24),
                  child: Text(
                    '推荐: ${move.bestMoveICCS}  (评分: ${move.bestScore ?? "?"})',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _qualityBadge(String mark) {
    Color color;
    switch (mark) {
      case '★':
        color = Colors.green;
      case '✓':
        color = Colors.blue;
      case '✗':
        color = Colors.orange;
      case '✗✗':
        color = Colors.red;
      default:
        color = Colors.grey;
    }
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        mark,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _diffColor(int diff) {
    if (diff >= -5) return Colors.green;
    if (diff >= -30) return Colors.lightGreen;
    if (diff >= -70) return Colors.orange;
    if (diff >= -100) return Colors.deepOrange;
    return Colors.red;
  }

  void _jumpToMove(BuildContext context) {
    // Navigate to this move in the game tree
    final moves = vm.movesFromRoot;
    if (move.moveNumber <= moves.length) {
      // Go to start, then go forward to the target move
      vm.goToStart();
      for (int i = 0; i < move.moveNumber - 1; i++) {
        if (vm.canGoForward) vm.goForward();
      }
    }
  }
}
