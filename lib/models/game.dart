import 'board.dart';
import 'chess_piece.dart';
import 'move.dart';
import '../utils/constants.dart';
import '../utils/position.dart';

/// 游戏状态
enum GameState { idle, playing, checkmate, draw }

/// 游戏整体状态
class Game {
  Game()
      : board = Board(),
        currentTurn = PieceColor.red,
        state = GameState.idle,
        moveHistory = [];

  final Board board;
  PieceColor currentTurn;
  GameState state;
  final List<MoveRecord> moveHistory;

  /// 开始新游戏
  void startNewGame() {
    board.initialize();
    currentTurn = PieceColor.red;
    state = GameState.playing;
    moveHistory.clear();
  }

  /// 尝试移动棋子
  bool movePiece(int fromCol, int fromRow, int toCol, int toRow) {
    if (state != GameState.playing) return false;

    final result = board.movePiece(
      Position(fromCol, fromRow),
      Position(toCol, toRow),
    );

    if (result == null) return false;

    moveHistory.add(MoveRecord(
      from: Position(fromCol, fromRow),
      to: Position(toCol, toRow),
      capturedPiece: result,
      color: currentTurn,
    ));

    currentTurn = currentTurn == PieceColor.red
        ? PieceColor.black
        : PieceColor.red;

    return true;
  }

  /// 获取当前回合的棋子
  List<ChessPiece> getCurrentTurnPieces() {
    return board.getPiecesOfColor(currentTurn);
  }

  /// 判断某方是否被将（简单判断：将/帅被攻击）
  bool isInCheck(PieceColor color) {
    // TODO: 实现完整的将军检测
    return false;
  }
}
