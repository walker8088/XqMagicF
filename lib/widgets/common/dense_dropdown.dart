import 'package:flutter/material.dart';

/// 紧凑型下拉选择器（统一深色主题样式）
///
/// 替换之前散落在 game_screen.dart 和 engine_control_panel.dart 中的重复 `_dropdown` 方法。
/// 统一行为：紧凑布局、深色下拉背景、无下划线、白色文字。
class DenseDropdown<T> extends StatelessWidget {
  const DenseDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
    this.tooltip,
    this.width,
  });

  /// 当前选中值
  final T value;

  /// 所有可选项
  final List<T> items;

  /// 单项的文本表示
  final String Function(T) label;

  /// 选中变化回调
  final void Function(T) onChanged;

  /// 可选 tooltip
  final String? tooltip;

  /// 可选固定宽度；为 null 则自适应内容
  final double? width;

  @override
  Widget build(BuildContext context) {
    final dropdown = DropdownButton<T>(
      value: value,
      isDense: true,
      isExpanded: width != null,
      dropdownColor: const Color(0xFF3E2723),
      underline: const SizedBox.shrink(),
      style: const TextStyle(color: Colors.white, fontSize: 12),
      items: items.map((item) {
        return DropdownMenuItem(value: item, child: Text(label(item)));
      }).toList(),
      onChanged: (v) => v != null ? onChanged(v) : null,
    );

    final wrapped = width != null
        ? SizedBox(width: width, child: dropdown)
        : dropdown;

    if (tooltip == null) return wrapped;
    return Tooltip(message: tooltip!, child: wrapped);
  }
}
