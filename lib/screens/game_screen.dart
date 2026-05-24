import 'package:flutter/material.dart';
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
                // 主内容区：棋盘 + 着法列表
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
            onPressed: () {}, // TODO
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

  /// 主内容区：棋盘 + 着法列表 + 分析面板
  Widget _buildMainArea(BuildContext context, GameViewModel vm) {
    return Row(
      children: [
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
        // 右侧面板：着法列表 + 分析
        SizedBox(
          width: 240,
          child: Column(
            children: [
              // 着法列表
              Expanded(
                flex: 2,
                child: MoveHistoryPanel(
                  moves: vm.movesFromRoot,
                  currentIndex: vm.depth - 1,
                  onTapMove: (index) {
                    // TODO: 跳转到指定着法
                  },
                ),
              ),
              // 分析面板
              Expanded(
                flex: 3,
                child: AnalysisPanel(
                  bestMove: vm.engineBestMove ?? vm.bestMoveHint,
                  cloudResult: vm.cloudResult,
                  isAnalyzing: vm.isAnalyzing || vm.engineManager.isThinking,
                  onBestMoveTap: (iccs) {
                    vm.playEngineMove(iccs);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
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
}
