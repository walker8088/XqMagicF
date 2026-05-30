import 'package:xqmagic/models/game_tree.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/move_notation.dart';

/// 着法质量评估器
///
/// 比较实际着法与引擎推荐，根据评分变化判断着法质量。
/// 从 GameViewModel 中提取，职责单一，便于测试。
class MoveQualityAssessor {
  MoveQualityAssessor._();

  /// 评估着法质量：比较实际着法与引擎推荐
  ///
  /// [node] 当前走子后的节点（必须有 move 和 parent）
  /// 要求 node.evaluation 和 node.engineBestMove 已被设置
  static void assess(GameTreeNode node) {
    final move = node.move;
    if (move == null) return;

    final bestICCS = node.engineBestMove ?? '';
    if (bestICCS.isEmpty) return;

    final moveICCS = MoveNotation.toICCS(move);

    // 引擎评分变化：比较走子前后的评分
    final scoreAfter = node.evaluation;
    if (scoreAfter == null) return;

    // 获取走子前的评分（父节点的评分）
    final scoreBefore = node.parent?.evaluation;

    // 计算评分变化
    // 正数变化 = 红方更好，负数变化 = 黑方更好
    // 走子的颜色决定方向
    int scoreDiff;
    if (scoreBefore != null) {
      scoreDiff = scoreAfter - scoreBefore;
      // 黑方走子时，评分变化取反（黑方让红方分减少 = 黑方好）
      if (move.color == PieceColor.black) {
        scoreDiff = -scoreDiff;
      }
    } else {
      scoreDiff = 0;
    }

    // 如果与引擎推荐一致 → 好棋
    if (bestICCS == moveICCS) {
      node.moveAnnotation = '★';
      return;
    }

    // 根据评分变化判断着法质量
    if (scoreDiff < -300) {
      node.moveAnnotation = '✗✗';
    } else if (scoreDiff < -150) {
      node.moveAnnotation = '✗';
    } else if (scoreDiff < -50) {
      node.moveAnnotation = '?';
    } else if (scoreDiff > 100) {
      node.moveAnnotation = '!';
    } else {
      node.moveAnnotation = '✓';
    }
  }
}
