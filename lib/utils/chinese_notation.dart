import 'package:xqmagic/utils/app_logger.dart';
import 'package:xqmagic/models/chess_piece.dart';
import 'package:xqmagic/models/move.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/coord.dart';

/// 中国象棋中文记谱法（符合1999竞赛规则 + WXF标准）
///
/// 记谱法格式（四字/五字）：
/// - 第1字：棋子名称（车、马、炮、相等）
/// - 第2字：所在纵线编号（红方中文数字一~九，黑方阿拉伯数字1~9）
/// - 第3字：移动方向（进、退、平）
/// - 第4字：目标位置
///
/// WXF格式：单字母+数字+方向+目标，作为中间表示便于简繁转换
/// - 例: C2.5 (炮二平五), N8+7 (马8进7), R2+3 (车二进三)

/// 走法方向分类（用于消除中文/WXF 之间的重复方向判断逻辑）
enum _MovementType { flat, forward, backward }

class ChineseNotation {
  ChineseNotation._();

  /// 中文数字映射
  static const _chineseNumbers = [
    '零',
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '七',
    '八',
    '九',
  ];

  // ========== 棋盘 Normalize/Denormalize ==========

  /// Normalize 坐标：将黑方视角转为红方视角
  ///
  /// 黑方走棋时，将棋盘旋转180度，按红方角度计算
  /// 旋转后：col' = 8 - col, row' = 9 - row
  static Coord normalizeCoord(Coord coord, PieceColor color) {
    if (color == PieceColor.red) return coord;
    return Coord(8 - coord.col, 9 - coord.row);
  }

  /// Denormalize 坐标：从红方视角转回原始视角
  static Coord denormalizeCoord(Coord coord, PieceColor color) {
    if (color == PieceColor.red) return coord;
    return Coord(8 - coord.col, 9 - coord.row);
  }

  /// Normalize 棋盘：将黑方的棋子坐标转为红方视角
  ///
  /// 返回一个新的棋盘 Map，其中所有黑方棋子坐标已旋转
  /// 红方棋子保持原坐标不变
  static Map<Coord, ChessPiece> normalizeBoard(
    Map<Coord, ChessPiece> board,
    PieceColor perspectiveColor,
  ) {
    if (perspectiveColor == PieceColor.red) return board;

    final result = <Coord, ChessPiece>{};
    for (final entry in board.entries) {
      final piece = entry.value;
      final newCoord = normalizeCoord(entry.key, perspectiveColor);
      final newPiece = ChessPiece(
        type: piece.type,
        color: piece.color,
        coord: newCoord,
      );
      result[newCoord] = newPiece;
    }
    return result;
  }

  /// Normalize 走法记录：将黑方走法转为红方视角
  ///
  /// 使用 [MoveRecord.copyWith] 以保留 `notation` / `nextColor` /
  /// `boardBefore/After` / `fenBefore/After` 等所有可选字段。
  /// 旧实现重新构造 MoveRecord 会丢失这些字段——任何未来调用者如果
  /// 将结果存储或传递，就会静默丢数据。
  static MoveRecord normalizeMove(MoveRecord move) {
    if (move.color == PieceColor.red) return move;
    return move.copyWith(
      from: normalizeCoord(move.from, move.color),
      to: normalizeCoord(move.to, move.color),
      capturedPiece: move.capturedPiece != null
          ? ChessPiece(
              type: move.capturedPiece!.type,
              color: move.capturedPiece!.color,
              coord: normalizeCoord(move.capturedPiece!.coord, move.color),
            )
          : null,
    );
  }

  // ========== 标准中文记谱法 ==========

  /// 将走法记录转换为标准中文记谱法（四字/五字格式）
  ///
  /// **视角转换策略：唯一转换点**
  /// 1. 黑方走子时，先 normalize 棋盘和走法到红方视角
  /// 2. 所有计算（行差、纵线、同线多子）统一按红方视角
  /// 3. isRed 仅用于输出格式化（中文数字 vs 阿拉伯数字）
  ///
  /// [board] 当前棋盘（用于检查同线是否有同类型棋子）
  /// [move] 走法记录
  /// [useSimpleText] 是否使用简体中文（默认true），false 则使用繁体
  static String toText(
    Map<Coord, ChessPiece> board,
    MoveRecord move, {
    bool useSimpleText = true,
  }) {
    final isRed = move.color == PieceColor.red;

    // 视角归一化：黑方走棋时，将棋盘和走法旋转到红方视角
    final normBoard = isRed ? board : normalizeBoard(board, PieceColor.black);
    final normMove = isRed ? move : normalizeMove(move);

    // === 以下所有计算均基于红方视角 ===

    final pieceName = _getPieceName(
      normMove.pieceType,
      normMove.color,
      useSimpleText,
    );

    // 纵线编号（红方视角：col 8=一路, col 0=九路）
    final fromFile = _getFileNumberFromRed(normMove.from.col, isRed);
    final toFile = _getFileNumberFromRed(normMove.to.col, isRed);

    // 同线多子检测（红方视角）
    final prefix = _getMultiPiecePrefixFromRed(normBoard, normMove);

    final colDiff = normMove.to.col - normMove.from.col;
    final rowDiff = normMove.to.row - normMove.from.row;

    final (action, target) = _getActionAndTarget(
      colDiff,
      rowDiff,
      toFile,
      normMove.pieceType,
      isRed,
    );

    String result;
    if (prefix != null) {
      result = '$prefix$pieceName$action$target';
    } else {
      result = '$pieceName$fromFile$action$target';
    }

    return result;
  }

  // ========== WXF 记谱法 ==========

  /// 将走法转换为 WXF 格式（World Xiangqi Federation Notation）
  ///
  /// 视角归一化：黑方走棋时，先 normalize 到红方视角
  static String toWXF(Map<Coord, ChessPiece> board, MoveRecord move) {
    final isRed = move.color == PieceColor.red;

    // 视角归一化
    final normBoard = isRed ? board : normalizeBoard(board, PieceColor.black);
    final normMove = isRed ? move : normalizeMove(move);

    // === 以下所有计算均基于红方视角 ===
    final pieceLetter = _getPieceLetter(normMove.pieceType);

    // 纵线编号（红方视角：col 8=1, col 0=9）
    final fromFile = 9 - normMove.from.col;
    final toFile = 9 - normMove.to.col;

    // 同线多子检测（红方视角）
    final prefix = _getWXFMultiPiecePrefixFromRed(normBoard, normMove);

    final colDiff = normMove.to.col - normMove.from.col;
    final rowDiff = normMove.to.row - normMove.from.row;

    final (direction, target) = _getWXFActionAndTarget(
      colDiff,
      rowDiff,
      toFile,
      normMove.pieceType,
    );

    if (prefix != null) {
      return '$prefix$pieceLetter$fromFile$direction$target';
    }
    return '$pieceLetter$fromFile$direction$target';
  }

  /// 从 WXF 格式解析为坐标
  ///
  /// 需要传入棋盘以处理前/后缀的情况
  /// 返回 (from, to) 坐标，如果解析失败或位置非法则返回 null
  ///
  /// 增加验证：
  /// - 检查棋盘上是否存在对应的棋子
  /// - 检查目标位置是否在棋盘范围内
  /// - 检查走法是否符合棋子规则
  static (Coord, Coord)? fromWXF(
    Map<Coord, ChessPiece> board,
    String wxf,
    PieceColor color, {
    bool validateBoard = false, // 默认不验证棋盘状态，仅解析记谱法
  }) {
    if (wxf.length < 3) return null;

    final isRed = color == PieceColor.red;
    int idx = 0;

    // 解析前缀（f=前, b=后, m=中）
    String? prefix;
    if (wxf.startsWith('f') || wxf.startsWith('b') || wxf.startsWith('m')) {
      prefix = wxf[0];
      idx = 1;
    }

    if (idx >= wxf.length) return null;

    // 解析棋子字母
    final pieceChar = wxf[idx].toUpperCase();
    final type = _pieceLetterToType(pieceChar);
    if (type == null) return null;
    idx++;

    if (idx >= wxf.length) return null;

    // 解析纵线
    final fileStr = wxf[idx];
    final fileNum = int.tryParse(fileStr);
    if (fileNum == null || fileNum < 1 || fileNum > 9) return null;
    idx++;

    if (idx >= wxf.length) return null;

    // 解析方向
    final directionChar = wxf[idx];
    if (!'+-.'.contains(directionChar)) return null;
    idx++;

    // 解析目标
    if (idx >= wxf.length) return null;
    final targetStr = wxf.substring(idx);
    final targetNum = int.tryParse(targetStr);
    if (targetNum == null) return null;

    // 转换纵线为 col（从走棋方视角）
    // 红方：file = 9 - col → col = 9 - file
    // 黑方：file = col + 1 → col = file - 1
    final fromCol = isRed ? 9 - fileNum : fileNum - 1;

    // 找到起始位置的棋子
    final fromCoord = _findPieceByCol(board, type, fromCol, color, prefix);
    if (fromCoord == null) {
      // 棋盘上不存在对应的棋子（例如 R2+3 但 2 路没有车）
      return null;
    }

    // 验证：如果要求验证棋盘，确保起始位置确实有对应颜色和类型的棋子
    if (validateBoard) {
      final pieceAtFrom = board[fromCoord];
      if (pieceAtFrom == null ||
          pieceAtFrom.color != color ||
          pieceAtFrom.type != type) {
        return null;
      }
    }

    // 计算目标位置
    final toCoord = _calculateTarget(
      fromCoord,
      directionChar,
      targetNum,
      isRed,
      type,
    );
    if (toCoord == null) return null;

    // 验证目标位置是否在棋盘范围内
    if (toCoord.col < 0 ||
        toCoord.col > 8 ||
        toCoord.row < 0 ||
        toCoord.row > 9) {
      return null;
    }

    // 验证：目标位置不能有己方棋子
    if (validateBoard) {
      final pieceAtTo = board[toCoord];
      if (pieceAtTo != null && pieceAtTo.color == color) {
        return null;
      }
    }

    return (fromCoord, toCoord);
  }

  // ========== 内部方法 ==========

  /// 获取棋子名称（根据颜色区分）
  static String _getPieceName(
    PieceType? type,
    PieceColor color,
    bool useSimpleText,
  ) {
    if (type == null) {
      AppLogger.warn('ChineseNotation', 'pieceType is null, color=$color');
      return '?';
    }

    // 检查索引范围
    if (type.index < 0 || type.index > 6) {
      AppLogger.warn(
        'ChineseNotation',
        'invalid pieceType.index=${type.index}, type=$type',
      );
      return '?';
    }

    if (useSimpleText) {
      // 简体中文：红黑双方用不同的字
      const redNames = ['帅', '仕', '相', '马', '车', '炮', '兵'];
      const blackNames = ['将', '士', '象', '马', '车', '炮', '卒'];
      return color == PieceColor.red
          ? redNames[type.index]
          : blackNames[type.index];
    } else {
      // 繁体中文
      const redNames = ['帥', '仕', '相', '傌', '俥', '砲', '兵'];
      const blackNames = ['將', '士', '象', '馬', '車', '砲', '卒'];
      return color == PieceColor.red
          ? redNames[type.index]
          : blackNames[type.index];
    }
  }

  /// 获取棋子字母（WXF格式）
  static String _getPieceLetter(PieceType? type) {
    if (type == null) return '?';
    const letters = ['K', 'A', 'B', 'N', 'R', 'C', 'P'];
    return letters[type.index];
  }

  /// 获取纵线编号（红方视角：col 8=1路, col 0=9路）
  /// isRed 仅用于选择数字格式（中文数字 vs 阿拉伯数字）
  static String _getFileNumberFromRed(int col, bool isRed) {
    final fileNumber = 9 - col;
    return isRed ? _chineseNumbers[fileNumber] : fileNumber.toString();
  }

  /// 是否为直线行走棋子（车、炮、帅、兵）
  static bool _isStraightPiece(PieceType type) {
    return type == PieceType.rook ||
        type == PieceType.cannon ||
        type == PieceType.king ||
        type == PieceType.pawn;
  }

  /// 统一的"走法概要"：(方向类型, 步数或目标纵线)
  ///
  /// 返回的字段分别表示：
  /// - [_MovementType] 平/进/退 三类
  /// - 步数（直线前进/后退时）或目标纵线（横向/斜线时）
  static (_MovementType type, int value) _resolveMovement(
    int colDiff,
    int rowDiff,
    PieceType? type,
  ) {
    if (rowDiff == 0) {
      // 平：rowDiff=0，colDiff 必非零（否则不可能是合法走法）
      return (_MovementType.flat, 0);
    }
    final isStraight = type != null && _isStraightPiece(type);
    if (isStraight && colDiff == 0) {
      return (
        rowDiff > 0 ? _MovementType.forward : _MovementType.backward,
        rowDiff.abs(),
      );
    }
    return (rowDiff > 0 ? _MovementType.forward : _MovementType.backward, 0);
  }

  /// 获取中文记谱法的动作和目标（红方视角）
  static (String action, String target) _getActionAndTarget(
    int colDiff,
    int rowDiff,
    String toFile,
    PieceType? type,
    bool isRed,
  ) {
    final movementResult = _resolveMovement(colDiff, rowDiff, type);
    switch (movementResult.$1) {
      case _MovementType.flat:
        return ('平', toFile);
      case _MovementType.forward:
        if (movementResult.$2 > 0) {
          final v = movementResult.$2;
          final t = isRed ? _chineseNumbers[v] : v.toString();
          return ('进', t);
        }
        return ('进', toFile);
      case _MovementType.backward:
        if (movementResult.$2 > 0) {
          final v = movementResult.$2;
          final t = isRed ? _chineseNumbers[v] : v.toString();
          return ('退', t);
        }
        return ('退', toFile);
    }
  }

  /// 获取 WXF 格式的动作和目标
  static (String direction, String target) _getWXFActionAndTarget(
    int colDiff,
    int rowDiff,
    int toFile,
    PieceType? type,
  ) {
    final movementResult = _resolveMovement(colDiff, rowDiff, type);
    switch (movementResult.$1) {
      case _MovementType.flat:
        return ('.', toFile.toString());
      case _MovementType.forward:
        if (movementResult.$2 > 0) {
          return ('+', movementResult.$2.toString());
        }
        return ('+', toFile.toString());
      case _MovementType.backward:
        if (movementResult.$2 > 0) {
          return ('-', movementResult.$2.toString());
        }
        return ('-', toFile.toString());
    }
  }

  /// 收集与 [move] 同色同类型且同纵线的棋子（红方视角，按"前"到"后"排序）
  ///
  /// 返回 `null` 表示无需前缀（线上仅 1 个棋子）；否则返回 (棋子总数, 移动方在排序中的索引)
  static (int total, int idx)? _collectSameFilePieces(
    Map<Coord, ChessPiece> board,
    MoveRecord move,
  ) {
    final moveFile = 9 - move.from.col;
    final pieces = <ChessPiece>[];
    for (final piece in board.values) {
      if (piece.type == move.pieceType && piece.color == move.color) {
        final pieceFile = 9 - piece.coord.col;
        if (pieceFile == moveFile) pieces.add(piece);
      }
    }
    if (pieces.length <= 1) return null;

    // 红方视角：row 越大越靠前
    pieces.sort((a, b) => b.coord.row.compareTo(a.coord.row));
    final idx = pieces.indexWhere((p) => p.coord == move.from);
    return (pieces.length, idx);
  }

  /// 检查同线是否有同类型棋子，返回前/后/中缀（红方视角）
  static String? _getMultiPiecePrefixFromRed(
    Map<Coord, ChessPiece> board,
    MoveRecord move,
  ) {
    final result = _collectSameFilePieces(board, move);
    if (result == null) return null;
    final (count, myIdx) = result;
    if (count == 2) return myIdx == 0 ? '前' : '后';
    if (myIdx == 0) return '前';
    if (myIdx == count - 1) return '后';
    if (count == 3 && myIdx == 1) return '中';
    const numWords = ['', '一', '二', '三', '四', '五'];
    return numWords[myIdx + 1];
  }

  /// 获取 WXF 格式的多子前缀（红方视角）
  static String? _getWXFMultiPiecePrefixFromRed(
    Map<Coord, ChessPiece> board,
    MoveRecord move,
  ) {
    final result = _collectSameFilePieces(board, move);
    if (result == null) return null;
    final (count, myIdx) = result;
    if (count == 2) return myIdx == 0 ? 'f' : 'b';
    if (myIdx == 0) return 'f';
    if (myIdx == count - 1) return 'b';
    return 'm'; // middle
  }

  /// 通过 WXF 棋子字母找到棋盘上的对应棋子坐标
  static Coord? _findPieceByCol(
    Map<Coord, ChessPiece> board,
    PieceType type,
    int fromCol,
    PieceColor color,
    String? prefix,
  ) {
    final isRed = color == PieceColor.red;
    final candidates = <ChessPiece>[];
    for (final entry in board.entries) {
      final piece = entry.value;
      if (piece.type == type && piece.color == color) {
        // 直接比较 col 值，不需要转换
        if (entry.key.col == fromCol) {
          candidates.add(piece);
        }
      }
    }

    if (candidates.isEmpty) return null;
    if (candidates.length == 1) return candidates.first.coord;

    // 多个候选，用前缀区分
    // 红方：row 越大越靠前，黑方：row 越小越靠前
    candidates.sort((a, b) {
      if (isRed) {
        return b.coord.row.compareTo(a.coord.row);
      } else {
        return a.coord.row.compareTo(b.coord.row);
      }
    });

    switch (prefix) {
      case 'f':
        return candidates.first.coord; // 前
      case 'b':
        return candidates.last.coord; // 后
      case 'm':
        return candidates[candidates.length ~/ 2].coord; // 中
      default:
        return candidates.first.coord;
    }
  }

  /// 根据方向和目标计算目标坐标
  static Coord? _calculateTarget(
    Coord from,
    String direction,
    int target,
    bool isRed,
    PieceType type,
  ) {
    switch (direction) {
      case '.':
        // 平：横向移动
        // 红方：toCol = 9 - target
        // 黑方：toCol = target - 1
        final toCol = isRed ? 9 - target : target - 1;
        return Coord(toCol, from.row);
      case '+':
      case '-':
        return _calculateForwardBackward(
          from,
          direction == '+' ? 1 : -1,
          target,
          isRed,
          type,
        );
      default:
        return null;
    }
  }

  /// 计算进/退方向的目标坐标。
  /// [rowSign] = +1 表示进，-1 表示退
  static Coord? _calculateForwardBackward(
    Coord from,
    int rowSign,
    int target,
    bool isRed,
    PieceType type,
  ) {
    if (_isStraightPiece(type)) {
      // 直线移动（车/炮/帅/兵）
      // 红方：进=row 增大，退=row 减小；黑方相反
      final rowDelta = (isRed ? rowSign : -rowSign) * target;
      return Coord(from.col, from.row + rowDelta);
    }
    // 斜线/马：target 是目标纵线
    final toCol = isRed ? 9 - target : target - 1;
    final colChange = (toCol - from.col).abs();
    final rowDelta = isRed ? rowSign : -rowSign;

    if (type == PieceType.knight) {
      // 马：走日字，col 变化1则 row 变化2，col 变化2则 row 变化1
      final rowChange = colChange == 1 ? 2 : 1;
      return Coord(toCol, from.row + rowDelta * rowChange);
    }
    // 士/象：斜线移动
    return Coord(toCol, from.row + rowDelta * colChange);
  }

  /// WXF 棋子字母转 PieceType
  static PieceType? _pieceLetterToType(String letter) {
    switch (letter) {
      case 'K':
        return PieceType.king;
      case 'A':
        return PieceType.advisor;
      case 'B':
        return PieceType.bishop;
      case 'N':
        return PieceType.knight;
      case 'R':
        return PieceType.rook;
      case 'C':
        return PieceType.cannon;
      case 'P':
        return PieceType.pawn;
      default:
        return null;
    }
  }
}
