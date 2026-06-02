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

  /// 引擎推荐的最佳着法（ICCS 格式）
  String? engineBestMove;

  /// 着法质量标记：★ 好棋, ✓ 一般, ✗ 劣着, ! 佳着, ? 疑问着
  String? moveAnnotation;

  /// 云库推荐的着法（ICCS 格式）
  String? cloudBestMove;

  GameTreeNode? get mainLineChild => _children.isEmpty ? null : _children.first;

  bool get hasChildren => _children.isNotEmpty;

  /// 添加子节点（主变着或变着统一入口）
  GameTreeNode addMove(String fenAfter, MoveRecord move) {
    final child = GameTreeNode(
      fen: fenAfter,
      move: move,
      parent: this,
      variationIndex: _children.length,
    );
    _children.add(child);
    return child;
  }

  /// 添加主变着（兼容旧调用）
  GameTreeNode addMainLine(String fenAfter, MoveRecord move) =>
      addMove(fenAfter, move);

  /// 添加变着（兼容旧调用）
  GameTreeNode addVariation(String fenAfter, MoveRecord move) =>
      addMove(fenAfter, move);

  /// 清空所有子节点（用于在历史位置走新棋时截断后续分支）
  void clearChildren() {
    _children.clear();
  }

  /// 获取到达当前节点的路径索引（迭代实现，O(depth)）
  List<int> getPathFromRoot() {
    final indices = <int>[];
    var node = this;
    while (node.parent != null) {
      indices.add(node.parent!._children.indexOf(node));
      node = node.parent!;
    }
    return indices.reversed.toList();
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
  ///
  /// 根据当前节点状态自动选择 mainLine 或 variation：
  /// - **无 mainLine 续走**（典型：主变着末端的走子）→ 作为 mainLine 添加
  /// - **已有 mainLine 续走**（典型：用户回到历史位置走新棋）→ 作为 variation 追加
  ///
  /// 本方法**不**截断已有分支。如需强制覆盖 mainLine（例如 PGN 解析后
  /// 用户主动重走某步），请显式调用 `_current!.clearChildren()` 后再调用本方法。
  GameTreeNode makeMove(MoveRecord move, String fenAfter) {
    if (_current!.mainLineChild != null) {
      // 已有 mainLine 续走：自动转 variation，避免覆盖既有分支
      return makeVariation(move, fenAfter);
    }
    final child = _current!.addMainLine(fenAfter, move);
    _current = child;
    return child;
  }

  /// 走一步变着：作为当前节点的 variation 子节点追加
  ///
  /// 本方法**不**截断已有分支。多次调用会在同一节点下追加多个 variation。
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
  ///
  /// 从 root 沿主变着线（始终走 `_children[0]`）走到与当前节点相同的深度。
  /// - 若当前已在主变着线上，则原地不动
  /// - 若当前在变着上，则跳到主变着对应深度的节点
  /// - 若主变着比当前变着浅，则走到主变着能到的最深节点
  bool goToMainLine() {
    if (_current == null) return false;
    // 先记录目标深度（_current 即将被改写），再从 root 沿主变着走相应深度
    final targetDepth = _current!.getPathFromRoot().length;
    _current = root;
    for (int i = 0; i < targetDepth; i++) {
      if (_current!.children.isEmpty) break;
      _current = _current!.children[0];
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
