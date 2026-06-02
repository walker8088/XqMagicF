import 'package:flutter/material.dart';
import 'package:xqmagic/models/game_mode.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/widgets/common/dense_dropdown.dart';

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
      color: Colors.black.withValues(alpha: 0.3),
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
          DenseDropdown<EngineAnalysisMode>(
            value: analysisMode,
            items: EngineAnalysisMode.values,
            label: (m) => m.label,
            onChanged: onAnalysisModeChanged,
            tooltip: '分析模式',
          ),
          const SizedBox(width: 8),

          // 优先级模式
          DenseDropdown<PriorityMode>(
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
          DenseDropdown<int>(
            value: multiPV,
            items: List.generate(AppConstants.maxMultiPV, (i) => i + 1),
            label: (v) => '$v',
            onChanged: onMultiPVChanged,
            width: 50,
          ),
        ],
      ),
    );
  }
}
