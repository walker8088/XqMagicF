import 'dart:convert';
import 'dart:io';

import 'package:xqmagic/utils/storage_service.dart';

/// 书签数据模型
class Bookmark {
  Bookmark({
    String? id,
    required this.fen,
    required this.name,
    this.comment = '',
    DateTime? createdAt,
    List<String>? tags,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       createdAt = createdAt ?? DateTime.now(),
       tags = tags ?? [];

  final String id;
  final String fen;
  final String name;
  final String comment;
  final DateTime createdAt;
  final List<String> tags;

  Map<String, dynamic> toJson() => {
    'id': id,
    'fen': fen,
    'name': name,
    'comment': comment,
    'createdAt': createdAt.toIso8601String(),
    'tags': tags,
  };

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
    id: json['id'] as String,
    fen: json['fen'] as String,
    name: json['name'] as String,
    comment: json['comment'] as String? ?? '',
    createdAt: DateTime.parse(json['createdAt'] as String),
    tags:
        (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
        [],
  );

  Bookmark copyWith({String? name, String? comment, List<String>? tags}) =>
      Bookmark(
        id: id,
        fen: fen,
        name: name ?? this.name,
        comment: comment ?? this.comment,
        createdAt: createdAt,
        tags: tags ?? this.tags,
      );
}

/// 游戏元数据
class GameMetadata {
  GameMetadata({
    this.event = '',
    this.red = '',
    this.black = '',
    this.date = '',
    this.result = '',
    this.site = '',
    this.round = '',
  });

  final String event;
  final String site;
  final String round;
  final String red;
  final String black;
  final String date;
  final String result;

  Map<String, dynamic> toJson() => {
    'event': event,
    'site': site,
    'round': round,
    'red': red,
    'black': black,
    'date': date,
    'result': result,
  };

  factory GameMetadata.fromJson(Map<String, dynamic> json) => GameMetadata(
    event: json['event'] as String? ?? '',
    site: json['site'] as String? ?? '',
    round: json['round'] as String? ?? '',
    red: json['red'] as String? ?? '',
    black: json['black'] as String? ?? '',
    date: json['date'] as String? ?? '',
    result: json['result'] as String? ?? '',
  );

  GameMetadata copyWith({
    String? event,
    String? site,
    String? round,
    String? red,
    String? black,
    String? date,
    String? result,
  }) => GameMetadata(
    event: event ?? this.event,
    site: site ?? this.site,
    round: round ?? this.round,
    red: red ?? this.red,
    black: black ?? this.black,
    date: date ?? this.date,
    result: result ?? this.result,
  );
}

/// 保存的游戏记录
class SavedGame {
  SavedGame({
    String? id,
    this.filename = '',
    required this.fen,
    required this.moves,
    GameMetadata? metadata,
    DateTime? createdAt,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       metadata = metadata ?? GameMetadata(),
       createdAt = createdAt ?? DateTime.now();

  final String id;
  final String filename;
  final String fen;
  final List<String> moves;
  final GameMetadata metadata;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'filename': filename,
    'fen': fen,
    'moves': moves,
    'metadata': metadata.toJson(),
    'createdAt': createdAt.toIso8601String(),
  };

  factory SavedGame.fromJson(Map<String, dynamic> json) => SavedGame(
    id: json['id'] as String,
    filename: json['filename'] as String? ?? '',
    fen: json['fen'] as String,
    moves: (json['moves'] as List<dynamic>).map((e) => e as String).toList(),
    metadata: json['metadata'] != null
        ? GameMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
        : GameMetadata(),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}

/// 最近打开的文件条目
class RecentFileEntry {
  RecentFileEntry({
    required this.path,
    required this.name,
    DateTime? lastOpened,
  }) : lastOpened = lastOpened ?? DateTime.now();

  final String path;
  final String name;
  final DateTime lastOpened;

  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'lastOpened': lastOpened.toIso8601String(),
  };

  factory RecentFileEntry.fromJson(Map<String, dynamic> json) =>
      RecentFileEntry(
        path: json['path'] as String,
        name: json['name'] as String,
        lastOpened: DateTime.parse(json['lastOpened'] as String),
      );
}

/// 书签服务 - 管理收藏的棋局局面
class BookmarkService {
  BookmarkService._();

  static final BookmarkService _instance = BookmarkService._();
  static BookmarkService get instance => _instance;

  static const String _fileName = 'bookmarks.json';
  final List<Bookmark> _bookmarks = [];
  bool _initialized = false;

  Future<File> get _file => StorageService.getFile(_fileName);

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _load();
    _initialized = true;
  }

  Future<void> _load() async {
    try {
      final file = await _file;
      if (!await file.exists()) return;

      final content = await file.readAsString();
      if (content.trim().isEmpty) return;

      final json = jsonDecode(content) as List<dynamic>;
      _bookmarks.clear();
      for (final item in json) {
        _bookmarks.add(Bookmark.fromJson(item as Map<String, dynamic>));
      }
    } catch (e) {
      // If loading fails, start with empty list
      _bookmarks.clear();
    }
  }

  Future<void> _save() async {
    try {
      final file = await _file;
      final json = _bookmarks.map((b) => b.toJson()).toList();
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(json),
      );
    } catch (e) {
      throw Exception('Failed to save bookmarks: $e');
    }
  }

  /// 添加书签
  Future<Bookmark> addBookmark({
    required String fen,
    required String name,
    String comment = '',
    List<String>? tags,
  }) async {
    await _ensureInitialized();
    final bookmark = Bookmark(
      fen: fen,
      name: name,
      comment: comment,
      tags: tags,
    );
    _bookmarks.add(bookmark);
    await _save();
    return bookmark;
  }

  /// 删除书签
  Future<bool> removeBookmark(String id) async {
    await _ensureInitialized();
    final initialLength = _bookmarks.length;
    _bookmarks.removeWhere((b) => b.id == id);
    if (_bookmarks.length < initialLength) {
      await _save();
      return true;
    }
    return false;
  }

  /// 更新书签
  Future<bool> updateBookmark(
    String id, {
    String? name,
    String? comment,
    List<String>? tags,
  }) async {
    await _ensureInitialized();
    final index = _bookmarks.indexWhere((b) => b.id == id);
    if (index == -1) return false;

    _bookmarks[index] = _bookmarks[index].copyWith(
      name: name,
      comment: comment,
      tags: tags,
    );
    await _save();
    return true;
  }

  /// 获取所有书签
  Future<List<Bookmark>> getAllBookmarks() async {
    await _ensureInitialized();
    return List.unmodifiable(_bookmarks);
  }

  /// 按标签搜索
  Future<List<Bookmark>> searchByTag(String tag) async {
    await _ensureInitialized();
    final lowerTag = tag.toLowerCase();
    return _bookmarks
        .where((b) => b.tags.any((t) => t.toLowerCase().contains(lowerTag)))
        .toList();
  }

  /// 按名称搜索
  Future<List<Bookmark>> searchByName(String query) async {
    await _ensureInitialized();
    final lowerQuery = query.toLowerCase();
    return _bookmarks
        .where(
          (b) =>
              b.name.toLowerCase().contains(lowerQuery) ||
              b.comment.toLowerCase().contains(lowerQuery),
        )
        .toList();
  }

  /// 按 FEN 查找书签
  Future<Bookmark?> findByFen(String fen) async {
    await _ensureInitialized();
    try {
      return _bookmarks.firstWhere((b) => b.fen == fen);
    } catch (_) {
      return null;
    }
  }
}

/// 游戏记录服务 - 管理保存的棋局
class GameRecordService {
  GameRecordService._();

  static final GameRecordService _instance = GameRecordService._();
  static GameRecordService get instance => _instance;

  static const String _fileName = 'saved_games.json';
  final List<SavedGame> _games = [];
  bool _initialized = false;

  Future<File> get _file => StorageService.getFile(_fileName);

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _load();
    _initialized = true;
  }

  Future<void> _load() async {
    try {
      final file = await _file;
      if (!await file.exists()) return;

      final content = await file.readAsString();
      if (content.trim().isEmpty) return;

      final json = jsonDecode(content) as List<dynamic>;
      _games.clear();
      for (final item in json) {
        _games.add(SavedGame.fromJson(item as Map<String, dynamic>));
      }
    } catch (e) {
      _games.clear();
    }
  }

  Future<void> _save() async {
    try {
      final file = await _file;
      final json = _games.map((g) => g.toJson()).toList();
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(json),
      );
    } catch (e) {
      throw Exception('Failed to save games: $e');
    }
  }

  /// 保存游戏
  Future<SavedGame> saveGame({
    required String fen,
    required List<String> moves,
    String filename = '',
    GameMetadata? metadata,
  }) async {
    await _ensureInitialized();
    final game = SavedGame(
      fen: fen,
      moves: moves,
      filename: filename,
      metadata: metadata,
    );
    _games.add(game);
    await _save();
    return game;
  }

  /// 加载游戏
  Future<SavedGame?> loadGame(String id) async {
    await _ensureInitialized();
    try {
      return _games.firstWhere((g) => g.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 更新游戏记录
  Future<bool> updateGame(
    String id, {
    List<String>? moves,
    GameMetadata? metadata,
  }) async {
    await _ensureInitialized();
    final index = _games.indexWhere((g) => g.id == id);
    if (index == -1) return false;

    final existing = _games[index];
    _games[index] = SavedGame(
      id: existing.id,
      filename: existing.filename,
      fen: existing.fen,
      moves: moves ?? existing.moves,
      metadata: metadata ?? existing.metadata,
      createdAt: existing.createdAt,
    );
    await _save();
    return true;
  }

  /// 获取所有游戏
  Future<List<SavedGame>> getAllGames() async {
    await _ensureInitialized();
    return List.unmodifiable(_games);
  }

  /// 删除游戏
  Future<bool> deleteGame(String id) async {
    await _ensureInitialized();
    final initialLength = _games.length;
    _games.removeWhere((g) => g.id == id);
    if (_games.length < initialLength) {
      await _save();
      return true;
    }
    return false;
  }

  /// 按玩家搜索
  Future<List<SavedGame>> searchByPlayer(String playerName) async {
    await _ensureInitialized();
    final lowerName = playerName.toLowerCase();
    return _games
        .where(
          (g) =>
              g.metadata.red.toLowerCase().contains(lowerName) ||
              g.metadata.black.toLowerCase().contains(lowerName),
        )
        .toList();
  }

  /// 按日期范围搜索
  Future<List<SavedGame>> searchByDate({DateTime? from, DateTime? to}) async {
    await _ensureInitialized();
    return _games.where((g) {
      if (from != null && g.createdAt.isBefore(from)) return false;
      if (to != null && g.createdAt.isAfter(to)) return false;
      return true;
    }).toList();
  }

  /// 按比赛事件搜索
  Future<List<SavedGame>> searchByEvent(String event) async {
    await _ensureInitialized();
    final lowerEvent = event.toLowerCase();
    return _games
        .where((g) => g.metadata.event.toLowerCase().contains(lowerEvent))
        .toList();
  }

  /// 获取游戏数量
  int get count => _games.length;
}

/// 最近文件服务 - 跟踪最近打开的文件
class RecentFilesService {
  RecentFilesService._();

  static final RecentFilesService _instance = RecentFilesService._();
  static RecentFilesService get instance => _instance;

  static const String _fileName = 'recent_files.json';
  static const int _maxEntries = 10;

  final List<RecentFileEntry> _entries = [];
  bool _initialized = false;

  Future<File> get _file => StorageService.getFile(_fileName);

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await _load();
    _initialized = true;
  }

  Future<void> _load() async {
    try {
      final file = await _file;
      if (!await file.exists()) return;

      final content = await file.readAsString();
      if (content.trim().isEmpty) return;

      final json = jsonDecode(content) as List<dynamic>;
      _entries.clear();
      for (final item in json) {
        _entries.add(RecentFileEntry.fromJson(item as Map<String, dynamic>));
      }
    } catch (e) {
      _entries.clear();
    }
  }

  Future<void> _save() async {
    try {
      final file = await _file;
      final json = _entries.map((e) => e.toJson()).toList();
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(json),
      );
    } catch (e) {
      throw Exception('Failed to save recent files: $e');
    }
  }

  /// 添加最近文件
  Future<void> addRecentFile(String path) async {
    await _ensureInitialized();

    // Remove existing entry if file was already in the list
    _entries.removeWhere((e) => e.path == path);

    final name = path.split(Platform.pathSeparator).last;
    final entry = RecentFileEntry(path: path, name: name);

    // Add to front
    _entries.insert(0, entry);

    // Trim to max entries
    if (_entries.length > _maxEntries) {
      _entries.removeRange(_maxEntries, _entries.length);
    }

    await _save();
  }

  /// 获取最近文件列表
  Future<List<RecentFileEntry>> getRecentFiles() async {
    await _ensureInitialized();
    return List.unmodifiable(_entries);
  }

  /// 清除所有最近文件
  Future<void> clearRecentFiles() async {
    await _ensureInitialized();
    _entries.clear();
    await _save();
  }

  /// 移除特定的最近文件
  Future<bool> removeRecentFile(String path) async {
    await _ensureInitialized();
    final initialLength = _entries.length;
    _entries.removeWhere((e) => e.path == path);
    if (_entries.length < initialLength) {
      await _save();
      return true;
    }
    return false;
  }
}
