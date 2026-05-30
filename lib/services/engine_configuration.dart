import 'package:flutter/foundation.dart';
import 'package:xqmagic/services/engine.dart';
import 'package:xqmagic/utils/app_logger.dart';

/// 引擎配置数据类：管理纯配置参数
///
/// 职责：
/// - 存储引擎配置参数（depth、timeMs、threads、hash、multiPV、customOptions）
/// - 提供 applyToEngine() 方法将配置应用到运行中的引擎
///
/// 不负责：
/// - 引擎生命周期（由 EngineManager 管理）
/// - 分析触发（由 EngineManager 管理）
/// - 分析模式/优先级模式（由 EngineManager 管理）
class EngineConfiguration extends ChangeNotifier {
  int _depth = 15;
  int _timeMs = 3000;
  int _threads = 1;
  int _hash = 64;
  int _multiPV = 1;
  final Map<String, dynamic> _customOptions = {};

  // Getters
  int get depth => _depth;
  int get timeMs => _timeMs;
  int get threads => _threads;
  int get hash => _hash;
  int get multiPV => _multiPV;
  Map<String, dynamic> get customOptions => Map.unmodifiable(_customOptions);

  // Setters

  /// Set search depth for analysis.
  void setDepth(int depth) {
    if (depth <= 0) return;
    _depth = depth;
    notifyListeners();
  }

  /// Set time limit for analysis in milliseconds.
  void setTimeMs(int ms) {
    if (ms <= 0) return;
    _timeMs = ms;
    notifyListeners();
  }

  /// Set number of threads for the engine.
  void setThreads(int threads) {
    if (threads <= 0) return;
    _threads = threads;
    notifyListeners();
  }

  /// Set hash table size in MB.
  void setHash(int mb) {
    if (mb <= 0) return;
    _hash = mb;
    notifyListeners();
  }

  /// Set MultiPV (number of principal variations).
  void setMultiPV(int n) {
    if (n < 1) return;
    _multiPV = n;
    notifyListeners();
  }

  /// Set Skill Level for the engine (0-20, UCI standard).
  void setSkillLevel(int level) {
    if (level < 0 || level > 20) return;
    _customOptions['Skill Level'] = level;
    notifyListeners();
  }

  /// Set a custom engine option.
  void setCustomOption(String name, dynamic value) {
    _customOptions[name] = value;
    notifyListeners();
  }

  /// Clear a custom engine option.
  void clearCustomOption(String name) {
    _customOptions.remove(name);
    notifyListeners();
  }

  /// Apply all configuration options to the running engine.
  Future<void> applyToEngine(Engine engine) async {
    if (!engine.isReady) return;

    await engine.configure(
      threads: _threads,
      hash: _hash,
      multiPV: _multiPV,
      customOptions: _customOptions,
    );

    AppLogger.debug(
      'EngineConfiguration',
      'Applied: depth=$_depth, time=$_timeMs, threads=$_threads, hash=$_hash, multiPV=$_multiPV',
    );
  }

  /// Reset to default values.
  void reset() {
    _depth = 15;
    _timeMs = 3000;
    _threads = 1;
    _hash = 64;
    _multiPV = 1;
    _customOptions.clear();
    notifyListeners();
  }
}
