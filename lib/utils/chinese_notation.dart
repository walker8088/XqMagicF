import 'package:flutter/foundation.dart';
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
class ChineseNotation {
  ChineseNotation._();

  /// 中文数字映射
  static const _chineseNumbers = ['零', '一', '二', '三', '四', '五', '六', '七', '八', '九'];

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
  static MoveRecord normalizeMove(MoveRecord move) {
    if (move.color == PieceColor.red) return move;
    return MoveRecord(
      from: normalizeCoord(move.from, move.color),
      to: normalizeCoord(move.to, move.color),
      pieceType: move.pieceType,
      capturedPiece: move.capturedPiece != null
          ? ChessPiece(
              type: move.capturedPiece!.type,
              color: move.capturedPiece!.color,
              coord: normalizeCoord(move.capturedPiece!.coord, move.color),
            )
          : null,
      color: move.color,
    );
  }

  // ========== 标准中文记谱法 ==========

  /// 将走法记录转换为标准中文记谱法（四字/五字格式）
  ///
  /// 需要传入当前棋盘状态以处理同线多子的情况
  /// [board] 当前棋盘（用于检查同线是否有同类型棋子）
  /// [move] 走法记录
  /// [useSimpleText] 是否使用简体中文（默认true），false 则使用繁体
  static String toText(
    Map<Coord, ChessPiece> board,
    MoveRecord move, {
    bool useSimpleText = true,
  }) {
    final isRed = move.color == PieceColor.red;

    final pieceName = _getPieceName(move.pieceType, move.color, useSimpleText);

    // 获取纵线编号（从走棋方视角，从右到左 1-9）
    // 公式：file = 9 - col，对红黑双方都适用
    final fromFile = _getFileNumber(move.from.col, isRed);
    final toFile = _getFileNumber(move.to.col, isRed);

    // 检查同线是否有同类型棋子（需要前/后区分）
    final prefix = _getMultiPiecePrefix(board, move, isRed);

    final colDiff = move.to.col - move.from.col;
    final rowDiff = _getRowDiff(move, isRed);

    final (action, target) = _getActionAndTarget(
      colDiff,
      rowDiff,
      toFile,
      move.pieceType,
      isRed,
    );

    if (prefix != null) {
      return '$prefix$pieceName$action$target';
    }
    return '$pieceName$fromFile$action$target';
  }

  // ========== WXF 记谱法 ==========

  /// 将走法转换为 WXF 格式（World Xiangqi Federation Notation）
  ///
  /// WXF 格式：棋子字母 + 纵线 + 方向符号 + 目标
  /// - 棋子字母：K(将/帅) A(士/仕) B(象/相) N(马/傌) R(车/俥) C(炮/砲) P(卒/兵)
  /// - 纵线：统一用阿拉伯数字 1-9（从走棋方视角从右到左）
  /// - 方向符号：+ (进)  - (退)  . (平)
  /// - 目标：平=目标纵线；进/退直线=步数；进/退斜线=落点纵线
  ///
  /// 例如：
  /// - C2.5 = 炮二平五
  /// - N8+7 = 马8进7
  /// - R2+3 = 车二进三
  /// - P3.4 = 兵三平四
  /// - fC2.5 = 前炮平五（同线多子）
  /// - bN8-7 = 后马退7
  static String toWXF(
    Map<Coord, ChessPiece> board,
    MoveRecord move,
  ) {
    final isRed = move.color == PieceColor.red;

    final pieceLetter = _getPieceLetter(move.pieceType);

    // WXF 纵线编号（从走棋方视角，从右到左 1-9）
    // 红方：file = 9 - col
    // 黑方：file = col + 1
    final fromFile = isRed ? 9 - move.from.col : move.from.col + 1;

    // 检查同线多子
    final prefix = _getWXFMultiPiecePrefix(board, move);

    final colDiff = move.to.col - move.from.col;
    final rowDiff = _getRowDiff(move, isRed);
    final toFile = isRed ? 9 - move.to.col : move.to.col + 1;

    final (direction, target) = _getWXFActionAndTarget(
      colDiff,
      rowDiff,
      toFile,
      move.pieceType,
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
    final fromCoord = _findPieceByFile(board, type, fromCol, color, prefix);
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
    final toCoord = _calculateTarget(fromCoord, directionChar, targetNum, isRed, type);
    if (toCoord == null) return null;

    // 验证目标位置是否在棋盘范围内
    if (toCoord.col < 0 || toCoord.col > 8 || toCoord.row < 0 || toCoord.row > 9) {
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
  static String _getPieceName(PieceType? type, PieceColor color, bool useSimpleText) {
    if (type == null) {
      debugPrint('[ChineseNotation] WARN: pieceType is null, color=$color');
      return '?';
    }

    // 检查索引范围
    if (type.index < 0 || type.index > 6) {
      debugPrint('[ChineseNotation] WARN: invalid pieceType.index=${type.index}, type=$type');
      return '?';
    }

    if (useSimpleText) {
      // 简体中文：红黑双方用不同的字
      const redNames = ['帅', '仕', '相', '马', '车', '炮', '兵'];
      const blackNames = ['将', '士', '象', '马', '车', '炮', '卒'];
      return color == PieceColor.red ? redNames[type.index] : blackNames[type.index];
    } else {
      // 繁体中文
      const redNames = ['帥', '仕', '相', '傌', '俥', '砲', '兵'];
      const blackNames = ['將', '士', '象', '馬', '車', '砲', '卒'];
      return color == PieceColor.red ? redNames[type.index] : blackNames[type.index];
    }
  }

  /// 获取棋子字母（WXF格式）
  static String _getPieceLetter(PieceType? type) {
    if (type == null) return '?';
    const letters = ['K', 'A', 'B', 'N', 'R', 'C', 'P'];
    return letters[type.index];
  }

  /// 获取纵线编号（从走棋方视角，从右到左 1-9）
  /// 红方用中文数字，黑方用阿拉伯数字
  static String _getFileNumber(int col, bool isRed) {
    // 红方：从右到左为一~九路（col 8=一路, col 0=九路）
    // 黑方：从右到左为1~9路（col 0=1路, col 8=9路）
    final fileNumber = isRed ? 9 - col : col + 1;
    if (isRed) {
      return _chineseNumbers[fileNumber];
    }
    return fileNumber.toString();
  }

  /// 计算行差（从走棋方视角）
  /// 红方：row 增大 = 前进（进），row 减小 = 后退（退）
  /// 黑方：row 减小 = 前进（进），row 增大 = 后退（退）
  /// 返回值：正数=进，负数=退，0=平
  static int _getRowDiff(MoveRecord move, bool isRed) {
    if (isRed) {
      return move.to.row - move.from.row;
    } else {
      return move.from.row - move.to.row;
    }
  }

  /// 是否为直线行走棋子（车、炮、帅、兵）
  static bool _isStraightPiece(PieceType type) {
    return type == PieceType.rook ||
        type == PieceType.cannon ||
        type == PieceType.king ||
        type == PieceType.pawn;
  }

  /// 获取中文记谱法的动作和目标
  static (String action, String target) _getActionAndTarget(
    int colDiff,
    int rowDiff,
    String toFile,
    PieceType? type,
    bool isRed,
  ) {
    if (rowDiff == 0) {
      return ('平', toFile);
    }

    final isStraight = type != null && _isStraightPiece(type);
    final direction = rowDiff > 0 ? '进' : '退';

    if (isStraight && colDiff == 0) {
      // 直线前进/后退，显示步数
      final steps = rowDiff.abs();
      // 红方用中文数字，黑方用阿拉伯数字
      final target = isRed ? _chineseNumbers[steps] : steps.toString();
      return (direction, target);
    } else {
      // 斜线前进/后退（马、士、象），显示目标纵线
      return (direction, toFile);
    }
  }

  /// 获取 WXF 格式的动作和目标
  static (String direction, String target) _getWXFActionAndTarget(
    int colDiff,
    int rowDiff,
    int toFile,
    PieceType? type,
  ) {
    if (rowDiff == 0) {
      return ('.', toFile.toString());
    }

    final isStraight = type != null && _isStraightPiece(type);
    final direction = rowDiff > 0 ? '+' : '-';

    if (isStraight && colDiff == 0) {
      return (direction, rowDiff.abs().toString());
    } else {
      return (direction, toFile.toString());
    }
  }

  /// 检查同线是否有同类型棋子，返回前/后/中缀
  static String? _getMultiPiecePrefix(
    Map<Coord, ChessPiece> board,
    MoveRecord move,
    bool isRed,
  ) {
    if (move.pieceType == null) return null;

    int countOnFile = 0;
    List<ChessPiece> piecesOnFile = [];
    for (final piece in board.values) {
      if (piece.type == move.pieceType! && piece.color == move.color) {
        final pieceFile = isRed ? 9 - piece.coord.col : piece.coord.col + 1;
        final moveFile = isRed ? 9 - move.from.col : move.from.col + 1;
        if (pieceFile == moveFile) {
          countOnFile++;
          piecesOnFile.add(piece);
        }
      }
    }

    if (countOnFile <= 1) return null;

    // 按"前/后"排序（从走棋方视角的前方 = 靠近对方底线）
    // 红方：row 越大越靠前（靠近黑方）
    // 黑方：row 越小越靠前（靠近红方）
    piecesOnFile.sort((a, b) {
      if (isRed) {
        return b.coord.row.compareTo(a.coord.row); // row 大的在前
      } else {
        return a.coord.row.compareTo(b.coord.row); // row 小的在前
      }
    });

    final myIdx = piecesOnFile.indexWhere((p) => p.coord == move.from);

    if (countOnFile == 2) {
      return myIdx == 0 ? '前' : '后';
    } else {
      if (myIdx == 0) return '前';
      if (myIdx == countOnFile - 1) return '后';
      if (countOnFile == 3 && myIdx == 1) return '中';
      const numWords = ['', '一', '二', '三', '四', '五'];
      return '${numWords[myIdx + 1]}';
    }
  }

  /// 获取 WXF 格式的多子前缀
  static String? _getWXFMultiPiecePrefix(
    Map<Coord, ChessPiece> board,
    MoveRecord move,
  ) {
    if (move.pieceType == null) return null;
    final isRed = move.color == PieceColor.red;

    int countOnFile = 0;
    List<ChessPiece> piecesOnFile = [];
    for (final piece in board.values) {
      if (piece.type == move.pieceType! && piece.color == move.color) {
        final pieceFile = isRed ? 9 - piece.coord.col : piece.coord.col + 1;
        final moveFile = isRed ? 9 - move.from.col : move.from.col + 1;
        if (pieceFile == moveFile) {
          countOnFile++;
          piecesOnFile.add(piece);
        }
      }
    }

    if (countOnFile <= 1) return null;

    piecesOnFile.sort((a, b) {
      if (isRed) {
        return b.coord.row.compareTo(a.coord.row);
      } else {
        return a.coord.row.compareTo(b.coord.row);
      }
    });

    final myIdx = piecesOnFile.indexWhere((p) => p.coord == move.from);

    if (countOnFile == 2) {
      return myIdx == 0 ? 'f' : 'b';
    } else {
      if (myIdx == 0) return 'f';
      if (myIdx == countOnFile - 1) return 'b';
      return 'm'; // middle
    }
  }

  /// 通过 WXF 棋子字母找到棋盘上的对应棋子坐标
  static Coord? _findPieceByFile(
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
        // 进（向前）
        if (_isStraightPiece(type)) {
          // 直线前进：红方 row 增大，黑方 row 减小
          return Coord(from.col, isRed ? from.row + target : from.row - target);
        } else if (type == PieceType.knight) {
          // 马：走日字，col 变化1则 row 变化2，col 变化2则 row 变化1
          final toCol = isRed ? 9 - target : target - 1;
          final colChange = (toCol - from.col).abs();
          final rowChange = colChange == 1 ? 2 : 1;
          return Coord(toCol, isRed ? from.row + rowChange : from.row - rowChange);
        } else {
          // 士/象：斜线前进，target 是目标纵线
          final toCol = isRed ? 9 - target : target - 1;
          final rowOffset = (toCol - from.col).abs();
          // 红方前进 = row 增大，黑方前进 = row 减小
          return Coord(toCol, isRed ? from.row + rowOffset : from.row - rowOffset);
        }
      case '-':
        // 退（向后）
        if (_isStraightPiece(type)) {
          return Coord(from.col, isRed ? from.row - target : from.row + target);
        } else if (type == PieceType.knight) {
          final toCol = isRed ? 9 - target : target - 1;
          final colChange = (toCol - from.col).abs();
          final rowChange = colChange == 1 ? 2 : 1;
          return Coord(toCol, isRed ? from.row - rowChange : from.row + rowChange);
        } else {
          final toCol = isRed ? 9 - target : target - 1;
          final rowOffset = (toCol - from.col).abs();
          return Coord(toCol, isRed ? from.row - rowOffset : from.row + rowOffset);
        }
      default:
        return null;
    }
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
