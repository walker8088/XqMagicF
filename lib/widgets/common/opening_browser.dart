import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:xqmagic/services/opening_book.dart';
import 'package:xqmagic/viewmodels/game_viewmodel.dart';

/// 开局浏览器对话框
/// 显示所有 ECCO 开局分类，支持搜索和选择开局
class OpeningBrowserDialog extends StatefulWidget {
  const OpeningBrowserDialog({super.key});

  @override
  State<OpeningBrowserDialog> createState() => _OpeningBrowserDialogState();
}

class _OpeningBrowserDialogState extends State<OpeningBrowserDialog> {
  final _searchController = TextEditingController();
  String _searchKeyword = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<OpeningInfo> get _filteredOpenings {
    if (_searchKeyword.isEmpty) {
      return OpeningBookService.instance.getAllOpenings();
    }
    return OpeningBookService.instance.searchByName(_searchKeyword);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2E1A0E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF3E2723),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.menu_book, color: Color(0xFFF5DEB3)),
                  const SizedBox(width: 8),
                  const Text(
                    'ECCO 开局库',
                    style: TextStyle(
                      color: Color(0xFFF5DEB3),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // 搜索栏
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: '搜索开局名称或 ECCO 代码...',
                  hintStyle: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFFF5DEB3),
                    size: 20,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  suffixIcon: _searchKeyword.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear,
                            size: 18,
                            color: Colors.white54,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchKeyword = '');
                          },
                        )
                      : null,
                ),
                onChanged: (v) => setState(() => _searchKeyword = v),
              ),
            ),
            // 开局列表
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: _filteredOpenings.length,
                itemBuilder: (context, index) {
                  final opening = _filteredOpenings[index];
                  return _OpeningTile(opening: opening);
                },
              ),
            ),
            // 底部统计
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '共 ${_filteredOpenings.length} 个开局',
                style: const TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个开局条目
class _OpeningTile extends StatelessWidget {
  final OpeningInfo opening;

  const _OpeningTile({required this.opening});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _loadOpening(context),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ECCO 代码徽章
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5DEB3).withValues(alpha: 0.15),
                  border: Border.all(
                    color: const Color(0xFFF5DEB3).withValues(alpha: 0.4),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  opening.eccoCode ?? '?',
                  style: const TextStyle(
                    color: Color(0xFFF5DEB3),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 开局名称
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opening.eccoName ?? '未知开局',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${opening.moves.length} 种常见走法',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _loadOpening(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _OpeningDetailDialog(opening: opening),
    );
  }
}

/// 开局详情对话框
class _OpeningDetailDialog extends StatelessWidget {
  final OpeningInfo opening;

  const _OpeningDetailDialog({required this.opening});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2E1A0E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF3E2723),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5DEB3).withValues(alpha: 0.2),
                      border: Border.all(
                        color: const Color(0xFFF5DEB3).withValues(alpha: 0.5),
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      opening.eccoCode ?? '?',
                      style: const TextStyle(
                        color: Color(0xFFF5DEB3),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      opening.eccoName ?? '未知开局',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // 常见走法列表
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '常见走法 (${opening.moves.length})',
                  style: const TextStyle(
                    color: Color(0xFFF5DEB3),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: opening.moves.length,
                itemBuilder: (context, index) {
                  final move = opening.moves[index];
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                    title: Text(
                      move.chineseName,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    subtitle: Text(
                      'ICCS: ${move.iccs} · 使用率: ${(move.frequency * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    onTap: () => _playMove(context, move),
                  );
                },
              ),
            ),
            // 加载开局按钮
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFF5DEB3)),
                      ),
                      child: const Text(
                        '关闭',
                        style: TextStyle(color: Color(0xFFF5DEB3)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _loadStartingPosition(context);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5DEB3),
                        foregroundColor: const Color(0xFF2E1A0E),
                      ),
                      child: const Text('加载开局'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 走一步开局着法
  void _playMove(BuildContext context, OpeningMove move) {
    final vm = context.read<GameViewModel>();
    // 尝试执行该着法
    vm.engineMove(move.iccs);
    Navigator.of(context).pop(); // 关闭详情
    Navigator.of(context).pop(); // 关闭浏览器
  }

  /// 加载开局起始局面（回到初始并开始走开局着法）
  void _loadStartingPosition(BuildContext context) {
    final vm = context.read<GameViewModel>();
    vm.goToStart();
    if (opening.moves.isNotEmpty) {
      // 走到第一个推荐着法
      vm.engineMove(opening.moves.first.iccs);
    }
  }
}
