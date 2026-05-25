import 'package:flutter/material.dart';
import 'package:xqmagic/models/game_mode.dart';

/// 引擎控制面板：分析模式、深度、线程、哈希、MultiPV
class EngineControlPanel extends StatelessWidget {
  const EngineControlPanel({
    super.key,
    required this.analysisMode,
    required this.priorityMode,
    required this.multiPV,
    required this.isAnalyzing,
    required this.onAnalysisModeChanged,
    required this.onPriorityModeChanged,
    required this.onMultiPVChanged,
    required this.onToggleAnalysis,
  });

  final EngineAnalysisMode analysisMode;
  final PriorityMode priorityMode;
  final int multiPV;
  final bool isAnalyzing;
  final void Function(EngineAnalysisMode) onAnalysisModeChanged;
  final void Function(PriorityMode) onPriorityModeChanged;
  final void Function(int) onMultiPVChanged;
  final VoidCallback onToggleAnalysis;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.black.withOpacity(0.3),
      child: Row(
        children: [
          // 分析开关
          ElevatedButton.icon(
            onPressed: onToggleAnalysis,
            icon: Icon(isAnalyzing ? Icons.pause : Icons.play_arrow, size: 16),
            label: Text(isAnalyzing ? '停止' : '分析'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isAnalyzing ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              textStyle: const TextStyle(fontSize: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
          const SizedBox(width: 16),

          // 分析模式
          _dropdown(
            value: analysisMode,
            items: EngineAnalysisMode.values,
            label: (m) => m.label,
            onChanged: onAnalysisModeChanged,
            tooltip: '分析模式',
          ),
          const SizedBox(width: 8),

          // 优先级模式
          _dropdown(
            value: priorityMode,
            items: PriorityMode.values,
            label: (m) => m.label,
            onChanged: onPriorityModeChanged,
            tooltip: '优先级',
          ),
          const SizedBox(width: 8),

          // MultiPV
          const Text(
            'PV:',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 50,
            child: DropdownButton<int>(
              value: multiPV,
              isDense: true,
              dropdownColor: const Color(0xFF3E2723),
              underline: const SizedBox.shrink(),
              style: const TextStyle(color: Colors.white, fontSize: 12),
              items: List.generate(5, (i) => i + 1)
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                  .toList(),
              onChanged: (v) => v != null ? onMultiPVChanged(v) : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required T value,
    required List<T> items,
    required String Function(T) label,
    required void Function(T) onChanged,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: DropdownButton<T>(
        value: value,
        isDense: true,
        dropdownColor: const Color(0xFF3E2723),
        underline: const SizedBox.shrink(),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        items: items.map((item) {
          return DropdownMenuItem(value: item, child: Text(label(item)));
        }).toList(),
        onChanged: (v) => v != null ? onChanged(v) : null,
      ),
    );
  }
}
