import 'package:flutter/material.dart';
import 'package:xqmagic/models/move.dart';
import 'package:xqmagic/utils/constants.dart';

/// 着法列表面板：显示走子历史、分数、注解
class MoveHistoryPanel extends StatefulWidget {
  const MoveHistoryPanel({
    super.key,
    required this.moves,
    required this.currentIndex,
    required this.onTapMove,
    this.notations = const [],
    this.evaluations = const {},
    this.annotations = const {},
  });

  final List<MoveRecord> moves;
  final int currentIndex;
  final void Function(int) onTapMove;
  final List<String> notations; // 中文记法列表
  final Map<int, int> evaluations; // 索引 -> 引擎分数
  final Map<int, String> annotations; // 索引 -> 注解

  @override
  State<MoveHistoryPanel> createState() => _MoveHistoryPanelState();
}

class _MoveHistoryPanelState extends State<MoveHistoryPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant MoveHistoryPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当有新着法或当前索引变化时，自动滚动到最新位置
    if (widget.moves.length != oldWidget.moves.length ||
        widget.currentIndex != oldWidget.currentIndex) {
      _scrollToCurrentIndex();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentIndex() {
    if (widget.moves.isEmpty || _scrollController.hasClients == false) return;

    final moveRow = widget.currentIndex ~/ 2;
    final totalRows = (widget.moves.length / 2).ceil();

    if (moveRow >= 0 && moveRow < totalRows) {
      final position = (moveRow * 40.0).clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      );
      _scrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        border: Border(left: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(child: _buildMoveList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: const [
          Icon(Icons.format_list_numbered, size: 18, color: Colors.white70),
          SizedBox(width: 8),
          Text(
            '着法列表',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoveList() {
    if (widget.moves.isEmpty) {
      return const Center(
        child: Text('暂无着法', style: TextStyle(color: Colors.white38)),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: (widget.moves.length / 2).ceil(),
      itemBuilder: (context, index) {
        final moveNumber = index + 1;
        final whiteIndex = index * 2;
        final blackIndex = index * 2 + 1;

        return _buildMoveRow(
          moveNumber,
          whiteIndex < widget.moves.length ? widget.moves[whiteIndex] : null,
          blackIndex < widget.moves.length ? widget.moves[blackIndex] : null,
          whiteIndex,
          blackIndex,
        );
      },
    );
  }

  Widget _buildMoveRow(
    int number,
    MoveRecord? whiteMove,
    MoveRecord? blackMove,
    int whiteIdx,
    int blackIdx,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            '$number.',
            style: const TextStyle(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: whiteMove != null
              ? _buildMoveButton(
                  whiteMove,
                  whiteIdx,
                  widget.notations.isNotEmpty && whiteIdx < widget.notations.length
                      ? widget.notations[whiteIdx]
                      : null,
                )
              : const SizedBox.shrink(),
        ),
        Expanded(
          child: blackMove != null
              ? _buildMoveButton(
                  blackMove,
                  blackIdx,
                  widget.notations.isNotEmpty && blackIdx < widget.notations.length
                      ? widget.notations[blackIdx]
                      : null,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildMoveButton(MoveRecord move, int index, String? notation) {
    final isActive = index == widget.currentIndex;
    final evalScore = widget.evaluations[index];
    final annotation = widget.annotations[index];

    final moveText = notation ?? '--';

    return InkWell(
      onTap: () => widget.onTapMove(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.2) : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 质量标记
            if (annotation != null && annotation.isNotEmpty)
              Text(
                annotation,
                style: TextStyle(
                  color: _getAnnotationColor(annotation),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            // 着法文本
            Flexible(
              child: Text(
                moveText,
                style: TextStyle(
                  color: move.color == PieceColor.red
                      ? const Color(0xFFCC4444)
                      : Colors.white70,
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 引擎分数
            if (evalScore != null)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  _formatScore(evalScore),
                  style: TextStyle(
                    color: evalScore > 0
                        ? const Color(0xFF44CC44)
                        : const Color(0xFFCC4444),
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatScore(int score) {
    if (score > 0) return '+${(score / 100).toStringAsFixed(2)}';
    return '-${((-score) / 100).toStringAsFixed(2)}';
  }

  Color? _getAnnotationColor(String mark) {
    switch (mark) {
      case '★':
        return Colors.green;
      case '✓':
        return Colors.blue;
      case '✗':
      case '✗✗':
        return Colors.red;
      default:
        return null;
    }
  }
}
