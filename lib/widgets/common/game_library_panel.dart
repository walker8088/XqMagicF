import 'package:flutter/material.dart';
import 'package:xqmagic/services/local_db.dart';
import 'package:xqmagic/viewmodels/game_viewmodel.dart';

/// 棋库面板：浏览、搜索、加载已保存的棋局
class GameLibraryPanel extends StatefulWidget {
  final GameViewModel viewModel;
  final VoidCallback onImportPGN;

  const GameLibraryPanel({
    super.key,
    required this.viewModel,
    required this.onImportPGN,
  });

  @override
  State<GameLibraryPanel> createState() => _GameLibraryPanelState();
}

class _GameLibraryPanelState extends State<GameLibraryPanel> {
  final GameRecordService _db = GameRecordService.instance;
  final TextEditingController _searchController = TextEditingController();
  String _filter = 'all'; // all, master, classic, personal
  List<SavedGame> _games = [];
  bool _loading = true;
  SavedGame? _loadingGame;

  @override
  void initState() {
    super.initState();
    _loadGames();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadGames() async {
    setState(() => _loading = true);
    try {
      final allGames = await _db.getAllGames();
      _applyFilterAndSearch(allGames);
    } catch (_) {
      _games = [];
    } finally {
      setState(() => _loading = false);
    }
  }

  void _onSearchChanged() {
    _applyCurrentFilters();
  }

  void _applyCurrentFilters() {
    _db.getAllGames().then((allGames) {
      _applyFilterAndSearch(allGames);
    });
  }

  void _applyFilterAndSearch(List<SavedGame> allGames) {
    var filtered = allGames;

    // 先按分类过滤
    switch (_filter) {
      case 'master':
        filtered = filtered.where((g) {
          final event = g.metadata.event.toLowerCase();
          return event.contains('大师') ||
              event.contains('特级大师') ||
              event.contains('全国');
        }).toList();
      case 'classic':
        filtered = filtered.where((g) {
          final event = g.metadata.event.toLowerCase();
          return event.contains('古') ||
              event.contains('经典') ||
              event.contains('谱') ||
              event.contains('名局');
        }).toList();
      case 'personal':
        filtered = filtered.where((g) => g.metadata.event.isEmpty).toList();
    }

    // 再按搜索关键词过滤
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((g) {
        final event = g.metadata.event.toLowerCase();
        final red = g.metadata.red.toLowerCase();
        final black = g.metadata.black.toLowerCase();
        final date = g.metadata.date.toLowerCase();
        final filename = g.filename.toLowerCase();
        return event.contains(query) ||
            red.contains(query) ||
            black.contains(query) ||
            date.contains(query) ||
            filename.contains(query);
      }).toList();
    }

    if (mounted) {
      setState(() => _games = filtered);
    }
  }

  void _onFilterChanged(String? value) {
    if (value == null) return;
    setState(() => _filter = value);
    _applyCurrentFilters();
  }

  Future<void> _loadGame(SavedGame game) async {
    if (_loadingGame != null) return;
    setState(() => _loadingGame = game);

    try {
      // 1. 用 FEN 初始化棋盘
      final fen = game.fen.isNotEmpty
          ? game.fen
          : 'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR r - - 0 1';
      widget.viewModel.loadFromFen(fen);

      // 2. 重演所有着法
      for (final iccs in game.moves) {
        if (iccs.isNotEmpty && iccs.length == 4) {
          widget.viewModel.playEngineMove(iccs);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已加载: ${_gameTitle(game)}'),
            duration: const Duration(seconds: 1),
            backgroundColor: const Color(0xFF3D3D3D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('加载失败: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loadingGame = null);
      }
    }
  }

  Future<void> _deleteGame(SavedGame game) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text('删除棋局', style: TextStyle(color: Colors.white)),
        content: Text(
          '确定要删除「${_gameTitle(game)}」吗？',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _db.deleteGame(game.id);
      _loadGames();
    }
  }

  String _gameTitle(SavedGame game) {
    if (game.metadata.event.isNotEmpty) return game.metadata.event;
    if (game.filename.isNotEmpty) return game.filename;
    return '未命名棋局';
  }

  String _resultLabel(String result) {
    final lower = result.toLowerCase();
    if (lower.contains('红') || lower.contains('1') || lower == '1-0') {
      return '红胜';
    }
    if (lower.contains('黑') || lower.contains('2') || lower == '0-1') {
      return '黑胜';
    }
    if (lower.contains('和') || lower.contains('平') || lower == '1/2') {
      return '和棋';
    }
    return '';
  }

  Color _resultColor(String label) {
    switch (label) {
      case '红胜':
        return const Color(0xFFCC4444);
      case '黑胜':
        return Colors.white70;
      case '和棋':
        return const Color(0xFFF5DEB3);
      default:
        return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        border: Border(left: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildSearchBar(),
          _buildFilterRow(),
          Expanded(child: _buildGameList()),
          _buildImportButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.library_books, size: 18, color: Colors.white70),
          const SizedBox(width: 8),
          const Text(
            '棋库',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Text(
            '${_games.length} 局',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: '搜索赛事、棋手、日期...',
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
          prefixIcon: const Icon(Icons.search, size: 18, color: Colors.white54),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFFF5DEB3)),
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          isDense: true,
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    size: 16,
                    color: Colors.white54,
                  ),
                  onPressed: () => _searchController.clear(),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          const Text(
            '分类:',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _filter,
                isDense: true,
                isExpanded: true,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                dropdownColor: const Color(0xFF2D2D2D),
                icon: const Icon(
                  Icons.arrow_drop_down,
                  color: Colors.white54,
                  size: 18,
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('全部')),
                  DropdownMenuItem(value: 'master', child: Text('大师对局')),
                  DropdownMenuItem(value: 'classic', child: Text('古典名局')),
                  DropdownMenuItem(value: 'personal', child: Text('个人收藏')),
                ],
                onChanged: _onFilterChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameList() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF5DEB3)),
        ),
      );
    }

    if (_games.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox, size: 40, color: Colors.white24),
            const SizedBox(height: 8),
            const Text(
              '暂无棋局',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              '点击底部按钮导入 PGN 棋谱',
              style: TextStyle(color: Colors.white24, fontSize: 11),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: _games.length,
      itemBuilder: (context, index) {
        final game = _games[index];
        final isLoading = _loadingGame?.id == game.id;
        return _buildGameCard(game, isLoading);
      },
    );
  }

  Widget _buildGameCard(SavedGame game, bool isLoading) {
    final title = _gameTitle(game);
    final red = game.metadata.red.isNotEmpty ? game.metadata.red : '红方';
    final black = game.metadata.black.isNotEmpty ? game.metadata.black : '黑方';
    final resultLabel = _resultLabel(game.metadata.result);
    final date = game.metadata.date.isNotEmpty
        ? game.metadata.date
        : _formatDate(game.createdAt);
    final moveCount = game.moves.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: isLoading ? null : () => _loadGame(game),
        onLongPress: () => _deleteGame(game),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isLoading
                ? const Color(0xFFF5DEB3).withOpacity(0.15)
                : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isLoading
                  ? const Color(0xFFF5DEB3).withOpacity(0.4)
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (resultLabel.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _resultColor(resultLabel).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _resultColor(resultLabel).withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        resultLabel,
                        style: TextStyle(
                          color: _resultColor(resultLabel),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              // 棋手行
              Row(
                children: [
                  Text(
                    red,
                    style: const TextStyle(
                      color: Color(0xFFCC6666),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    ' vs ',
                    style: TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  Expanded(
                    child: Text(
                      black,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // 日期与步数行
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 12,
                    color: Colors.white.withOpacity(0.4),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    date,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.directions_run,
                    size: 12,
                    color: Colors.white.withOpacity(0.4),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$moveCount 步',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  if (isLoading)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFFF5DEB3).withOpacity(0.7),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImportButton() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: widget.onImportPGN,
          icon: const Icon(Icons.upload_file, size: 16),
          label: const Text('导入棋谱'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFF5DEB3),
            side: const BorderSide(color: Color(0xFFF5DEB3)),
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${_pad(dt.month)}-${_pad(dt.day)}';
  }

  String _pad(int n) => n.toString().padLeft(2, '0');
}
