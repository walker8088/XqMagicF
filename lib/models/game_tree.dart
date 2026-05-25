import 'package:xqmagic/models/move.dart';
import 'package:xqmagic/utils/fen.dart';

/// 棋谱节点：用于存储走子历史、支持变着和回溯
/// 结构为一棵走子树，每个节点代表一个局面
class GameTreeNode {
  GameTreeNode({
    required this.fen,
    this.move,
    this.parent,
    this.variationIndex = 0,
    this.comment = '',
  });

  /// 当前局面的 FEN
  final String fen;

  /// 到达此局面的走法（根节点为 null）
  final MoveRecord? move;

  /// 父节点（根节点为 null）
  GameTreeNode? parent;

  /// 主变着列表
  final List<GameTreeNode> _children = [];

  List<GameTreeNode> get children => List.unmodifiable(_children);

  /// 是否是主变着（第一个子节点）
  bool get isMainLine {
    if (parent == null) return true;
    return parent!._children.isNotEmpty && parent!._children.first == this;
  }

  /// 变着索引
  final int variationIndex;

  /// 注解
  String comment;

  /// 引擎评估分数（单位：厘，正数对红方有利）
  int? evaluation;

  /// 着法质量标记：★ 好棋, ✓ 一般, ✗ 劣着, ! 佳着, ? 疑问着
  String? moveAnnotation;

  /// 云库推荐的着法（ICCS 格式）
  String? cloudBestMove;

  GameTreeNode? get mainLineChild => _children.isEmpty ? null : _children.first;

  bool get hasChildren => _children.isNotEmpty;

  /// 添加主变着
  GameTreeNode addMainLine(String fenAfter, MoveRecord move) {
    final child = GameTreeNode(
      fen: fenAfter,
      move: move,
      parent: this,
      variationIndex: _children.length,
    );
    _children.add(child);
    return child;
  }

  /// 添加变着
  GameTreeNode addVariation(String fenAfter, MoveRecord move) {
    final child = GameTreeNode(
      fen: fenAfter,
      move: move,
      parent: this,
      variationIndex: _children.length,
    );
    _children.add(child);
    return child;
  }

  /// 获取到达当前节点的路径索引
  List<int> getPathFromRoot() {
    if (parent == null) return [];
    final parentPath = parent!.getPathFromRoot();
    parentPath.add(parent!._children.indexOf(this));
    return parentPath;
  }

  /// 提取从根到当前节点的走法序列
  List<MoveRecord> getMovesFromRoot() {
    if (move == null) return [];
    final parentMoves = parent?.getMovesFromRoot() ?? [];
    return [...parentMoves, move!];
  }

}

/// 棋谱树管理：维护整棵走子树
class GameTree {
  /// 根节点（初始局面）
  late GameTreeNode root;

  /// 当前所在节点
  GameTreeNode? _current;

  GameTreeNode? get current => _current;

  /// 是否在主变着线上
  bool get isOnMainLine {
    var node = _current;
    while (node != null && node.parent != null) {
      if (!node.isMainLine) return false;
      node = node.parent;
    }
    return true;
  }

  /// 初始化从 FEN 开始
  void initFromFen(String fen) {
    root = GameTreeNode(fen: fen);
    _current = root;
  }

  /// 初始化标准开局
  void initStandard() {
    initFromFen(FenParser.initial);
  }

  /// 走一步棋并添加到树中
  GameTreeNode makeMove(MoveRecord move, String fenAfter) {
    final child = _current!.addMainLine(fenAfter, move);
    _current = child;
    return child;
  }

  /// 走变着
  GameTreeNode makeVariation(MoveRecord move, String fenAfter) {
    final child = _current!.addVariation(fenAfter, move);
    _current = child;
    return child;
  }

  /// 前进到下一个局面
  bool goForward({int? variationIndex}) {
    if (_current == null || !_current!.hasChildren) return false;
    if (variationIndex != null && variationIndex < _current!.children.length) {
      _current = _current!.children[variationIndex];
    } else {
      _current = _current!.mainLineChild;
    }
    return true;
  }

  /// 后退到上一个局面
  bool goBack() {
    if (_current == null || _current!.parent == null) return false;
    _current = _current!.parent;
    return true;
  }

  /// 回到初始局面
  bool goToStart() {
    _current = root;
    return true;
  }

  /// 回到主变着线
  bool goToMainLine() {
    if (_current == null) return false;
    var node = _current!;
    while (node.parent != null) {
      node = node.parent!;
    }
    // Now navigate to current depth on main line
    final path = _current!.getPathFromRoot();
    _current = root;
    for (int i = 0; i < path.length; i++) {
      if (i < _current!.children.length) {
        _current = _current!.children[0];
      } else {
        break;
      }
    }
    return true;
  }

  /// 从根到当前的节点路径（不含当前节点自身）
  List<GameTreeNode> getPathToCurrent() {
    final path = <GameTreeNode>[];
    var node = _current;
    while (node != null) {
      path.add(node);
      node = node.parent;
    }
    return path.reversed.toList();
  }

  /// 当前局面 FEN
  String? get currentFen => _current?.fen;

  /// 从根到当前的走法序列
  List<MoveRecord> get movesFromRoot => _current?.getMovesFromRoot() ?? [];

  /// 完整主变着线（从根到最深的节点，不受 _current 影响）
  List<MoveRecord> get mainLineMoves {
    final moves = <MoveRecord>[];
    var node = root;
    while (node.mainLineChild != null) {
      node = node.mainLineChild!;
      if (node.move != null) moves.add(node.move!);
    }
    return moves;
  }

  /// 完整主变着线的节点路径（从根到最深的节点）
  List<GameTreeNode> get mainLinePath {
    final path = <GameTreeNode>[root];
    var node = root;
    while (node.mainLineChild != null) {
      node = node.mainLineChild!;
      path.add(node);
    }
    return path;
  }

  /// 当前节点的深度（从根开始的步数）
  int get depth => _current?.getPathFromRoot().length ?? 0;
}
