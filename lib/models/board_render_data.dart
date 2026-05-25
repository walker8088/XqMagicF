import 'package:xqmagic/models/chess_piece.dart';
import 'package:xqmagic/models/move.dart';
import 'package:xqmagic/utils/coord.dart';

/// 棋盘渲染数据：纯数据类，用于 ChessBoardPainter 渲染
/// 包含所有绘图所需的状态，不依赖 ViewModel
class BoardRenderData {
  const BoardRenderData({
    required this.pieces,
    this.selectedPosition,
    this.possibleMoves = const [],
    this.lastMove,
    this.inCheckPosition,
  });

  /// 所有棋子的列表
  final List<ChessPiece> pieces;

  /// 当前选中位置
  final Coord? selectedPosition;

  /// 可行走位置列表
  final List<Coord> possibleMoves;

  /// 上一步走法
  final MoveRecord? lastMove;

  /// 被将军的位置
  final Coord? inCheckPosition;

  /// 位置是否被选中
  bool isPositionSelected(Coord pos) => selectedPosition == pos;

  /// 位置是否可行走
  bool isPossibleMove(Coord pos) => possibleMoves.contains(pos);
}
