import 'package:flutter/material.dart';
import 'package:xqmagic/widgets/common/cloud_review_panel.dart';
import 'package:xqmagic/widgets/common/engine_review_panel.dart';

/// 复盘面板：在云库复盘和引擎复盘之间切换
class ReviewPanel extends StatefulWidget {
  const ReviewPanel({super.key});

  @override
  State<ReviewPanel> createState() => _ReviewPanelState();
}

class _ReviewPanelState extends State<ReviewPanel> {
  ReviewTab _currentTab = ReviewTab.cloud;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTabBar(),
        Expanded(
          child: _currentTab == ReviewTab.cloud
              ? const CloudReviewPanel()
              : const EngineReviewPanel(),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          _tabButton(ReviewTab.cloud, '云库', Icons.cloud),
          const SizedBox(width: 4),
          _tabButton(ReviewTab.engine, '引擎', Icons.smart_toy),
        ],
      ),
    );
  }

  Widget _tabButton(ReviewTab tab, String label, IconData icon) {
    final isSelected = _currentTab == tab;
    return Expanded(
      child: TextButton.icon(
        onPressed: () => setState(() => _currentTab = tab),
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 11)),
        style: TextButton.styleFrom(
          backgroundColor: isSelected
              ? Colors.white.withOpacity(0.1)
              : Colors.transparent,
          foregroundColor: isSelected
              ? const Color(0xFFF5DEB3)
              : Colors.white54,
          padding: const EdgeInsets.symmetric(vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

enum ReviewTab { cloud, engine }
