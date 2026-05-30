import 'package:flutter/material.dart';
import 'package:xqmagic/models/chess_piece.dart';
import 'package:xqmagic/services/cloud_db.dart';
import 'package:xqmagic/services/uci_engine.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/coord.dart';
import 'package:xqmagic/utils/move_notation.dart';
import 'package:xqmagic/utils/pv_chinese_converter.dart';

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
    this.moveColor = PieceColor.red,
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

  /// 引擎分析时的走子方，用于 PV 线路中文转换
  final PieceColor moveColor;

  /// Factory constructor to create from EngineInfo
  factory EnginePVLine.fromEngineInfo(EngineInfo info) {
    final convertedScore = info.adjustedScore;
    return EnginePVLine(
      depth: info.depth,
      score: convertedScore,
      mateIn: info.isMate ? convertedScore : null,
      pv: info.pv,
      nodes: info.nodes,
      nps: info.nps,
      time: info.timeMs,
      moveColor: info.moveColor,
    );
  }

  /// Get the first move (best move in this line) in ICCS format
  String get bestMove => pv.isNotEmpty ? pv.first : '';
}

/// 实时引擎分析面板：监听引擎分析数据并显示实时 PV 线路
///
/// 这是 `AnalysisPanel` 的状态化包装器，接收明确的分析数据 props
/// 而非直接依赖 GameViewModel，实现 widget 与 ViewModel 的解耦
class LiveAnalysisPanel extends StatefulWidget {
  const LiveAnalysisPanel({
    super.key,
    required this.engineInfos,
    required this.isEngineReady,
    required this.isAnalyzing,
    required this.isThinking,
    required this.bestMove,
    required this.board,
    required this.activeColor,
    this.onBestMoveTap,
  });

  /// 引擎 PV 线路列表
  final List<EngineInfo> engineInfos;

  /// 引擎是否已就绪
  final bool isEngineReady;

  /// UI 是否标记为正在分析
  final bool isAnalyzing;

  /// 引擎是否正在思考
  final bool isThinking;

  /// 当前最佳着法 (ICCS)
  final String? bestMove;

  /// 当前棋盘棋子映射
  final Map<Coord, ChessPiece> board;

  /// 当前走子方
  final PieceColor activeColor;

  /// 点击最佳着法时的回调
  final void Function(String iccs)? onBestMoveTap;

  @override
  State<LiveAnalysisPanel> createState() => _LiveAnalysisPanelState();
}

class _LiveAnalysisPanelState extends State<LiveAnalysisPanel> {
  @override
  Widget build(BuildContext context) {
    final infos = widget.engineInfos;

    // Convert EngineInfo list to EnginePVLine list, sorted by multipv
    final pvLines =
        infos.map((info) => EnginePVLine.fromEngineInfo(info)).toList()
          ..sort((a, b) {
            final idxA = infos.indexWhere((i) => i.bestMoveICCS == a.bestMove);
            final idxB = infos.indexWhere((i) => i.bestMoveICCS == b.bestMove);
            return idxA.compareTo(idxB);
          });

    return AnalysisPanel(
      engineInfo: widget.isEngineReady
          ? EngineInfo(depth: 0, score: 0, isMate: false, pv: [])
          : null,
      board: widget.board,
      activeColor: widget.activeColor,
      bestMove: widget.bestMove,
      isAnalyzing: widget.isAnalyzing || widget.isThinking,
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
    this.board,
    this.activeColor,
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

  /// Board state for converting ICCS to Chinese notation
  final Map<Coord, ChessPiece>? board;

  /// Active color for Chinese notation conversion
  final PieceColor? activeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (bestMove != null) _buildBestMove(context),
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
      ),
    );
  }

  Widget _buildBestMove(BuildContext context) {
    final pvLine = pvLines.isNotEmpty ? pvLines.first : null;
    // 优先使用引擎分析时的 moveColor；pvLines 为空时 fallback 到 activeColor
    final bestColor = pvLine != null
        ? pvLine.moveColor
        : activeColor ?? PieceColor.red;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Text(
            '最佳: ',
            style: TextStyle(fontSize: 12, color: Colors.white54),
          ),
          if (bestMove != null)
            InkWell(
              onTap: onBestMoveTap != null
                  ? () => onBestMoveTap!(bestMove!)
                  : null,
              child: Text(
                _formatMoveDisplay(bestMove!, bestColor),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          const Spacer(),
          if (pvLine != null)
            ScoreDisplay(
              score: pvLine.score,
              mateIn: pvLine.mateIn,
              small: true,
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
          // 使用引擎分析时的 moveColor，确保 PV 颜色正确
          final pvActiveColor = line.moveColor;
          final displayMoves = board != null
              ? PVChineseConverter.formatPVWithChinese(
                  board!,
                  pvActiveColor,
                  line.pv,
                )
              : line.pv.map((m) => MoveNotation.formatICCS(m)).toList();
          return _buildPVLineRow(index, line, displayMoves);
        }),
      ],
    );
  }

  Widget _buildPVLineRow(
    int index,
    EnginePVLine line,
    List<String> chineseMoves,
  ) {
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
            // PV 线路（完整中文记谱）
            Expanded(
              child: Text(
                chineseMoves.isNotEmpty ? chineseMoves.join(' ') : '--',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: index == 0 ? FontWeight.bold : FontWeight.normal,
                  color: index == 0 ? Colors.white : Colors.white70,
                ),
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
        CloudMoveList(moves: cloudResult!.moves, onMoveTap: onBestMoveTap),
      ],
    );
  }

  /// 统一格式化单步着法显示：中文记谱(ICCS)
  String _formatMoveDisplay(String iccs, PieceColor color) {
    if (board == null) return MoveNotation.formatICCS(iccs);
    return MoveNotation.formatMoveDisplay(board!, color, iccs);
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
    this.pieces,
    this.activeColor,
    required this.moves,
    this.maxMoves = 10,
    this.onMoveTap,
  });

  /// 当前棋盘棋子映射（用于生成中文记谱）
  final Map<Coord, ChessPiece>? pieces;

  /// 当前走子方
  final PieceColor? activeColor;

  /// List of cloud moves
  final List<CloudMoveInfo> moves;

  /// Maximum number of moves to display
  final int maxMoves;

  /// Callback when a move is tapped (ICCS format)
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
    // 将 ICCS 转为中文记谱
    final chineseNotation = _iccsToChinese(move.iccs);

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
            // 序号
            SizedBox(
              width: 20,
              child: Text(
                '${moves.indexOf(move) + 1}.',
                style: TextStyle(
                  fontSize: 11,
                  color: isBest ? Colors.amber : Colors.white38,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            const SizedBox(width: 6),
            // 中文着法
            Expanded(
              child: Text(
                chineseNotation,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isBest ? FontWeight.bold : FontWeight.normal,
                  color: isBest ? Colors.white : Colors.white70,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 分数
            _buildScoreDisplay(move.score),
          ],
        ),
      ),
    );
  }

  /// 将 ICCS 转为显示格式
  String _iccsToChinese(String iccs) {
    if (pieces == null || activeColor == null) return iccs;
    return MoveNotation.formatMoveDisplay(pieces!, activeColor!, iccs);
  }

  Widget _buildScoreDisplay(int score) {
    final text = score >= 0 ? '+$score' : '$score';
    Color color;
    if (score > 0) {
      color = const Color(0xFF00CC44);
    } else if (score < 0) {
      color = const Color(0xFFFF4444);
    } else {
      color = Colors.white70;
    }
    return Text(
      text,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
    );
  }
}
