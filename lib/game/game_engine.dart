import 'package:magicf/models/board.dart';
import 'package:magicf/models/chess_piece.dart';
import 'package:magicf/models/move.dart';
import 'package:magicf/utils/constants.dart';
import 'package:magicf/utils/fen.dart';
import 'package:magicf/utils/position.dart';

import 'move_validator.dart';

/// 游戏引擎：处理游戏逻辑、走棋验证、胜负判定
/// 支持从 FEN 字符串初始化，适用于棋谱树中的任意局面
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

  /// 获取某位置所有合法走法
  List<MoveRecord> getLegalMoves(Position from) {
    final piece = _board.getPiece(from);
    if (piece == null || piece.color != _currentTurn) return [];

    final allPieces = _board.pieces.values.toList();
    final obstacles = allPieces.map((p) => p.position).toList();
    final moves = <MoveRecord>[];

    for (int col = 0; col < AppConstants.boardCols; col++) {
      for (int row = 0; row < AppConstants.boardRows; row++) {
        final to = Position(col, row);
        final targetPiece = _board.getPiece(to);

        // 不能吃己方棋子
        if (targetPiece != null && targetPiece.color == piece.color) continue;

        final pieceObstacles = obstacles.where((p) => p != to).toList();

        if (MoveValidator.isValidMove(
          type: piece.type,
          color: piece.color,
          from: from,
          to: to,
          obstacles: pieceObstacles,
        )) {
          moves.add(
            MoveRecord(
              from: from,
              to: to,
              capturedPiece: targetPiece,
              color: piece.color,
            ),
          );
        }
      }
    }
    return moves;
  }

  /// 获取某方所有棋子的所有合法走法
  List<MoveRecord> getAllLegalMoves(PieceColor color) {
    final pieces = _board.getPiecesOfColor(color);
    final moves = <MoveRecord>[];
    for (final piece in pieces) {
      moves.addAll(getLegalMoves(piece.position));
    }
    return moves;
  }

  /// 执行走棋
  bool executeMove(Position from, Position to) {
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
  Position? _findGeneral(PieceColor color) {
    for (final piece in _board.pieces.values) {
      if (piece.type == PieceType.general && piece.color == color) {
        return piece.position;
      }
    }
    return null;
  }

  /// 获取当前局面 FEN
  String get currentFen => FenParser.generate(_board, _currentTurn);
}
