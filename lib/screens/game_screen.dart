import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/game.dart';
import '../models/game_mode.dart';
import '../utils/constants.dart';
import '../viewmodels/game_viewmodel.dart';
import '../widgets/board/chess_board.dart';
import '../widgets/common/analysis_panel.dart';
import '../widgets/common/bookmark_panel.dart';
import '../widgets/common/engine_control_panel.dart';
import '../widgets/common/game_library_panel.dart';
import '../widgets/common/move_history_panel.dart';
import '../widgets/common/opening_browser.dart';
import '../widgets/common/review_panel.dart';
import 'pgn_dialog.dart';
import 'settings_dialog.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameViewModel>(
      builder: (context, vm, _) {
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
                // 顶部栏：模式选择 + 导航
                _buildTopBar(context, vm),
                // 主内容区：左侧面板 + 棋盘 + 右侧面板
                Expanded(child: _buildMainArea(context, vm)),
                // 引擎控制面板
                EngineControlPanel(
                  analysisMode: vm.analysisMode,
                  priorityMode: vm.priorityMode,
                  multiPV: vm.multiPV,
                  isAnalyzing: vm.isAnalyzing,
                  onAnalysisModeChanged: vm.setAnalysisMode,
                  onPriorityModeChanged: vm.setPriorityMode,
                  onMultiPVChanged: vm.setMultiPV,
                  onToggleAnalysis: () => vm.toggleAnalysis(),
                ),
                // 底部状态栏
                _buildStatusBar(vm),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 顶部栏
  Widget _buildTopBar(BuildContext context, GameViewModel vm) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.black.withOpacity(0.3),
      child: Row(
        children: [
          // 应用标题
          const Text(
            '象棋魔术师',
            style: TextStyle(
              color: Color(0xFFF5DEB3),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 16),
          // 模式选择
          DropdownButton<GameMode>(
            value: vm.mode,
            dropdownColor: const Color(0xFF3E2723),
            underline: const SizedBox.shrink(),
            style: const TextStyle(color: Colors.white, fontSize: 13),
            items: GameMode.values
                .map((m) => DropdownMenuItem(value: m, child: Text(m.label)))
                .toList(),
            onChanged: (v) => v != null ? vm.setMode(v) : null,
          ),
          const SizedBox(width: 16),
          const VerticalDivider(color: Colors.white24, width: 1),
          const SizedBox(width: 8),
          // 开局浏览器按钮
          _openBookButton(context, vm),
          const SizedBox(width: 8),
          // 导航按钮
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
          // 左侧面板切换按钮
          _sidePanelButton(
            icon: Icons.bookmark_border,
            activeIcon: Icons.bookmark,
            isActive: vm.isBookmarkPanelVisible,
            tooltip: '收藏',
            onPressed: vm.showBookmarkPanel,
          ),
          _sidePanelButton(
            icon: Icons.folder_open,
            activeIcon: Icons.folder,
            isActive: vm.isLibraryPanelVisible,
            tooltip: '棋谱库',
            onPressed: vm.showLibraryPanel,
          ),
          // 右侧面板切换按钮
          _sidePanelButton(
            icon: vm.isAnalysisPanel ? Icons.analytics : Icons.replay,
            isActive: false,
            tooltip: vm.isAnalysisPanel ? '切换到复盘' : '切换到分析',
            onPressed: vm.toggleRightPanel,
            label: vm.isAnalysisPanel ? '分析' : '复盘',
          ),
          const SizedBox(width: 8),
          const VerticalDivider(color: Colors.white24, width: 1),
          const SizedBox(width: 8),
          // 右侧操作
          IconButton(
            icon: const Icon(Icons.folder_open, size: 18),
            color: Colors.white70,
            tooltip: '打开棋谱',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => PGNOpenDialog(viewModel: vm),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.save, size: 18),
            color: Colors.white70,
            tooltip: '保存棋谱',
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => PGNSaveDialog(viewModel: vm),
              );
            },
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
            onPressed: () => SettingsDialog.show(context),
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

  /// 侧边面板切换按钮
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
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: isActive ? Colors.white.withOpacity(0.1) : null,
        ),
      ),
    );
  }

  /// 主内容区：左侧面板 + 棋盘 + 右侧面板
  Widget _buildMainArea(BuildContext context, GameViewModel vm) {
    return Row(
      children: [
        // 左侧面板（收藏/棋谱库）
        if (vm.leftPanel != 'none')
          SizedBox(width: 260, child: _buildLeftPanel(context, vm)),
        // 棋盘区域
        Expanded(
          flex: 3,
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth * 0.95;
                final availableHeight = constraints.maxHeight * 0.95;
                final cellSizeFromWidth =
                    availableWidth /
                    (AppConstants.boardCols + AppConstants.paddingCells * 2);
                final cellSizeFromHeight =
                    availableHeight /
                    (AppConstants.boardRows + AppConstants.paddingCells * 2);
                final cellSize = cellSizeFromWidth < cellSizeFromHeight
                    ? cellSizeFromWidth
                    : cellSizeFromHeight;
                return ChessBoard(cellSize: cellSize, viewModel: vm);
              },
            ),
          ),
        ),
        // 右侧面板：着法列表 + 分析/复盘
        SizedBox(
          width: 260,
          child: Column(
            children: [
              // 着法列表
              Expanded(
                flex: 2,
                child: MoveHistoryPanel(
                  moves: vm.movesFromRoot,
                  currentIndex: vm.depth - 1,
                  onTapMove: (index) {
                    vm.goToStart();
                    for (int i = 0; i < index; i++) {
                      if (vm.canGoForward) vm.goForward();
                    }
                  },
                ),
              ),
              // 分析面板 或 复盘面板
              Expanded(
                flex: 3,
                child: vm.isAnalysisPanel
                    ? AnalysisPanel(
                        bestMove: vm.engineBestMove ?? vm.bestMoveHint,
                        cloudResult: vm.cloudResult,
                        isAnalyzing:
                            vm.isAnalyzing || vm.engineManager.isThinking,
                        onBestMoveTap: (iccs) {
                          vm.playEngineMove(iccs);
                        },
                      )
                    : const ReviewPanel(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 左侧面板内容
  Widget _buildLeftPanel(BuildContext context, GameViewModel vm) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: Column(
        children: [
          // 面板标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.black.withOpacity(0.2),
            child: Row(
              children: [
                Icon(
                  vm.isBookmarkPanelVisible ? Icons.bookmark : Icons.folder,
                  size: 16,
                  color: const Color(0xFFF5DEB3),
                ),
                const SizedBox(width: 6),
                Text(
                  vm.isBookmarkPanelVisible ? '收藏' : '棋谱库',
                  style: const TextStyle(
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
          // 面板内容
          Expanded(
            child: vm.isBookmarkPanelVisible
                ? const BookmarkPanel()
                : GameLibraryPanel(
                    viewModel: vm,
                    onImportPGN: () {
                      showDialog(
                        context: context,
                        builder: (_) => PGNOpenDialog(viewModel: vm),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// 底部状态栏
  Widget _buildStatusBar(GameViewModel vm) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: Colors.black.withOpacity(0.4),
      child: Row(
        children: [
          // 回合指示
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
          // ECCO 开局信息
          if (vm.currentOpening != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF5DEB3).withOpacity(0.1),
                border: Border.all(
                  color: const Color(0xFFF5DEB3).withOpacity(0.3),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${vm.currentOpening!.eccoCode} ${vm.currentOpening!.eccoName}',
                style: const TextStyle(color: Color(0xFFF5DEB3), fontSize: 11),
              ),
            ),
            const SizedBox(width: 24),
          ],
          // 游戏状态
          if (vm.state == GameState.checkmate)
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
          // 残局挑战状态
          if (vm.mode == GameMode.engineEndGame &&
              vm.currentPuzzle != null) ...[
            const SizedBox(width: 16),
            Text(
              '杀法挑战: ${vm.currentPuzzle!.name}',
              style: const TextStyle(color: Color(0xFFF5DEB3), fontSize: 12),
            ),
            if (vm.puzzleCompleted) ...[
              const SizedBox(width: 8),
              const Icon(Icons.check_circle, color: Colors.green, size: 16),
              const Text(
                '完成!',
                style: TextStyle(color: Colors.green, fontSize: 12),
              ),
            ],
          ],
          const Spacer(),
          // 引擎状态
          if (vm.engineManager.isThinking) ...[
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
          ] else if (vm.engineManager.isReady) ...[
            const SizedBox(width: 8),
            const Icon(Icons.smart_toy, color: Colors.green, size: 14),
            const SizedBox(width: 2),
            Text(
              '引擎就绪',
              style: const TextStyle(color: Colors.green, fontSize: 11),
            ),
          ],
          // 云库缓存信息
          Text(
            '云库缓存: ${vm.cloudDB.cache.size}',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          // 复盘状态
          if (vm.isCloudReviewing) ...[
            const SizedBox(width: 8),
            const Icon(Icons.cloud, color: Colors.blue, size: 12),
            const SizedBox(width: 2),
            Text(
              '云库复盘中... ${(vm.cloudReviewProgress! * 100).toInt()}%',
              style: const TextStyle(color: Colors.blue, fontSize: 11),
            ),
          ],
          if (vm.isEngineReviewing) ...[
            const SizedBox(width: 8),
            const Icon(Icons.smart_toy, color: Colors.blue, size: 12),
            const SizedBox(width: 2),
            Text(
              '引擎复盘中... ${(vm.engineReviewProgress! * 100).toInt()}%',
              style: const TextStyle(color: Colors.blue, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  /// 编辑局面对话框
  void _showEditFenDialog(BuildContext context, GameViewModel vm) {
    final controller = TextEditingController(
      text: vm.gameTree.currentFen ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑局面 FEN'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '输入 FEN 字符串...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              vm.loadFromFen(controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('加载'),
          ),
        ],
      ),
    );
  }

  /// 复制 FEN 到剪贴板
  void _copyFen(BuildContext context, GameViewModel vm) {
    final fen = vm.gameTree.currentFen ?? '';
    Clipboard.setData(ClipboardData(text: fen));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('FEN 已复制到剪贴板'),
        duration: Duration(seconds: 1),
        backgroundColor: Color(0xFF3E2723),
      ),
    );
  }
}
