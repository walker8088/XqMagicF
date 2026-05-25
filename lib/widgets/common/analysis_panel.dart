import 'package:flutter/material.dart';
import 'package:xqmagic/services/cloud_db.dart';
import 'package:xqmagic/services/uci_engine.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/viewmodels/game_viewmodel.dart';

/// Represents a single principal variation line from engine analysis.
class EnginePVLine {
  EnginePVLine({
    required this.depth,
    required this.score,
    this.mateIn,
    required this.pv,
    required this.nodes,
    required this.nps,
    required this.time,
  });

  /// Search depth
  final int depth;

  /// Evaluation in centipawns (positive = red advantage)
  final int score;

  /// Mate-in-N, null if not a mate situation
  final int? mateIn;

  /// Principal variation moves in ICCS format
  final List<String> pv;

  /// Nodes searched
  final int nodes;

  /// Nodes per second
  final int nps;

  /// Time spent in milliseconds
  final int time;

  /// Factory constructor to create from EngineInfo
  factory EnginePVLine.fromEngineInfo(EngineInfo info) {
    return EnginePVLine(
      depth: info.depth,
      score: info.score,
      mateIn: info.isMate ? info.score : null,
      pv: info.pv,
      nodes: info.nodes,
      nps: info.nps,
      time: info.timeMs,
    );
  }

  /// Get the first move (best move in this line) in ICCS format
  String get bestMove => pv.isNotEmpty ? pv.first : '';
}

/// 实时引擎分析面板：自动监听 GameViewModel 并显示实时 PV 线路
///
/// 这是 `AnalysisPanel` 的状态化包装器，监听引擎分析更新
/// 并将 `EngineInfo` 自动转换为 `EnginePVLine` 格式
class LiveAnalysisPanel extends StatefulWidget {
  const LiveAnalysisPanel({
    super.key,
    required this.viewModel,
    this.cloudResult,
    this.onBestMoveTap,
  });

  final GameViewModel viewModel;
  final CloudQueryResult? cloudResult;
  final void Function(String iccs)? onBestMoveTap;

  @override
  State<LiveAnalysisPanel> createState() => _LiveAnalysisPanelState();
}

class _LiveAnalysisPanelState extends State<LiveAnalysisPanel> {
  late final VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _listener = _onViewModelChanged;
    widget.viewModel.addListener(_listener);
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_listener);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant LiveAnalysisPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      oldWidget.viewModel.removeListener(_listener);
      widget.viewModel.addListener(_listener);
    }
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final infos = vm.engineInfos;

    // Convert EngineInfo list to EnginePVLine list, sorted by multipv
    final pvLines = infos
        .map((info) => EnginePVLine.fromEngineInfo(info))
        .toList()
      ..sort((a, b) {
        final idxA = infos.indexWhere((i) => i.bestMoveICCS == a.bestMove);
        final idxB = infos.indexWhere((i) => i.bestMoveICCS == b.bestMove);
        return idxA.compareTo(idxB);
      });

    return AnalysisPanel(
      engineInfo: vm.engineManager.isReady
          ? EngineInfo(
              depth: 0,
              score: 0,
              isMate: false,
              pv: [],
            )
          : null,
      cloudResult: widget.cloudResult,
      bestMove: vm.engineBestMove,
      isAnalyzing: vm.isAnalyzing || vm.engineManager.isThinking,
      pvLines: pvLines,
      onBestMoveTap: widget.onBestMoveTap,
    );
  }
}

/// Combined analysis panel showing engine analysis and cloud database results.
class AnalysisPanel extends StatelessWidget {
  const AnalysisPanel({
    super.key,
    this.engineInfo,
    this.cloudResult,
    this.bestMove,
    this.isAnalyzing = false,
    this.pvLines = const [],
    this.onBestMoveTap,
  });

  /// Engine info (name, author, etc.)
  final EngineInfo? engineInfo;

  /// Cloud database query result
  final CloudQueryResult? cloudResult;

  /// Best move in ICCS format
  final String? bestMove;

  /// Whether the engine is currently analyzing
  final bool isAnalyzing;

  /// Multiple PV lines for MultiPV analysis
  final List<EnginePVLine> pvLines;

  /// Callback when user taps a recommended move
  final void Function(String iccs)? onBestMoveTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 300),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context),
          const Divider(height: 16),
          if (isAnalyzing) _buildAnalyzingIndicator(context),
          if (bestMove != null && !isAnalyzing) _buildBestMove(context),
          if (pvLines.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildPVLines(context),
          ],
          if (cloudResult != null && cloudResult!.moves.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 20),
            _buildCloudSection(context),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          '引擎分析',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        if (engineInfo != null)
          Text(
            'D:${engineInfo!.depth}',
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
      ],
    );
  }

  Widget _buildAnalyzingIndicator(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '引擎分析中...',
            style: TextStyle(fontSize: 12, color: Colors.blue),
          ),
        ],
      ),
    );
  }

  Widget _buildBestMove(BuildContext context) {
    final pvLine = pvLines.isNotEmpty ? pvLines.first : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppConstants.redPieceColor.withOpacity(0.85),
            const Color(0xFFAA0000),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '最佳着法',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (pvLine != null)
                ScoreDisplay(
                  score: pvLine.score,
                  mateIn: pvLine.mateIn,
                  small: true,
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (bestMove != null)
            InkWell(
              onTap: onBestMoveTap != null
                  ? () => onBestMoveTap!(bestMove!)
                  : null,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  _formatMoveDisplay(bestMove!),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          if (pvLine != null && pvLine.pv.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '变化: ${_formatPVPreview(pvLine.pv)}',
                style: const TextStyle(fontSize: 10, color: Colors.white60),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPVLines(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '分析线路',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        ...pvLines.asMap().entries.map((entry) {
          final index = entry.key;
          final line = entry.value;
          return _buildPVLineRow(index, line);
        }),
      ],
    );
  }

  Widget _buildPVLineRow(int index, EnginePVLine line) {
    return InkWell(
      onTap: line.pv.isNotEmpty && onBestMoveTap != null
          ? () => onBestMoveTap!(line.pv.first)
          : null,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: index == 0
              ? Colors.white.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PV line number
            SizedBox(
              width: 18,
              child: Text(
                '${index + 1}.',
                style: TextStyle(
                  fontSize: 11,
                  color: index == 0 ? Colors.amber : Colors.white38,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 2),
            // Depth
            SizedBox(
              width: 28,
              child: Text(
                'D${line.depth}',
                style: const TextStyle(fontSize: 10, color: Colors.white54),
              ),
            ),
            const SizedBox(width: 4),
            // Score
            SizedBox(
              width: 72,
              child: ScoreDisplay(
                score: line.score,
                mateIn: line.mateIn,
                small: true,
              ),
            ),
            const SizedBox(width: 4),
            // First move
            Expanded(
              child: Text(
                line.pv.isNotEmpty ? _formatMoveDisplay(line.pv.first) : '--',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: index == 0 ? FontWeight.bold : FontWeight.normal,
                  color: index == 0 ? Colors.white : Colors.white70,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '云库着法',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (cloudResult!.isCache)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Text(
                  '缓存',
                  style: TextStyle(fontSize: 9, color: Colors.white70),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        CloudMoveList(
          moves: cloudResult!.moves,
          bestScore: cloudResult!.bestScore,
          onMoveTap: onBestMoveTap,
        ),
      ],
    );
  }

  String _formatMoveDisplay(String iccs) {
    if (iccs.length != 4) return iccs;
    // Format ICCS as "81-82" for better readability
    return '${iccs.substring(0, 2)}-${iccs.substring(2)}';
  }

  String _formatPVPreview(List<String> moves) {
    if (moves.length <= 1) return '';
    final preview = moves.sublist(1, moves.length.clamp(1, 6));
    return preview.map(_formatMoveDisplay).join(' ');
  }
}

/// Displays an evaluation score in human-readable format.
class ScoreDisplay extends StatelessWidget {
  const ScoreDisplay({
    super.key,
    required this.score,
    this.mateIn,
    this.small = false,
  });

  /// Score in centipawns (positive = red advantage)
  final int score;

  /// Mate-in-N, null if not a mate situation
  final int? mateIn;

  /// Use smaller text size
  final bool small;

  @override
  Widget build(BuildContext context) {
    final (text, color) = _formatScore();

    return Text(
      text,
      style: TextStyle(
        fontSize: small ? 12 : 16,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }

  (String, Color) _formatScore() {
    // Mate situation
    if (mateIn != null) {
      final mateText = '杀$mateIn';
      final color = score > 0
          ? const Color(0xFFFF4444) // Red side mating (red is favorable)
          : Colors.blue; // Black side mating
      return (mateText, color);
    }

    // Regular centipawn score
    final pawns = score / 100.0;
    final text = pawns >= 0
        ? '+${pawns.toStringAsFixed(2)}'
        : pawns.toStringAsFixed(2);

    // Color coding: green = good for red (positive), red = bad for red (negative)
    final color = _scoreToColor(pawns);
    return (text, color);
  }

  Color _scoreToColor(double pawns) {
    if (pawns >= 2.0) return const Color(0xFF00CC44); // Strong red advantage
    if (pawns >= 0.5) return Colors.green; // Moderate red advantage
    if (pawns >= -0.5) return Colors.white70; // Equal position
    if (pawns >= -2.0) return Colors.orange; // Moderate black advantage
    return const Color(0xFFFF4444); // Strong black advantage
  }
}

/// Displays cloud database moves in a scrollable list.
class CloudMoveList extends StatelessWidget {
  const CloudMoveList({
    super.key,
    required this.moves,
    this.bestScore = 0,
    this.maxMoves = 8,
    this.onMoveTap,
  });

  /// List of cloud moves
  final List<CloudMoveInfo> moves;

  /// Best score for calculating quality marks
  final int bestScore;

  /// Maximum number of moves to display
  final int maxMoves;

  /// Callback when a move is tapped
  final void Function(String iccs)? onMoveTap;

  @override
  Widget build(BuildContext context) {
    final displayMoves = moves.take(maxMoves).toList();

    if (displayMoves.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            '无云库数据',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 240),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: displayMoves.length,
        itemBuilder: (context, index) {
          final move = displayMoves[index];
          return _buildMoveRow(move, index == 0);
        },
      ),
    );
  }

  Widget _buildMoveRow(CloudMoveInfo move, bool isBest) {
    return InkWell(
      onTap: onMoveTap != null ? () => onMoveTap!(move.iccs) : null,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isBest ? Colors.white.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            // Quality mark
            SizedBox(width: 20, child: _buildQualityMark(move)),
            const SizedBox(width: 2),
            // Move notation
            SizedBox(
              width: 52,
              child: Text(
                '${move.iccs.substring(0, 2)}-${move.iccs.substring(2)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isBest ? FontWeight.bold : FontWeight.normal,
                  color: isBest ? Colors.white : Colors.white70,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Score
            SizedBox(
              width: 52,
              child: ScoreDisplay(score: move.score, small: true),
            ),
            const SizedBox(width: 6),
            // Win rate
            SizedBox(
              width: 36,
              child: Text(
                '${move.winRate}%',
                style: TextStyle(
                  fontSize: 10,
                  color: _winRateColor(move.winRate),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Frequency
            SizedBox(
              width: 32,
              child: Text(
                move.frequency.toString(),
                style: const TextStyle(fontSize: 10, color: Colors.white54),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityMark(CloudMoveInfo move) {
    final mark = move.qualityMark;
    Color? markColor;

    if (mark.contains('★')) {
      markColor = const Color(0xFF00CC44); // Good
    } else if (mark.contains('✓')) {
      markColor = Colors.blue; // OK
    } else if (mark.contains('✗')) {
      markColor = const Color(0xFFFF4444); // Bad
    }

    if (mark.isEmpty) {
      // Best move indicator
      return const Text(
        '★',
        style: TextStyle(fontSize: 11, color: Colors.amber),
      );
    }

    return Text(
      mark,
      style: TextStyle(fontSize: 11, color: markColor ?? Colors.white54),
    );
  }

  Color _winRateColor(int winRate) {
    if (winRate >= 60) return const Color(0xFF00CC44); // High win rate
    if (winRate >= 45) return Colors.orange; // Moderate
    return const Color(0xFFFF6666); // Low win rate
  }
}
