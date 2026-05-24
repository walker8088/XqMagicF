import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:magicf/viewmodels/game_viewmodel.dart';
import 'package:magicf/services/engine_review.dart';

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
              if (vm.engineReviewResult != null) _buildResult(context, vm),
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

  Widget _buildResult(BuildContext context, GameViewModel vm) {
    final result = vm.engineReviewResult!;
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
                return _EngineMoveTile(move: move, vm: vm);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(EngineReviewResult result) {
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

class _EngineMoveTile extends StatelessWidget {
  final EngineReviewMove move;
  final GameViewModel vm;

  const _EngineMoveTile({required this.move, required this.vm});

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
                  Text(
                    '${move.moveNumber}.',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    move.moveChinese,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const Spacer(),
                  _qualityBadge(move.qualityMark),
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
              // 引擎分析详情
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 24),
                child: Row(
                  children: [
                    Text(
                      'D:${move.depth}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (move.bestMoveICCS != null)
                      Text(
                        '推荐: ${move.bestMoveICCS}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    if (move.bestScore != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '${move.bestScore}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // PV 预览
              if (move.pv.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 1, left: 24),
                  child: Text(
                    'PV: ${move.pv.take(3).join(" ")}',
                    style: const TextStyle(
                      color: Colors.white24,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
      case '○':
        color = Colors.orange;
      case '✗':
        color = Colors.deepOrange;
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
    final moves = vm.movesFromRoot;
    if (move.moveNumber <= moves.length) {
      vm.goToStart();
      for (int i = 0; i < move.moveNumber - 1; i++) {
        if (vm.canGoForward) vm.goForward();
      }
    }
  }
}
