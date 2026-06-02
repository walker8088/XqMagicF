import 'package:flutter/material.dart';

/// 导航工具栏：前进、后退、回到开始等
class NavigationToolbar extends StatelessWidget {
  const NavigationToolbar({
    super.key,
    required this.canGoBack,
    required this.canGoForward,
    required this.onGoBack,
    required this.onGoForward,
    required this.onGoToStart,
    required this.onGoToEnd,
    required this.onNewGame,
    this.depth = 0,
  });

  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onGoBack;
  final VoidCallback onGoForward;
  final VoidCallback onGoToStart;
  final VoidCallback onGoToEnd;
  final VoidCallback onNewGame;
  final int depth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.black.withValues(alpha: 0.2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _navButton(Icons.skip_previous, '回到开始', onGoToStart),
          _navButton(Icons.navigate_before, '后退', canGoBack ? onGoBack : null),
          _navButton(
            Icons.navigate_next,
            '前进',
            canGoForward ? onGoForward : null,
          ),
          _navButton(Icons.skip_next, '走到最后', onGoToEnd),
          const SizedBox(width: 16),
          Text(
            '第 $depth 步',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 16),
          _navButton(Icons.refresh, '新局', onNewGame),
        ],
      ),
    );
  }

  Widget _navButton(IconData icon, String tooltip, VoidCallback? onPressed) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 20),
        color: onPressed != null ? Colors.white70 : Colors.white24,
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
      ),
    );
  }
}

/// 模式选择器
class ModeSelector extends StatelessWidget {
  const ModeSelector({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  final String currentMode;
  final void Function(String) onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: Colors.black.withValues(alpha: 0.2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '模式:',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 4),
          DropdownButton<String>(
            value: currentMode,
            dropdownColor: const Color(0xFF3E2723),
            underline: const SizedBox.shrink(),
            style: const TextStyle(color: Colors.white, fontSize: 12),
            items: const [
              DropdownMenuItem(value: 'Free', child: Text('自由练习')),
              DropdownMenuItem(value: 'EngineFight', child: Text('人机对战')),
              DropdownMenuItem(value: 'EngineEndGame', child: Text('杀法挑战')),
              DropdownMenuItem(value: 'EngineOnline', child: Text('连线分析')),
            ],
            onChanged: (v) => v != null ? onModeChanged(v) : null,
          ),
        ],
      ),
    );
  }
}
