import 'package:flutter/foundation.dart';
import 'package:xqmagic/models/board.dart';
import 'package:xqmagic/models/chess_piece.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/coord.dart';
import 'package:xqmagic/utils/fen.dart';

/// 棋盘编辑控制器：管理棋盘编辑模式的状态与操作
///
/// 职责：
/// - 维护编辑状态（选中棋子类型/颜色、放置/删除模式、走子方）
/// - 在 Board 上直接执行放置/删除/清空/初始化操作
/// - 应用编辑（生成 FEN）和取消编辑（重置状态）
///
/// 与 GameStateManager 类似，仅持有 UI 级别的编辑状态，
/// 不依赖 GameController、GameEngine 或其他 Manager。
class BoardEditController extends ChangeNotifier {
  BoardEditController(this._board);

  final Board _board;

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

  void setPieceType(PieceType type) {
    _pieceType = type;
    notifyListeners();
  }

  void setPieceColor(PieceColor color) {
    _pieceColor = color;
    notifyListeners();
  }

  void setSideToMove(PieceColor color) {
    _sideToMove = color;
    notifyListeners();
  }

  void setPlacing(bool placing) {
    _placing = placing;
    notifyListeners();
  }

  // ──────────── 棋盘操作 ────────────

  /// 在 [pos] 放置或删除棋子（根据当前 [placing] 模式）
  void tap(Coord pos) {
    if (!_board.isValidPosition(pos)) return;

    if (_placing) {
      _board.putPiece(
        ChessPiece(type: _pieceType, color: _pieceColor, coord: pos),
      );
    } else {
      _board.removePiece(pos);
    }
    notifyListeners();
  }

  /// 清空棋盘
  void clearBoard() {
    _board.clear();
    notifyListeners();
  }

  /// 初始化标准开局并重置走子方为红方
  void initStandard() {
    _board.initialize();
    _sideToMove = PieceColor.red;
    notifyListeners();
  }

  /// 从当前棋盘生成完整 FEN（含走子方）
  String toFen() => FenParser.generate(_board, _sideToMove);

  // ──────────── 重置 ────────────

  /// 重置所有编辑状态到默认值
  void reset() {
    _pieceType = PieceType.pawn;
    _pieceColor = PieceColor.red;
    _sideToMove = PieceColor.red;
    _placing = true;
    notifyListeners();
  }
}
