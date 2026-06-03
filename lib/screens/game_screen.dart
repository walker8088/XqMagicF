import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:provider/provider.dart';
import '../models/game_state.dart';
import '../models/game_mode.dart';
import '../models/panel_type.dart';
import '../utils/constants.dart';
import '../viewmodels/game_viewmodel.dart';
import '../widgets/board/chess_board.dart';
import '../widgets/common/analysis_panel.dart';
import '../widgets/common/board_edit_panel.dart';
import '../widgets/common/dense_dropdown.dart';
import '../widgets/common/move_history_panel.dart';
import '../widgets/common/opening_browser.dart';
import 'pgn_dialog.dart';
import 'package:xqmagic/screens/settings_dialog.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late MultiSplitViewController _splitController;
  late MultiSplitViewController _verticalSplitController;

  @override
  void initState() {
    super.initState();
    // 初始显示云库查询左侧面板
    _splitController = MultiSplitViewController(
      areas: [
        Area(
          size: AppConstants.defaultSidePanelWidth,
          min: 0,
          max: AppConstants.maxSidePanelWidth,
        ),
        Area(flex: 1),
        Area(
          size: AppConstants.defaultRightPanelWidth,
          min: AppConstants.minRightPanelWidth,
          max: AppConstants.maxSidePanelWidth,
        ),
      ],
    );
    // 垂直分栏：主内容区和底部面板
    _verticalSplitController = MultiSplitViewController(
      areas: [
        Area(flex: 3, min: 200), // 主内容区（棋盘）
        Area(size: 200, min: 120, max: 400), // 底部引擎面板
      ],
    );
  }

  @override
  void dispose() {
    _splitController.dispose();
    _verticalSplitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameViewModel>(
      builder: (context, vm, _) {
        // 左侧面板状态变化时，在 build 之外异步更新分栏
        // （build 应为纯函数，setter/notify 会触发额外 build）
        final shouldShowLeft =
            vm.leftPanel != PanelType.none || vm.cloudResult != null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _syncLeftPanelVisibility(shouldShowLeft);
        });

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF2E1A0E), Color(0xFF3E2723)],
              ),
            ),
            child: Column(
              children: [
                _buildTopBar(context, vm),
                Expanded(
                  child: MultiSplitViewTheme(
                    data: MultiSplitViewThemeData(
                      dividerPainter: DividerPainters.grooved2(
                        backgroundColor: const Color(0xFF2E1A0E),
                        color: const Color(0xFFF5DEB3).withValues(alpha: 0.5),
                        thickness: 4,
                      ),
                    ),
                    child: MultiSplitView(
                      axis: Axis.vertical,
                      controller: _verticalSplitController,
                      builder: (context, vArea) {
                        switch (vArea.index) {
                          case 0:
                            // 主内容区：水平三栏（左面板、棋盘、右面板）
                            return MultiSplitViewTheme(
                              data: MultiSplitViewThemeData(
                                dividerPainter: DividerPainters.grooved2(
                                  backgroundColor: const Color(0xFF2E1A0E),
                                  color: const Color(
                                    0xFFF5DEB3,
                                  ).withValues(alpha: 0.3),
                                  thickness: 2,
                                ),
                              ),
                              child: MultiSplitView(
                                axis: Axis.horizontal,
                                controller: _splitController,
                                builder: (context, area) {
                                  switch (area.index) {
                                    case 0:
                                      final showLeft =
                                          vm.leftPanel != PanelType.none ||
                                          vm.cloudResult != null;
                                      return showLeft
                                          ? _buildLeftPanel(context, vm)
                                          : const SizedBox.shrink();
                                    case 1:
                                      return _buildBoardArea(context, vm);
                                    case 2:
                                      return _buildRightPanel(context, vm);
                                    default:
                                      return const SizedBox.shrink();
                                  }
                                },
                              ),
                            );
                          case 1:
                            // 底部面板：引擎分析
                            return _buildBottomPanel(context, vm);
                          default:
                            return const SizedBox.shrink();
                        }
                      },
                    ),
                  ),
                ),
                _buildStatusBar(vm),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBoardArea(BuildContext context, GameViewModel vm) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;
        final cellSizeFromWidth =
            availableWidth /
            (AppConstants.boardCols + AppConstants.paddingCells * 2);
        final cellSizeFromHeight =
            availableHeight /
            (AppConstants.boardRows + AppConstants.paddingCells * 2);
        final cellSize = cellSizeFromWidth < cellSizeFromHeight
            ? cellSizeFromWidth
            : cellSizeFromHeight;
        return Center(
          child: ChessBoard(
            cellSize: cellSize,
            renderData: vm.boardRenderData,
            onTap: (coord) => vm.selectPiece(coord),
          ),
        );
      },
    );
  }

  Widget _buildRightPanel(BuildContext context, GameViewModel vm) {
    // 棋盘编辑模式：显示编辑面板
    if (vm.isBoardEditMode) {
      return BoardEditPanel(viewModel: vm);
    }

    return Container(
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: Column(
        children: [
          Expanded(
            child: MoveHistoryPanel(
              moves: vm.mainLineMoves,
              notations: vm.mainLineNotations,
              evaluations: vm.mainLineEvaluations,
              annotations: vm.mainLineAnnotations,
              currentIndex: vm.depth - 1,
              onTapMove: (index) {
                vm.goToStart();
                for (int i = 0; i <= index; i++) {
                  if (vm.canGoForward) vm.goForward();
                }
              },
              onTapRoot: () {
                vm.goToStart();
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 同步左侧面板的可见性到分栏控制器。
  ///
  /// 必须避免在 build 阶段直接修改 [_splitController]，因为：
  /// 1. build 应为纯函数
  /// 2. 同步修改会触发额外 build，可能产生闪烁
  ///
  /// 通过 [addPostFrameCallback] 在当前帧渲染后再更新。
  void _syncLeftPanelVisibility(bool shouldShowLeft) {
    final newLeftSize = shouldShowLeft
        ? AppConstants.defaultSidePanelWidth
        : 0.0;
    final currentAreas = _splitController.areas;
    if (currentAreas.isNotEmpty && currentAreas[0].size == newLeftSize) {
      return; // 无变化
    }
    _splitController.areas = [
      Area(size: newLeftSize, min: 0, max: AppConstants.maxSidePanelWidth),
      Area(flex: 1),
      Area(
        size: AppConstants.defaultRightPanelWidth,
        min: AppConstants.minRightPanelWidth,
        max: AppConstants.maxSidePanelWidth,
      ),
    ];
  }

  Widget _buildTopBar(BuildContext context, GameViewModel vm) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.black.withValues(alpha: 0.3),
      child: Row(
        children: [
          const Text(
            '象棋魔术师',
            style: TextStyle(
              color: Color(0xFFF5DEB3),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 16),
          DenseDropdown<GameMode>(
            value: vm.mode,
            items: GameMode.values,
            label: (m) => m.label,
            onChanged: vm.setMode,
          ),
          const SizedBox(width: 16),
          const VerticalDivider(color: Colors.white24, width: 1),
          const SizedBox(width: 8),
          _openBookButton(context, vm),
          const SizedBox(width: 8),
          _navButton(Icons.skip_previous, vm.goToStart),
          _navButton(Icons.navigate_before, vm.canGoBack ? vm.goBack : null),
          _navButton(
            Icons.navigate_next,
            vm.canGoForward ? vm.goForward : null,
          ),
          const SizedBox(width: 8),
          Text(
            '第 ${vm.depth} 步',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const Spacer(),
          _sidePanelButton(
            icon: Icons.cloud_outlined,
            activeIcon: Icons.cloud,
            isActive: vm.isCloudPanelVisible,
            tooltip: '云库查询',
            onPressed: vm.showCloudPanel,
          ),
          const SizedBox(width: 8),
          const VerticalDivider(color: Colors.white24, width: 1),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.folder_open, size: 18),
            color: Colors.white70,
            tooltip: '打开棋谱',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => PGNOpenDialog(viewModel: vm),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.save, size: 18),
            color: Colors.white70,
            tooltip: '保存棋谱',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => PGNSaveDialog(viewModel: vm),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            color: Colors.white70,
            tooltip: '编辑局面',
            onPressed: () => _showEditFenDialog(context, vm),
          ),
          IconButton(
            icon: const Icon(Icons.content_copy, size: 18),
            color: Colors.white70,
            tooltip: '复制 FEN',
            onPressed: () => _copyFen(context, vm),
          ),
          IconButton(
            icon: const Icon(Icons.settings, size: 18),
            color: Colors.white70,
            tooltip: '设置',
            onPressed: () => SettingsDialog.showAndApply(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            color: Colors.white70,
            tooltip: '新局',
            onPressed: vm.newGame,
          ),
        ],
      ),
    );
  }

  Widget _navButton(IconData icon, VoidCallback? onPressed) {
    return IconButton(
      icon: Icon(icon, size: 18),
      color: onPressed != null ? Colors.white70 : Colors.white24,
      onPressed: onPressed,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(),
    );
  }

  Widget _openBookButton(BuildContext context, GameViewModel vm) {
    return TextButton.icon(
      onPressed: () {
        showDialog(
          context: context,
          builder: (_) => const OpeningBrowserDialog(),
        );
      },
      icon: const Icon(Icons.menu_book, size: 18, color: Color(0xFFF5DEB3)),
      label: const Text(
        '开局',
        style: TextStyle(color: Color(0xFFF5DEB3), fontSize: 13),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  Widget _sidePanelButton({
    required IconData icon,
    IconData? activeIcon,
    required bool isActive,
    required String tooltip,
    required VoidCallback onPressed,
    String? label,
  }) {
    return Tooltip(
      message: tooltip,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: isActive
              ? Colors.white.withValues(alpha: 0.1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? (activeIcon ?? icon) : icon,
              size: 16,
              color: isActive ? const Color(0xFFF5DEB3) : Colors.white70,
            ),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? const Color(0xFFF5DEB3) : Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLeftPanel(BuildContext context, GameViewModel vm) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.black.withValues(alpha: 0.2),
            child: Row(
              children: [
                const Icon(Icons.cloud, size: 16, color: Color(0xFFF5DEB3)),
                const SizedBox(width: 6),
                const Text(
                  '云库查询',
                  style: TextStyle(
                    color: Color(0xFFF5DEB3),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  color: Colors.white54,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: vm.hideLeftPanel,
                ),
              ],
            ),
          ),
          Expanded(
            child: vm.cloudResult != null
                ? CloudMoveList(
                    pieces: vm.currentPieces,
                    moves: vm.cloudResult!.moves,
                    onMoveTap: (iccs) => vm.engineMove(iccs),
                  )
                : vm.isCloudQuerying
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white54,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '云库查询中...',
                          style: TextStyle(fontSize: 12, color: Colors.white54),
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off_outlined,
                            size: 48,
                            color: Colors.white24,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '无云库数据',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// 底部面板：引擎控制（上）+ 引擎输出（下）
  Widget _buildBottomPanel(BuildContext context, GameViewModel vm) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.black.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // === 顶部：引擎控制 ===
          Row(
            children: [
              // 分析模式
              DenseDropdown<EngineAnalysisMode>(
                value: vm.analysisMode,
                items: EngineAnalysisMode.values,
                label: (m) => m.label,
                onChanged: vm.setAnalysisMode,
                tooltip: '分析模式',
              ),
              const SizedBox(width: 8),
              // MultiPV
              const Text(
                'PV:',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(width: 4),
              DenseDropdown<int>(
                value: vm.multiPV,
                items: List.generate(AppConstants.maxMultiPV, (i) => i + 1),
                label: (v) => '$v',
                onChanged: vm.setMultiPV,
                width: 50,
              ),
            ],
          ),
          const SizedBox(height: 6),
          // === 底部：引擎分析结果（实时 PV 线路） ===
          // 用 lastMove 的 boardAfter 和 nextColor，确保显示与分析用的是同一个局面
          Flexible(
            child: LiveAnalysisPanel(
              engineInfos: vm.engineInfos,
              bestMove: vm.engineBestMove,
              board: vm.lastMove?.boardAfter ?? vm.currentPieces,
              activeColor: vm.lastMove?.nextColor ?? vm.currentTurn,
              onBestMoveTap: (iccs) => vm.engineMove(iccs),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar(GameViewModel vm) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.black.withValues(alpha: 0.4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: vm.currentTurn == PieceColor.red
                  ? const Color(0xFFCC0000)
                  : const Color(0xFF1A1A1A),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: vm.currentTurn == PieceColor.red
                      ? const Color(0xFFCC0000)
                      : const Color(0xFF1A1A1A),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            vm.currentTurn == PieceColor.red ? '红方走棋' : '黑方走棋',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(width: 24),
          if (vm.gameState == GameState.checkmate)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '胜负已分',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          if (vm.gameState == GameState.draw)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blueGrey,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '和棋',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          if (vm.mode == GameMode.engineEndGame &&
              vm.currentPuzzleName != null) ...[
            const SizedBox(width: 16),
            Text(
              '杀法挑战: ${vm.currentPuzzleName}',
              style: const TextStyle(color: Color(0xFFF5DEB3), fontSize: 12),
            ),
            if (vm.isPuzzleCompleted) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const Text(
                '完成!',
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
            ],
          ],
          const Spacer(),
          if (vm.isEngineThinking) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '引擎思考中...',
              style: TextStyle(color: Colors.green, fontSize: 11),
            ),
          ] else if (vm.isEngineReady) ...[
            const SizedBox(width: 8),
            const Icon(Icons.smart_toy, color: Colors.green, size: 14),
            const SizedBox(width: 2),
            Text(
              '引擎就绪',
              style: const TextStyle(color: Colors.green, fontSize: 11),
            ),
          ],
          Text(
            '云库缓存: ${vm.cloudCacheSize}',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  void _showEditFenDialog(BuildContext context, GameViewModel vm) {
    // 使用 StatefulWidget 包装对话框以管理 TextEditingController 生命周期
    // 避免以前那种每次打开都泄漏一个 ChangeNotifier 的问题。
    showDialog(
      context: context,
      builder: (ctx) => _EditFenDialog(initialFen: vm.currentFen ?? ''),
    ).then((result) {
      if (result is String && result.trim().isNotEmpty) {
        vm.loadFromFen(result);
      }
    });
  }

  void _copyFen(BuildContext context, GameViewModel vm) async {
    final fen = vm.currentFen ?? '';
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Clipboard.setData(ClipboardData(text: fen));
      messenger.showSnackBar(
        const SnackBar(
          content: Text('FEN 已复制到剪贴板'),
          duration: Duration(seconds: 1),
          backgroundColor: Color(0xFF3E2723),
        ),
      );
    } on Exception {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('复制失败'),
          duration: Duration(seconds: 1),
          backgroundColor: Color(0xFF3E2723),
        ),
      );
    }
  }
}

/// FEN 编辑对话框。独立 StatefulWidget 负责释放 [TextEditingController]。
class _EditFenDialog extends StatefulWidget {
  const _EditFenDialog({required this.initialFen});

  final String initialFen;

  @override
  State<_EditFenDialog> createState() => _EditFenDialogState();
}

class _EditFenDialogState extends State<_EditFenDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialFen);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑局面 FEN'),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: '输入 FEN 字符串...',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('加载'),
        ),
      ],
    );
  }
}
