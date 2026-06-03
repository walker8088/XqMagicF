import 'package:flutter/material.dart';
import 'package:xqmagic/services/local_db.dart';
import 'package:xqmagic/utils/app_logger.dart';
import 'package:xqmagic/viewmodels/game_viewmodel.dart';
import 'package:xqmagic/widgets/common/empty_state.dart';
import 'package:provider/provider.dart';

/// 书签/收藏面板：管理收藏的棋局局面和最近打开的文件
class BookmarkPanel extends StatefulWidget {
  const BookmarkPanel({super.key, this.onOpenFile});

  /// 当用户点击最近文件时回调，返回文件路径
  final void Function(String path)? onOpenFile;

  @override
  State<BookmarkPanel> createState() => _BookmarkPanelState();
}

class _BookmarkPanelState extends State<BookmarkPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // 书签数据
  List<Bookmark> _bookmarks = [];
  bool _bookmarksLoading = true;

  // 最近文件数据
  List<RecentFileEntry> _recentFiles = [];
  bool _recentFilesLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBookmarks();
    _loadRecentFiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBookmarks() async {
    if (!mounted) return;
    setState(() => _bookmarksLoading = true);
    try {
      final bookmarks = await BookmarkService.instance.getAllBookmarks();
      if (mounted) {
        setState(() {
          _bookmarks = bookmarks;
          _bookmarksLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _bookmarksLoading = false);
      }
    }
  }

  Future<void> _loadRecentFiles() async {
    if (!mounted) return;
    setState(() => _recentFilesLoading = true);
    try {
      final files = await RecentFilesService.instance.getRecentFiles();
      if (mounted) {
        setState(() {
          _recentFiles = files;
          _recentFilesLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _recentFilesLoading = false);
      }
    }
  }

  List<Bookmark> get _filteredBookmarks {
    if (_searchQuery.isEmpty) return _bookmarks;
    final query = _searchQuery.toLowerCase();
    return _bookmarks.where((b) {
      return b.name.toLowerCase().contains(query) ||
          b.comment.toLowerCase().contains(query) ||
          b.tags.any((t) => t.toLowerCase().contains(query));
    }).toList();
  }

  Future<void> _addBookmark() async {
    final vm = context.read<GameViewModel>();
    final fen = vm.currentFen;
    if (fen == null) return;

    final moveCount = vm.depth;

    // 使用子 widget 管理 TextEditingController 生命周期，
    // 避免以前关闭对话框后 controller 仍然存活 → ChangeNotifier 泄漏。
    final result = await showDialog<_AddBookmarkResult>(
      context: context,
      builder: (ctx) =>
          _AddBookmarkDialog(moveCount: moveCount, fenPreview: fen),
    );

    if (result == null) return;
    if (result.name.isEmpty) return;

    try {
      await BookmarkService.instance.addBookmark(
        fen: fen,
        name: result.name,
        comment: result.comment,
        tags: result.tags,
      );
      await _loadBookmarks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('已添加到收藏'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e, s) {
      AppLogger.error('BookmarkPanel', '添加收藏失败: $e\n$s');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('收藏失败，请重试')));
      }
    }
  }

  Future<void> _deleteBookmark(String id, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除收藏'),
        content: Text('确定要删除「$name」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await BookmarkService.instance.removeBookmark(id);
    await _loadBookmarks();
  }

  Future<void> _clearRecentFiles() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除历史'),
        content: const Text('确定要清除所有最近打开的文件记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await RecentFilesService.instance.clearRecentFiles();
    await _loadRecentFiles();
  }

  Future<void> _removeRecentFile(String path, String name) async {
    await RecentFilesService.instance.removeRecentFile(path);
    await _loadRecentFiles();
  }

  void _loadBookmark(Bookmark bookmark) {
    final vm = context.read<GameViewModel>();
    vm.loadFromFen(bookmark.fen);
  }

  void _openRecentFile(RecentFileEntry entry) {
    widget.onOpenFile?.call(entry.path);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _fenPreview(String fen) {
    // 只显示棋盘部分（FEN 的第一段），截断过长内容
    final boardPart = fen.split(' ').firstOrNull ?? fen;
    if (boardPart.length > 40) {
      return '${boardPart.substring(0, 40)}...';
    }
    return boardPart;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        border: Border(
          left: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标签栏
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFF5DEB3),
            labelColor: const Color(0xFFF5DEB3),
            unselectedLabelColor: Colors.white54,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(text: '收藏'),
              Tab(text: '最近'),
            ],
          ),
          // 标签内容
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildBookmarksTab(), _buildRecentFilesTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookmarksTab() {
    return Column(
      children: [
        // 搜索栏 + 添加按钮
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: '搜索名称或标签',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 18,
                      color: Colors.white54,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                icon: const Icon(Icons.bookmark_add, size: 18),
                onPressed: _addBookmark,
                tooltip: '添加收藏',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(
                    0xFFF5DEB3,
                  ).withValues(alpha: 0.2),
                  foregroundColor: const Color(0xFFF5DEB3),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(36, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        // 书签列表
        Expanded(
          child: _bookmarksLoading
              ? const LoadingIndicator()
              : _filteredBookmarks.isEmpty
              ? EmptyState(
                  icon: Icons.bookmark_border,
                  message: _searchQuery.isEmpty ? '暂无收藏' : '没有找到匹配的结果',
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _filteredBookmarks.length,
                  itemBuilder: (context, index) {
                    final bookmark = _filteredBookmarks[index];
                    return _buildBookmarkTile(bookmark);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBookmarkTile(Bookmark bookmark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _loadBookmark(bookmark),
          onLongPress: () => _deleteBookmark(bookmark.id, bookmark.name),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 名称 + 日期
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        bookmark.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatDate(bookmark.createdAt),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // FEN 预览
                Text(
                  _fenPreview(bookmark.fen),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // 备注
                if (bookmark.comment.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    bookmark.comment,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // 标签
                if (bookmark.tags.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: bookmark.tags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFF5DEB3,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(
                            color: Color(0xFFF5DEB3),
                            fontSize: 10,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentFilesTab() {
    return Column(
      children: [
        // 清除按钮
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.delete_sweep, size: 16),
                label: const Text('清除', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white54,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _recentFiles.isEmpty ? null : _clearRecentFiles,
              ),
            ],
          ),
        ),
        // 最近文件列表
        Expanded(
          child: _recentFilesLoading
              ? const LoadingIndicator()
              : _recentFiles.isEmpty
              ? const EmptyState(icon: Icons.history, message: '暂无最近文件')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _recentFiles.length,
                  itemBuilder: (context, index) {
                    final entry = _recentFiles[index];
                    return _buildRecentFileTile(entry);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRecentFileTile(RecentFileEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => _openRecentFile(entry),
          onLongPress: () => _removeRecentFile(entry.path, entry.name),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 文件名 + 日期
                Row(
                  children: [
                    Icon(
                      Icons.insert_drive_file,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        entry.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatDate(entry.lastOpened),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                // 路径
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 22),
                  child: Text(
                    entry.path,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 添加收藏对话框返回的结果。
class _AddBookmarkResult {
  const _AddBookmarkResult({
    required this.name,
    required this.comment,
    required this.tags,
  });

  final String name;
  final String comment;
  final List<String> tags;
}

/// 添加收藏对话框。独立 StatefulWidget 以正确释放 3 个 TextEditingController。
class _AddBookmarkDialog extends StatefulWidget {
  const _AddBookmarkDialog({required this.moveCount, required this.fenPreview});

  final int moveCount;
  final String fenPreview;

  @override
  State<_AddBookmarkDialog> createState() => _AddBookmarkDialogState();
}

class _AddBookmarkDialogState extends State<_AddBookmarkDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _commentController;
  late final TextEditingController _tagsController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: '局面 #${widget.moveCount}');
    _commentController = TextEditingController();
    _tagsController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _commentController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fenPreview = widget.fenPreview;
    return AlertDialog(
      title: const Text('添加收藏'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '名称',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: '备注',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: '标签',
                hintText: '用逗号分隔，如：开局, 中局',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'FEN: ${fenPreview.length > 50 ? '${fenPreview.substring(0, 50)}...' : fenPreview}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final tags = _tagsController.text
                .split(',')
                .map((t) => t.trim())
                .where((t) => t.isNotEmpty)
                .toList();
            Navigator.pop(
              context,
              _AddBookmarkResult(
                name: _nameController.text.trim(),
                comment: _commentController.text.trim(),
                tags: tags,
              ),
            );
          },
          child: const Text('收藏'),
        ),
      ],
    );
  }
}
