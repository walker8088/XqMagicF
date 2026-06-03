import 'package:xqmagic/models/board.dart';
import 'package:xqmagic/models/chess_piece.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/coord.dart';
import 'package:xqmagic/utils/fen.dart';

/// 棋盘编辑控制器：管理棋盘编辑模式的状态与操作
///
/// 职责：
/// - 维护编辑状态（选中棋子类型/颜色、放置/删除模式、走子方）
/// - 在调用方传入的 [Board] 上执行放置/删除/清空/初始化操作
///
/// **不持有 [Board] 引用**——`GameController.reset()` 会重建 `GameEngine`
/// 并切换 board 实例，因此每次操作都接收 [Board] 参数以始终操作当前
/// 棋盘。否则一旦 reset/edit 顺序错乱，会写到已被丢弃的旧棋盘上。
class BoardEditController {
  BoardEditController();

  // ──────────── 状态 ────────────

  PieceType _pieceType = PieceType.pawn;
  PieceColor _pieceColor = PieceColor.red;
  PieceColor _sideToMove = PieceColor.red;
  bool _placing = true;

  PieceType get pieceType => _pieceType;
  PieceColor get pieceColor => _pieceColor;
  PieceColor get sideToMove => _sideToMove;
  bool get placing => _placing;

  // ──────────── 状态设置 ────────────

  void setPieceType(PieceType type) => _pieceType = type;
  void setPieceColor(PieceColor color) => _pieceColor = color;
  void setSideToMove(PieceColor color) => _sideToMove = color;
  void setPlacing(bool placing) => _placing = placing;

  // ──────────── 棋盘操作 ────────────

  /// 在 [board] 的 [pos] 放置或删除棋子（根据当前 [placing] 模式）
  void tap(Board board, Coord pos) {
    if (!board.isValidPosition(pos)) return;

    if (_placing) {
      board.putPiece(
        ChessPiece(type: _pieceType, color: _pieceColor, coord: pos),
      );
    } else {
      board.removePiece(pos);
    }
  }

  /// 清空 [board]
  void clearBoard(Board board) {
    board.clear();
  }

  /// 初始化 [board] 为标准开局并重置走子方为红方
  void initStandard(Board board) {
    board.initialize();
    _sideToMove = PieceColor.red;
  }

  /// 从 [board] 当前状态生成完整 FEN（含走子方）
  String toFen(Board board) => FenParser.generate(board, _sideToMove);

  // ──────────── 重置 ────────────

  /// 重置所有编辑状态到默认值（不影响棋盘内容）
  void reset() {
    _pieceType = PieceType.pawn;
    _pieceColor = PieceColor.red;
    _sideToMove = PieceColor.red;
    _placing = true;
  }
}
