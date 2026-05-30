import 'package:flutter/foundation.dart';
import 'package:xqmagic/data/endgame_puzzles.dart';
import 'package:xqmagic/models/panel_type.dart';
import 'package:xqmagic/utils/coord.dart';

/// UI 状态管理器：管理游戏界面的交互状态
///
/// 负责管理：
/// - 棋子选择状态（selectedPosition, possibleMoves）
/// - 最佳着法提示
/// - 残局状态（puzzleState）
/// - 面板可见性
class GameStateManager extends ChangeNotifier {
  // ──────────── 棋子选择状态 ────────────

  /// 当前选中位置
  Coord? _selectedPosition;
  Coord? get selectedPosition => _selectedPosition;

  /// 当前可能的走法位置
  List<Coord> _possibleMoves = [];
  List<Coord> get possibleMoves => _possibleMoves;

  /// 最佳着法提示（来自引擎或云库）
  String? _bestMoveHint;
  String? get bestMoveHint => _bestMoveHint;

  // ──────────── 残局状态 ────────────

  /// 当前残局谜题
  EndgamePuzzle? _currentPuzzle;
  EndgamePuzzle? get currentPuzzle => _currentPuzzle;

  /// 残局解题进度
  int _puzzleSolutionIndex = 0;
  int get puzzleSolutionIndex => _puzzleSolutionIndex;

  /// 残局是否完成
  bool _puzzleCompleted = false;
  bool get puzzleCompleted => _puzzleCompleted;

  // ──────────── 面板状态 ────────────

  /// 左侧面板类型
  PanelType _leftPanel = PanelType.cloud;
  PanelType get leftPanel => _leftPanel;

  /// 云库查询结果（用于控制左侧面板显示）
  bool _hasCloudResult = false;
  bool get hasCloudResult => _hasCloudResult;

  // ──────────── 棋子选择方法 ────────────

  /// 选择棋子
  void selectPosition(Coord? position) {
    _selectedPosition = position;
    notifyListeners();
  }

  /// 设置可能的走法
  void setPossibleMoves(List<Coord> moves) {
    _possibleMoves = moves;
    notifyListeners();
  }

  /// 清除选择状态
  void clearSelection() {
    _selectedPosition = null;
    _possibleMoves = [];
    notifyListeners();
  }

  /// 检查指定位置是否被选中
  bool isPositionSelected(Coord pos) => _selectedPosition == pos;

  /// 检查指定位置是否是可能的走法
  bool isPossibleMove(Coord pos) => _possibleMoves.contains(pos);

  // ──────────── 最佳着法提示方法 ────────────

  /// 设置最佳着法提示
  void setBestMoveHint(String? hint) {
    _bestMoveHint = hint;
    notifyListeners();
  }

  /// 清除最佳着法提示
  void clearBestMoveHint() {
    _bestMoveHint = null;
    notifyListeners();
  }

  // ──────────── 残局状态方法 ────────────

  /// 初始化残局
  void initPuzzle(EndgamePuzzle puzzle) {
    _currentPuzzle = puzzle;
    _puzzleSolutionIndex = 0;
    _puzzleCompleted = false;
    notifyListeners();
  }

  /// 推进残局解题进度
  void advancePuzzleSolution() {
    if (_currentPuzzle == null) return;

    _puzzleSolutionIndex++;
    if (_puzzleSolutionIndex >= _currentPuzzle!.solution.length) {
      _puzzleCompleted = true;
    }
    notifyListeners();
  }

  /// 重置残局状态
  void resetPuzzle() {
    _currentPuzzle = null;
    _puzzleSolutionIndex = 0;
    _puzzleCompleted = false;
    notifyListeners();
  }

  /// 检查残局是否完成
  bool isPuzzleCompleted() {
    if (_currentPuzzle == null) return false;
    return _puzzleCompleted;
  }

  // ──────────── 面板状态方法 ────────────

  /// 切换云库面板显示
  void toggleCloudPanel() {
    _leftPanel = _leftPanel == PanelType.cloud
        ? PanelType.none
        : PanelType.cloud;
    notifyListeners();
  }

  /// 隐藏左侧面板
  void hideLeftPanel() {
    _leftPanel = PanelType.none;
    notifyListeners();
  }

  /// 显示云库面板
  void showCloudPanel() {
    _leftPanel = PanelType.cloud;
    notifyListeners();
  }

  /// 检查云库面板是否可见
  bool get isCloudPanelVisible => _leftPanel == PanelType.cloud;

  /// 设置云库查询结果状态
  void setHasCloudResult(bool hasResult) {
    _hasCloudResult = hasResult;
    notifyListeners();
  }

  // ──────────── 状态重置 ────────────

  /// 重置所有 UI 状态
  void reset() {
    _selectedPosition = null;
    _possibleMoves = [];
    _bestMoveHint = null;
    _currentPuzzle = null;
    _puzzleSolutionIndex = 0;
    _puzzleCompleted = false;
    _leftPanel = PanelType.cloud;
    _hasCloudResult = false;
    notifyListeners();
  }
}
