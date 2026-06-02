import 'package:flutter/material.dart';

/// 共享空状态 widget
///
/// 替换之前散落在 bookmark_panel / game_library_panel / opening_browser 等
/// 多个文件中的重复"图标 + 主文字 + 副文字"结构。
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.hint,
    this.iconSize = 40,
    this.iconColor = const Color(0x33FFFFFF), // Colors.white ~20%
  });

  /// 主图标
  final IconData icon;

  /// 主提示文字
  final String message;

  /// 可选副提示文字
  final String? hint;

  /// 图标大小
  final double iconSize;

  /// 图标颜色（默认半透明白）
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: iconColor),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              style: const TextStyle(color: Colors.white38, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// 共享加载中 widget（深色主题）
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    super.key,
    this.size = 36,
    this.color = const Color(0xFFF5DEB3),
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    );
  }
}
