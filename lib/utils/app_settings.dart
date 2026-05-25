import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 应用设置服务：持久化用户偏好
/// 使用 JSON 文件存储设置
class AppSettings {
  AppSettings._();

  static AppSettings? _instance;
  static AppSettings get instance => _instance ??= AppSettings._();

  Map<String, dynamic> _data = {};
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/magicf_settings.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        _data = _parseJsonSafe(content);
      }
    } catch (_) {
      _data = {};
    }
    _initialized = true;
  }

  Map<String, dynamic> _parseJsonSafe(String content) {
    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _save() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/magicf_settings.json');
      await file.writeAsString(jsonEncode(_data));
    } catch (_) {
      // Ignore save errors
    }
  }

  T get<T>(String key, T defaultValue) {
    if (!_data.containsKey(key)) return defaultValue;
    final value = _data[key];
    if (value is T) return value;
    // Try to convert
    if (T == int && value is num) return value.toInt() as T;
    if (T == double && value is num) return value.toDouble() as T;
    if (T == String) return value.toString() as T;
    return defaultValue;
  }

  Future<void> set<T>(String key, T value) async {
    _data[key] = value;
    await _save();
  }

  // === 便捷方法 ===

  double get boardScale => get<double>('board_scale', 1.0);
  Future<void> setBoardScale(double scale) => set('board_scale', scale);

  String get skinName => get<String>('skin_name', 'default');
  Future<void> setSkinName(String name) => set('skin_name', name);

  int get engineDepth => get<int>('engine_depth', 15);
  Future<void> setEngineDepth(int depth) => set('engine_depth', depth);

  int get engineThreads => get<int>('engine_threads', 2);
  Future<void> setEngineThreads(int threads) => set('engine_threads', threads);

  int get engineHash => get<int>('engine_hash', 256);
  Future<void> setEngineHash(int mb) => set('engine_hash', mb);

  int get engineSkillLevel => get<int>('engine_skill_level', 20);
  Future<void> setEngineSkillLevel(int level) =>
      set('engine_skill_level', level);

  String get enginePath => get<String>('engine_path', '');
  Future<void> setEnginePath(String path) => set('engine_path', path);

  int get multiPV => get<int>('multi_pv', 1);
  Future<void> setMultiPV(int count) => set('multi_pv', count);

  double get splitterRatio => get<double>('splitter_ratio', 0.3);
  Future<void> setSplitterRatio(double ratio) => set('splitter_ratio', ratio);

  int get windowWidth => get<int>('window_width', 1200);
  Future<void> setWindowWidth(int width) => set('window_width', width);

  int get windowHeight => get<int>('window_height', 800);
  Future<void> setWindowHeight(int height) => set('window_height', height);

  bool get soundEnabled => get<bool>('sound_enabled', true);
  Future<void> setSoundEnabled(bool enabled) => set('sound_enabled', enabled);

  double get volume => get<double>('volume', 0.7);
  Future<void> setVolume(double vol) => set('volume', vol);

  bool get showMoveHints => get<bool>('show_move_hints', true);
  Future<void> setShowMoveHints(bool show) => set('show_move_hints', show);

  bool get showCoordinates => get<bool>('show_coordinates', true);
  Future<void> setShowCoordinates(bool show) => set('show_coordinates', show);

  String get lastOpenedDir => get<String>('last_opened_dir', '');
  Future<void> setLastOpenedDir(String path) => set('last_opened_dir', path);

  String get recentFiles => get<String>('recent_files', '[]');
  Future<void> setRecentFiles(String json) => set('recent_files', json);

  /// 引擎协议类型：uci、ucci、auto(自动检测)
  String get engineProtocol => get<String>('engine_protocol', 'auto');
  Future<void> setEngineProtocol(String protocol) =>
      set('engine_protocol', protocol);

  Future<void> reset() async {
    _data.clear();
    await _save();
  }
}
