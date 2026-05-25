import 'package:flutter/material.dart';

// ============================================================
// 复盘面板共享组件（引擎复盘 + 云库复盘 共用）
// ============================================================

/// 质量标记徽章（★ ✓ ✗ ✗✗）
Widget buildQualityBadge(String mark) {
  if (mark.isEmpty) return const SizedBox.shrink();

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

/// 分数差对应的颜色
Color diffColor(int diff) {
  if (diff >= -5) return Colors.green;
  if (diff >= -30) return Colors.lightGreen;
  if (diff >= -70) return Colors.orange;
  if (diff >= -100) return Colors.deepOrange;
  return Colors.red;
}

/// 复盘统计摘要组件
class ReviewSummary extends StatelessWidget {
  const ReviewSummary({
    super.key,
    required this.totalMoves,
    required this.accuracyMoves,
    required this.badMoves,
    required this.averageDiff,
  });

  final int totalMoves;
  final int accuracyMoves;
  final int badMoves;
  final double averageDiff;

  @override
  Widget build(BuildContext context) {
    final accuracy =
        totalMoves > 0
            ? (accuracyMoves / totalMoves * 100).toStringAsFixed(1)
            : '0.0';

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          _summaryItem('$totalMoves', '总着法', Colors.white70),
          const SizedBox(width: 12),
          _summaryItem(accuracy, '准确率', Colors.green),
          const SizedBox(width: 12),
          _summaryItem(
            '$badMoves',
            '劣着',
            badMoves > 0 ? Colors.red : Colors.white38,
          ),
          const SizedBox(width: 12),
          _summaryItem(
            averageDiff.toStringAsFixed(0),
            '平均偏离',
            averageDiff < -50 ? Colors.orange : Colors.white70,
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

/// 复带着法列表项 - 通用版本
/// [extraInfo] 可用于显示引擎特有的深度/PV 等信息
class ReviewMoveTile extends StatelessWidget {
  const ReviewMoveTile({
    super.key,
    required this.moveNumber,
    required this.moveChinese,
    required this.diff,
    required this.qualityMark,
    this.bestMoveHint,
    this.extraInfo,
    this.onTap,
  });

  final int moveNumber;
  final String moveChinese;
  final int diff;
  final String qualityMark;
  final String? bestMoveHint;
  final Widget? extraInfo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '$moveNumber.',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    moveChinese,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  const Spacer(),
                  buildQualityBadge(qualityMark),
                  Text(
                    diff >= 0 ? '+$diff' : '$diff',
                    style: TextStyle(
                      color: diffColor(diff),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              if (bestMoveHint != null && bestMoveHint!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2, left: 24),
                  child: Text(
                    bestMoveHint!,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              if (extraInfo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 1, left: 24),
                  child: extraInfo,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
