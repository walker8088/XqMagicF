import 'package:xqmagic/models/board.dart';
import 'package:xqmagic/models/chess_piece.dart';
import 'package:xqmagic/models/move.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/fen.dart';
import 'package:xqmagic/utils/coord.dart';

import 'move_validator.dart';

/// 游戏引擎：处理游戏逻辑、走棋验证、胜负判定
/// 支持从 FEN 字符串初始化，适用于棋谱树中的任意局面
/// 是游戏中唯一的规则和状态仲裁者
class GameEngine {
  final Board _board;
  PieceColor _currentTurn;

  GameEngine(String fen) : _board = Board(), _currentTurn = PieceColor.red {
    _currentTurn = FenParser.parse(fen, _board);
  }

  /// 从已初始化的棋盘创建
  GameEngine.fromBoard(this._board, this._currentTurn);

  Board get board => _board;
  PieceColor get currentTurn => _currentTurn;

  /// 获取某位置所有合法走法（仅限当前回合方）
  List<MoveRecord> getLegalMoves(Coord from) {
    final piece = _board.getPiece(from);
    if (piece == null || piece.color != _currentTurn) return [];
    return _generateMovesFor(from, piece);
  }

  /// 获取某方所有棋子的所有合法走法
  List<MoveRecord> getAllLegalMoves(PieceColor color) {
    final pieces = _board.getPiecesOfColor(color);
    final moves = <MoveRecord>[];
    for (final piece in pieces) {
      moves.addAll(_generateMovesFor(piece.coord, piece));
    }
    return moves;
  }

  /// 内部：生成指定棋子的所有合法走法（不限制回合）
  List<MoveRecord> _generateMovesFor(Coord from, ChessPiece piece) {
    final allPieces = _board.pieces.values.toList();
    // Pass full obstacles list (including target) — cannon needs this
    // to distinguish between moving (count=0) and capturing (count=1).
    // _countPiecesBetween only counts pieces BETWEEN from and to,
    // so including the target position doesn't affect path checks.
    final obstacles = allPieces.map((p) => p.coord).toList();
    final moves = <MoveRecord>[];

    for (int col = 0; col < AppConstants.boardCols; col++) {
      for (int row = 0; row < AppConstants.boardRows; row++) {
        final to = Coord(col, row);
        final targetPiece = _board.getPiece(to);

        // 不能吃己方棋子
        if (targetPiece != null && targetPiece.color == piece.color) continue;

        if (MoveValidator.isValidMove(
          type: piece.type,
          color: piece.color,
          from: from,
          to: to,
          obstacles: obstacles,
        )) {
          moves.add(
            MoveRecord(
              from: from,
              to: to,
              pieceType: piece.type,
              capturedPiece: targetPiece,
              color: piece.color,
            ),
          );
        }
      }
    }
    return moves;
  }

  /// 执行走棋
  bool executeMove(Coord from, Coord to) {
    final piece = _board.getPiece(from);
    if (piece == null) return false;

    final legalMoves = getLegalMoves(from);
    final isLegal = legalMoves.any((m) => m.to == to);
    if (!isLegal) return false;

    _board.movePiece(from, to);
    _currentTurn = _currentTurn == PieceColor.red
        ? PieceColor.black
        : PieceColor.red;

    return true;
  }

  /// 检查某方是否被将军
  bool isInCheck(PieceColor color) {
    final generalPos = _findGeneral(color);
    if (generalPos == null) return false;

    final opponentColor = color == PieceColor.red
        ? PieceColor.black
        : PieceColor.red;
    final opponentMoves = getAllLegalMoves(opponentColor);
    return opponentMoves.any((m) => m.to == generalPos);
  }

  /// 检查某方是否被将杀（无合法走法且被将军）
  bool isCheckmate(PieceColor color) {
    if (!isInCheck(color)) return false;
    return getAllLegalMoves(color).isEmpty;
  }

  /// 检查某方是否被困毙（无合法走法但未被将军）
  bool isStalemate(PieceColor color) {
    if (isInCheck(color)) return false;
    return getAllLegalMoves(color).isEmpty;
  }

  /// 查找将/帅的位置
  Coord? _findGeneral(PieceColor color) {
    for (final piece in _board.pieces.values) {
      if (piece.type == PieceType.king && piece.color == color) {
        return piece.coord;
      }
    }
    return null;
  }

  /// 获取当前局面 FEN
  String get currentFen => FenParser.generate(_board, _currentTurn);

  /// 开始新游戏（标准开局）
  void startNewGame() {
    _board.initialize();
    _currentTurn = PieceColor.red;
  }

  /// 用当前状态重新创建引擎（用于模拟操作）
  GameEngine copy() {
    final newBoard = Board();
    FenParser.parse(currentFen, newBoard);
    return GameEngine.fromBoard(newBoard, _currentTurn);
  }

  /// 不验证规则地直接移动棋子（用于棋谱回放）
  /// 返回被吃掉的棋子（如有）
  ChessPiece? forceMove(Coord from, Coord to) {
    final captured = _board.movePiece(from, to);
    _currentTurn = _currentTurn == PieceColor.red
        ? PieceColor.black
        : PieceColor.red;
    return captured;
  }
}
