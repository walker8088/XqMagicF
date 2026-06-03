import 'package:flutter/material.dart';
import 'package:xqmagic/models/move.dart';
import 'package:xqmagic/services/engine.dart';
import 'package:xqmagic/utils/constants.dart';

/// 着法列表面板：显示走子历史、分数、注解
class MoveHistoryPanel extends StatefulWidget {
  const MoveHistoryPanel({
    super.key,
    required this.moves,
    required this.currentIndex,
    required this.onTapMove,
    required this.onTapRoot,
    this.notations = const [],
    this.evaluations = const {},
    this.annotations = const {},
  });

  final List<MoveRecord> moves;
  final int currentIndex; // -1 = root, 0+ = move index
  final void Function(int) onTapMove;
  final VoidCallback onTapRoot;
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
    if (_scrollController.hasClients == false) return;

    // Row 0 = root, Row 1+ = moves (one move per row)
    final int row;
    if (widget.currentIndex < 0) {
      row = 0; // root
    } else {
      row = widget.currentIndex + 1;
    }
    final totalRows = 1 + widget.moves.length;

    if (row >= 0 && row < totalRows) {
      final position = (row * 36.0).clamp(
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
        color: Colors.black.withValues(alpha: 0.2),
        border: Border(
          left: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
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
      return ListView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [_buildRootRow()],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: 1 + widget.moves.length, // +1 for root, one row per move
      itemBuilder: (context, index) {
        if (index == 0) {
          return _buildRootRow();
        }

        final moveIndex = index - 1; // skip root
        final moveNumber = (moveIndex ~/ 2) + 1;
        final isRedMove = moveIndex % 2 == 0;

        return _buildMoveRow(
          isRedMove ? '$moveNumber.' : '',
          widget.moves[moveIndex],
          moveIndex,
        );
      },
    );
  }

  Widget _buildMoveRow(String numberLabel, MoveRecord move, int moveIndex) {
    return Row(
      children: [
        SizedBox(
          width: 32,
          child: Text(
            numberLabel,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _buildMoveButton(
            move,
            moveIndex,
            widget.notations.isNotEmpty && moveIndex < widget.notations.length
                ? widget.notations[moveIndex]
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildRootRow() {
    final isRootSelected = widget.currentIndex < 0;

    return InkWell(
      onTap: widget.onTapRoot,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isRootSelected ? Colors.white.withValues(alpha: 0.2) : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            const SizedBox(width: 32),
            const SizedBox(width: 4),
            Text(
              ' === ',
              style: TextStyle(
                color: const Color(0xFFCC4444),
                fontSize: 13,
                fontWeight: isRootSelected
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
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
          color: isActive ? Colors.white.withValues(alpha: 0.2) : null,
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
    final mateDistance = EngineInfo.mateDistanceFrom(score);
    if (mateDistance != null) return '杀$mateDistance';
    if (score > 0) return '+$score';
    return '$score';
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
