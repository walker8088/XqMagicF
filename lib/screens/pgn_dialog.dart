import 'dart:io';

import 'package:flutter/material.dart';
import 'package:xqmagic/services/pgn_service.dart';
import 'package:xqmagic/utils/app_settings.dart';
import 'package:xqmagic/utils/fen.dart';
import 'package:xqmagic/viewmodels/game_viewmodel.dart';

/// PGN 文件打开对话框
/// 提供简易文件浏览器，浏览 .pgn 文件并选择要加载的对局
class PGNOpenDialog extends StatefulWidget {
  final GameViewModel viewModel;

  const PGNOpenDialog({super.key, required this.viewModel});

  @override
  State<PGNOpenDialog> createState() => _PGNOpenDialogState();
}

class _PGNOpenDialogState extends State<PGNOpenDialog> {
  late String _currentPath;
  late TextEditingController _pathController;
  List<FileSystemEntity> _entries = [];
  String? _selectedFile;
  List<GameRecord> _games = [];
  int? _selectedGameIndex;
  bool _loading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    final lastDir = AppSettings.instance.lastOpenedDir;
    _currentPath = (lastDir.isNotEmpty && Directory(lastDir).existsSync())
        ? lastDir
        : Platform.isWindows
        ? Directory.current.path
        : '/';
    _pathController = TextEditingController(text: _currentPath);
    _loadDirectory();
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  void _syncPathController(String path) {
    // 只在路径确实变化时同步，避免用户在文本框中输入时被打断。
    if (_pathController.text != path) {
      _pathController.text = path;
    }
  }

  Future<void> _loadDirectory() async {
    setState(() {
      _loading = true;
      _error = '';
      _entries = [];
      _selectedFile = null;
      _games = [];
      _selectedGameIndex = null;
    });

    final dir = Directory(_currentPath);
    if (!dir.existsSync()) {
      setState(() {
        _loading = false;
        _error = '目录不存在: $_currentPath';
      });
      return;
    }

    try {
      final entities = await dir.list().toList();
      final directories = <FileSystemEntity>[];
      final pgnFiles = <FileSystemEntity>[];

      for (final entity in entities) {
        final name = _entityName(entity);
        if (entity is Directory) {
          directories.add(entity);
        } else if (entity is File && name.toLowerCase().endsWith('.pgn')) {
          pgnFiles.add(entity);
        }
      }

      directories.sort(
        (a, b) => _entityName(
          a,
        ).toLowerCase().compareTo(_entityName(b).toLowerCase()),
      );
      pgnFiles.sort(
        (a, b) => _entityName(
          a,
        ).toLowerCase().compareTo(_entityName(b).toLowerCase()),
      );

      setState(() {
        _entries = [...directories, ...pgnFiles];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '无法读取目录: $e';
      });
    }
  }

  String _entityName(FileSystemEntity entity) {
    return entity.path.split(Platform.pathSeparator).last;
  }

  String _parentPath() {
    final parts = _currentPath.split(Platform.pathSeparator);
    // Handle Windows drive root like "C:\"
    if (parts.length <= 1 ||
        (Platform.isWindows && parts.length == 2 && parts.last.isEmpty)) {
      return _currentPath;
    }
    return parts.sublist(0, parts.length - 1).join(Platform.pathSeparator);
  }

  void _navigateTo(String path) {
    setState(() {
      _currentPath = path;
      _syncPathController(path);
    });
    _loadDirectory();
    AppSettings.instance.setLastOpenedDir(path);
  }

  void _onEntryTap(FileSystemEntity entity) {
    if (entity is Directory) {
      _navigateTo(entity.path);
    } else if (entity is File) {
      _loadFile(entity);
    }
  }

  Future<void> _loadFile(File file) async {
    setState(() {
      _selectedFile = file.path;
      _loading = true;
      _games = [];
      _selectedGameIndex = null;
      _error = '';
    });

    try {
      final pgnService = PGNService();
      final result = pgnService.readFromFile(file.path);

      if (result.games.isEmpty && result.hasErrors) {
        setState(() {
          _loading = false;
          _error = '解析失败: ${result.errors.first.message}';
        });
        return;
      }

      setState(() {
        _games = result.games;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '读取文件失败: $e';
      });
    }
  }

  void _loadSelectedGame() {
    if (_selectedGameIndex == null || _games.isEmpty) return;

    final game = _games[_selectedGameIndex!];
    final targetNode = game.gameTree.current;
    final targetFen = targetNode?.fen ?? (game.fen ?? FenParser.initial);
    final targetPath = targetNode?.getPathFromRoot() ?? [];

    // Load the target position (sets up board, engine, and state correctly)
    widget.viewModel.loadFromFen(targetFen);

    // Replace the tree root with the PGN game's full tree
    widget.viewModel.gameTree.root = game.gameTree.root;

    // Navigate from root to the target position
    widget.viewModel.gameTree.goToStart();
    for (final index in targetPath) {
      widget.viewModel.gameTree.goForward(variationIndex: index);
    }
    // goForward already calls notifyListeners internally

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: SizedBox(
        width: 600,
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.folder_open),
                  const SizedBox(width: 8),
                  const Text(
                    '打开 PGN 文件',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Path bar
            _buildPathBar(theme),
            const Divider(height: 1),
            // File list / Game list
            Expanded(child: _buildContent()),
            // Footer buttons
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildPathBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_upward),
            onPressed: _currentPath == _parentPath()
                ? null
                : () => _navigateTo(_parentPath()),
            tooltip: '上级目录',
            iconSize: 18,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _pathController,
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _navigateTo(value);
                }
              },
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                border: OutlineInputBorder(),
                hintText: '输入路径...',
              ),
            ),
          ),
          const SizedBox(width: 4),
          ElevatedButton.icon(
            onPressed: _loadDirectory,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('刷新'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 8),
            Text(_error, textAlign: TextAlign.center),
          ],
        ),
      );
    }

    // If a file is selected and games are loaded, show game list
    if (_selectedFile != null && _games.isNotEmpty) {
      return _buildGameList();
    }

    // Show file browser
    if (_entries.isEmpty) {
      return const Center(child: Text('此目录为空'));
    }

    return ListView.builder(
      itemCount: _entries.length,
      itemBuilder: (context, index) {
        final entity = _entries[index];
        final isDir = entity is Directory;
        final name = _entityName(entity);

        return ListTile(
          leading: Icon(
            isDir ? Icons.folder : Icons.description,
            color: isDir ? Colors.amber : Colors.blue,
          ),
          title: Text(name),
          subtitle: isDir ? null : Text(_formatPath(entity.path)),
          trailing: isDir
              ? const Icon(Icons.chevron_right, color: Colors.grey)
              : null,
          onTap: () => _onEntryTap(entity),
        );
      },
    );
  }

  Widget _buildGameList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.games, size: 18),
              const SizedBox(width: 8),
              Text(
                '文件 "${_formatPath(_selectedFile!)}" 包含 ${_games.length} 局对弈',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _games.length,
            itemBuilder: (context, index) {
              final game = _games[index];
              final isSelected = _selectedGameIndex == index;
              return ListTile(
                selected: isSelected,
                leading: Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
                title: Text(
                  game.event.isNotEmpty ? game.event : '对局 ${index + 1}',
                ),
                subtitle: Text(
                  [
                    if (game.redPlayer.isNotEmpty) game.redPlayer,
                    if (game.blackPlayer.isNotEmpty) game.blackPlayer,
                  ].join(' vs '),
                ),
                trailing: Text(
                  game.result.symbol,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  setState(() => _selectedGameIndex = index);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final canOpen =
        _selectedFile != null &&
        _games.isNotEmpty &&
        _selectedGameIndex != null;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: canOpen ? _loadSelectedGame : null,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: const Text('加载对局'),
          ),
        ],
      ),
    );
  }

  String _formatPath(String path) {
    // Shorten long paths for display
    if (path.length > 40) {
      return '...${path.substring(path.length - 37)}';
    }
    return path;
  }
}

/// PGN 文件保存对话框
/// 允许编辑 PGN 头部标签并预览/保存当前对局
class PGNSaveDialog extends StatefulWidget {
  final GameViewModel viewModel;

  const PGNSaveDialog({super.key, required this.viewModel});

  @override
  State<PGNSaveDialog> createState() => _PGNSaveDialogState();
}

class _PGNSaveDialogState extends State<PGNSaveDialog> {
  late TextEditingController _eventController;
  late TextEditingController _siteController;
  late TextEditingController _dateController;
  late TextEditingController _roundController;
  late TextEditingController _redPlayerController;
  late TextEditingController _blackPlayerController;
  late TextEditingController _filePathController;

  GameResult _result = GameResult.ongoing;
  String _currentBrowsePath = '';
  List<FileSystemEntity> _browseEntries = [];
  bool _showBrowser = false;
  bool _saving = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _eventController = TextEditingController(text: '象棋对局');
    _siteController = TextEditingController(text: '象棋魔术师');
    _dateController = TextEditingController(
      text:
          '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}',
    );
    _roundController = TextEditingController();
    _redPlayerController = TextEditingController();
    _blackPlayerController = TextEditingController();

    final lastDir = AppSettings.instance.lastOpenedDir;
    _currentBrowsePath = (lastDir.isNotEmpty && Directory(lastDir).existsSync())
        ? lastDir
        : Directory.current.path;

    _filePathController = TextEditingController(
      text: '$_currentBrowsePath${Platform.pathSeparator}game.pgn',
    );

    _loadBrowseDirectory();
  }

  @override
  void dispose() {
    _eventController.dispose();
    _siteController.dispose();
    _dateController.dispose();
    _roundController.dispose();
    _redPlayerController.dispose();
    _blackPlayerController.dispose();
    _filePathController.dispose();
    super.dispose();
  }

  void _loadBrowseDirectory() {
    final dir = Directory(_currentBrowsePath);
    if (!dir.existsSync()) return;

    try {
      final entities = dir.listSync();
      final directories = <FileSystemEntity>[];
      final items = <FileSystemEntity>[];

      for (final entity in entities) {
        if (entity is Directory) {
          directories.add(entity);
        } else {
          items.add(entity);
        }
      }

      directories.sort(
        (a, b) => _entityName(
          a,
        ).toLowerCase().compareTo(_entityName(b).toLowerCase()),
      );
      items.sort(
        (a, b) => _entityName(
          a,
        ).toLowerCase().compareTo(_entityName(b).toLowerCase()),
      );

      setState(() {
        _browseEntries = [...directories, ...items];
      });
    } catch (_) {
      // Ignore listing errors
    }
  }

  String _entityName(FileSystemEntity entity) {
    return entity.path.split(Platform.pathSeparator).last;
  }

  String _parentPath() {
    final parts = _currentBrowsePath.split(Platform.pathSeparator);
    if (parts.length <= 1 ||
        (Platform.isWindows && parts.length == 2 && parts.last.isEmpty)) {
      return _currentBrowsePath;
    }
    return parts.sublist(0, parts.length - 1).join(Platform.pathSeparator);
  }

  void _browseUp() {
    final parent = _parentPath();
    if (parent != _currentBrowsePath) {
      setState(() => _currentBrowsePath = parent);
      _loadBrowseDirectory();
    }
  }

  void _browseNavigate(String path) {
    setState(() => _currentBrowsePath = path);
    _loadBrowseDirectory();
  }

  String _generatePreview() {
    final game = GameRecord(
      event: _eventController.text,
      site: _siteController.text,
      date: _dateController.text,
      round: _roundController.text,
      redPlayer: _redPlayerController.text,
      blackPlayer: _blackPlayerController.text,
      result: _result,
      fen: widget.viewModel.gameTree.root.fen != FenParser.initial
          ? widget.viewModel.gameTree.root.fen
          : null,
      gameTree: widget.viewModel.gameTree,
    );

    return PGNService().writeSingle(game);
  }

  Future<void> _save() async {
    final filePath = _filePathController.text.trim();
    if (filePath.isEmpty) {
      setState(() => _statusMessage = '请输入文件路径');
      return;
    }

    setState(() {
      _saving = true;
      _statusMessage = '';
    });

    try {
      final game = GameRecord(
        event: _eventController.text,
        site: _siteController.text,
        date: _dateController.text,
        round: _roundController.text,
        redPlayer: _redPlayerController.text,
        blackPlayer: _blackPlayerController.text,
        result: _result,
        fen: widget.viewModel.gameTree.root.fen != FenParser.initial
            ? widget.viewModel.gameTree.root.fen
            : null,
        gameTree: widget.viewModel.gameTree,
      );

      final content = PGNService().writeSingle(game);
      final file = File(filePath);
      await file.writeAsString(content);

      // Update last opened directory
      final dirParts = filePath.split(Platform.pathSeparator);
      if (dirParts.length > 1) {
        AppSettings.instance.setLastOpenedDir(
          dirParts.sublist(0, dirParts.length - 1).join(Platform.pathSeparator),
        );
      }

      setState(() {
        _saving = false;
        _statusMessage = '已保存到: $filePath';
      });

      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _statusMessage = '保存失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: 600,
        height: 550,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.save),
                  const SizedBox(width: 8),
                  const Text(
                    '保存 PGN 文件',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: '关闭',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Scrollable content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Header tags
                  _buildHeaderFields(),
                  const SizedBox(height: 16),
                  // File path
                  _buildFilePathField(),
                  const SizedBox(height: 16),
                  // Preview
                  _buildPreview(),
                ],
              ),
            ),
            // Footer
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PGN 头部标签',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _eventController,
          decoration: const InputDecoration(
            labelText: 'Event (赛事)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _siteController,
          decoration: const InputDecoration(
            labelText: 'Site (地点)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _dateController,
                decoration: const InputDecoration(
                  labelText: 'Date (日期)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _roundController,
                decoration: const InputDecoration(
                  labelText: 'Round (轮次)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _redPlayerController,
          decoration: const InputDecoration(
            labelText: '红方 (Red Player)',
            border: OutlineInputBorder(),
            isDense: true,
            prefixIcon: Icon(Icons.circle, color: Colors.red, size: 16),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _blackPlayerController,
          decoration: const InputDecoration(
            labelText: '黑方 (Black Player)',
            border: OutlineInputBorder(),
            isDense: true,
            prefixIcon: Icon(Icons.circle, color: Colors.black, size: 16),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('结果:', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<GameResult>(
                initialValue: _result,
                isDense: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                ),
                items: const [
                  DropdownMenuItem(
                    value: GameResult.ongoing,
                    child: Text('未知 (*)'),
                  ),
                  DropdownMenuItem(
                    value: GameResult.redWin,
                    child: Text('红胜 (1-0)'),
                  ),
                  DropdownMenuItem(
                    value: GameResult.blackWin,
                    child: Text('黑胜 (0-1)'),
                  ),
                  DropdownMenuItem(
                    value: GameResult.draw,
                    child: Text('和棋 (1/2-1/2)'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _result = value);
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilePathField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '文件路径',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _filePathController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: '输入保存路径...',
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => _showBrowser = !_showBrowser);
                if (_showBrowser) {
                  _loadBrowseDirectory();
                }
              },
              icon: const Icon(Icons.folder, size: 16),
              label: const Text('浏览'),
            ),
          ],
        ),
        if (_showBrowser) _buildBrowserPanel(),
      ],
    );
  }

  Widget _buildBrowserPanel() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      constraints: const BoxConstraints(maxHeight: 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Path bar
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_upward, size: 18),
                onPressed: _browseUp,
                tooltip: '上级目录',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _currentBrowsePath,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Divider(height: 8),
          // File list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _browseEntries.length,
              itemBuilder: (context, index) {
                final entity = _browseEntries[index];
                final isDir = entity is Directory;
                final name = _entityName(entity);

                return ListTile(
                  dense: true,
                  leading: Icon(
                    isDir ? Icons.folder : Icons.description,
                    color: isDir ? Colors.amber : Colors.blue,
                    size: 18,
                  ),
                  title: Text(name, style: const TextStyle(fontSize: 13)),
                  trailing: isDir
                      ? const Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: Colors.grey,
                        )
                      : null,
                  onTap: () {
                    if (isDir) {
                      _browseNavigate(entity.path);
                    } else {
                      // Select file: update path field
                      // 必须用当前浏览目录 _currentBrowsePath，
                      // 不能用 _filePathController.text 推算的旧目录，
                      // 否则用户在不同目录间浏览时，选中的文件会被错误地
                      // 拼接到原路径所在的目录。
                      _filePathController.text =
                          '$_currentBrowsePath${Platform.pathSeparator}$name';
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final preview = _generatePreview();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PGN 预览',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          constraints: const BoxConstraints(maxHeight: 150),
          child: SingleChildScrollView(
            child: SelectableText(
              preview.isEmpty ? '(空)' : preview,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          const SizedBox(width: 8),
          _saving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save, size: 16),
                  label: const Text('保存'),
                ),
          if (_statusMessage.isNotEmpty) ...[
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                _statusMessage,
                style: TextStyle(
                  color: _statusMessage.startsWith('已保存')
                      ? Colors.green
                      : Colors.red,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
