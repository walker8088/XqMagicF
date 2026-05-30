import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:xqmagic/models/game_mode.dart';
import 'package:xqmagic/services/engine_configuration.dart';
import 'package:xqmagic/services/uci_engine.dart';
import 'package:xqmagic/utils/app_logger.dart';
import 'package:xqmagic/utils/app_settings.dart';
import 'package:xqmagic/utils/constants.dart';

/// Manages the lifecycle and analysis requests for a UCI Xiangqi engine.
///
/// Provides a higher-level API over [UCIEngine] for common use cases:
/// - Loading and starting engines from configurable paths
/// - Requesting position analysis with depth or time constraints
/// - Cancelling ongoing analysis
/// - Getting best moves for engine-vs-human (fight) mode
/// - Engine state management
/// Manages the lifecycle and analysis requests for a UCI/UCCI Xiangqi engine.
class EngineManager extends ChangeNotifier {
  EngineManager({String? defaultEnginePath, this.logEnabled = false})
    : _defaultEnginePath = defaultEnginePath,
      _config = EngineConfiguration();

  final String? _defaultEnginePath;
  final bool logEnabled;
  final EngineConfiguration _config;

  /// 引擎协议类型：'uci'、'ucci'、'auto'
  String _protocol = 'auto';
  String get protocol => _protocol;
  void setProtocol(String protocol) {
    if (protocol == 'uci' || protocol == 'ucci' || protocol == 'auto') {
      _protocol = protocol;
      notifyListeners();
    }
  }

  /// 引擎分析模式
  EngineAnalysisMode _analysisMode = EngineAnalysisMode.deep;
  EngineAnalysisMode get analysisMode => _analysisMode;

  /// 优先级模式
  PriorityMode _priorityMode = PriorityMode.engine;
  PriorityMode get priorityMode => _priorityMode;

  /// 是否正在分析
  bool _isAnalyzing = false;
  bool get isAnalyzing => _isAnalyzing;

  UCIEngine? _engine;
  EngineState _state = EngineState.idle;

  /// 引擎配置
  EngineConfiguration get config => _config;
  int get depth => _config.depth;
  int get timeMs => _config.timeMs;
  int get threads => _config.threads;
  int get hash => _config.hash;
  int get multiPV => _config.multiPV;
  Map<String, dynamic> get customOptions => _config.customOptions;

  String? _currentFen;
  EngineInfo? _latestInfo;
  List<EngineInfo> _allInfos = [];
  String? _lastBestMove;
  String? _error;

  // Subscription to engine events
  StreamSubscription<EngineEvent>? _eventSubscription;

  // ---- Getters ----

  UCIEngine? get engine => _engine;
  EngineState get state => _state;
  String? get currentFen => _currentFen;
  EngineInfo? get latestInfo => _latestInfo;
  List<EngineInfo> get allInfos => List.unmodifiable(_allInfos);
  String? get lastBestMove => _lastBestMove;
  String? get error => _error;
  bool get isReady => _state == EngineState.ready;
  bool get isThinking => _state == EngineState.thinking;
  bool get isIdle => _state == EngineState.idle;
  bool get hasError => _state == EngineState.error;

  String get engineName => _engine?.engineName ?? 'Not loaded';
  String get engineAuthor => _engine?.engineAuthor ?? '';

  // Current analysis

  /// Set search depth for analysis.
  void setDepth(int depth) => _config.setDepth(depth);

  /// Set time limit for analysis in milliseconds.
  void setTimeMs(int ms) => _config.setTimeMs(ms);

  /// Set number of threads for the engine.
  void setThreads(int threads) => _config.setThreads(threads);

  /// Set hash table size in MB.
  void setHash(int mb) => _config.setHash(mb);

  /// Set MultiPV (number of principal variations).
  Future<void> setMultiPV(int n) async {
    if (n < 1) return;
    _config.setMultiPV(n);
    await _applyMultiPVToEngine();
  }

  /// Send the current MultiPV value to the running engine.
  Future<void> _applyMultiPVToEngine() async {
    final eng = _engine;
    if (eng != null && eng.isReady && !isThinking) {
      try {
        await eng.setOption('MultiPV', _config.multiPV);
        _log('MultiPV set to ${_config.multiPV} on engine');
      } catch (e) {
        _log('Failed to apply MultiPV to engine: $e');
      }
    }
  }

  /// Set Skill Level for the engine (0-20, UCI standard).
  void setSkillLevel(int level) => _config.setSkillLevel(level);

  /// Set a custom engine option.
  void setCustomOption(String name, dynamic value) =>
      _config.setCustomOption(name, value);

  /// Clear a custom engine option.
  void clearCustomOption(String name) => _config.clearCustomOption(name);

  /// 同步 AppSettings 中的引擎配置到运行中的引擎
  Future<void> syncSettingsToEngine() async {
    final settings = AppSettings.instance;
    setProtocol(settings.engineProtocol);
    setDepth(settings.engineDepth);
    setThreads(settings.engineThreads);
    setHash(settings.engineHash);
    setSkillLevel(settings.engineSkillLevel);
    _config.setMultiPV(settings.multiPV);
    await applyConfiguration();
  }

  void setAnalysisMode(EngineAnalysisMode mode) {
    _analysisMode = mode;
    notifyListeners();
  }

  void setPriorityMode(PriorityMode mode) {
    _priorityMode = mode;
    notifyListeners();
  }

  void setIsAnalyzing(bool analyzing) {
    _isAnalyzing = analyzing;
    notifyListeners();
  }

  /// Apply all configuration options to the running engine.
  Future<void> applyConfiguration() async {
    final eng = _engine;
    if (eng == null || !eng.isReady) return;
    await _config.applyToEngine(eng);
  }

  // ---- Engine Lifecycle ----

  /// Load and start the engine.
  /// If [enginePath] is null, uses the default path.
  Future<bool> loadEngine({String? enginePath}) async {
    final path = enginePath ?? _defaultEnginePath;
    AppLogger.debug('EngineManager', 'loadEngine: path=$path');
    if (path == null || path.isEmpty) {
      _state = EngineState.error;
      _error = 'Engine path not configured';
      notifyListeners();
      AppLogger.warn('EngineManager', 'loadEngine failed: no path configured');
      return false;
    }

    // Apply protocol from AppSettings before loading
    setProtocol(AppSettings.instance.engineProtocol);

    await _cleanupEngine();

    _state = EngineState.loading;
    _error = null;
    notifyListeners();
    AppLogger.debug(
      'EngineManager',
      'loadEngine: state=loading, creating UCIEngine...',
    );

    try {
      _engine = UCIEngine(
        enginePath: path,
        logEnabled: logEnabled,
        protocol: _protocol,
      );

      // Subscribe to engine events
      _eventSubscription = _engine!.events.listen(_onEngineEvent);
      AppLogger.debug('EngineManager', 'UCIEngine created, calling start()...');

      final started = await _engine!.start();
      AppLogger.debug('EngineManager', 'engine start() returned: $started');
      if (!started) {
        _state = EngineState.error;
        _error = 'Failed to start engine';
        notifyListeners();
        AppLogger.warn(
          'EngineManager',
          'loadEngine failed: start() returned false',
        );
        return false;
      }

      _state = EngineState.ready;
      notifyListeners();
      _log('Engine loaded: ${_engine!.engineName}');
      AppLogger.debug(
        'EngineManager',
        'Engine loaded successfully: ${_engine!.engineName}',
      );

      // Apply analysis mode settings after successful load
      setDepth(_analysisMode.depth);
      setTimeMs(_analysisMode.timeMs);
      await setMultiPV(_config.multiPV);

      return true;
    } catch (e, st) {
      _state = EngineState.error;
      _error = 'Failed to load engine: $e';
      notifyListeners();
      AppLogger.error('EngineManager', 'loadEngine exception: $e');
      AppLogger.debug('EngineManager', 'stack: $st');
      return false;
    }
  }

  /// Stop and unload the engine.
  Future<void> unloadEngine() async {
    await _cleanupEngine();
    _state = EngineState.idle;
    _error = null;
    _latestInfo = null;
    _allInfos.clear();
    _lastBestMove = null;
    _currentFen = null;
    _isAnalyzing = false;
    notifyListeners();
  }

  /// Restart the engine with current configuration.
  Future<bool> restartEngine() async {
    if (_engine == null) return false;

    _state = EngineState.loading;
    notifyListeners();

    final success = await _engine!.restart();
    if (success) {
      await applyConfiguration();
      _state = EngineState.ready;
    } else {
      _state = EngineState.error;
      _error = 'Failed to restart engine';
    }
    notifyListeners();
    return success;
  }

  /// Check if the engine is still alive.
  Future<bool> ping() async {
    if (_engine == null) return false;
    final alive = await _engine!.ping();
    if (!alive) {
      _state = EngineState.error;
      _error = 'Engine is not responsive';
      notifyListeners();
    }
    return alive;
  }

  // ---- Analysis Methods ----

  /// Start analysis on a position using the configured depth.
  Future<void> analyze({required String fen}) async {
    if (_engine == null || !_engine!.isReady) {
      _state = EngineState.error;
      _error = 'Engine not ready';
      notifyListeners();
      return;
    }

    _currentFen = fen;
    final activePart = fen.split(' ').length >= 2 ? fen.split(' ')[1] : '?';
    _log(
      'analyze() FEN activeColor=$activePart (expected: ${activePart == "r" ? "red" : "black"})',
    );
    _allInfos.clear();
    _latestInfo = null;
    _state = EngineState.thinking;
    notifyListeners();

    try {
      await _engine!.analyze(
        fen: fen,
        depth: _config.depth,
        timeMs: _config.timeMs,
        multiPV: _config.multiPV,
      );
    } catch (e) {
      _state = EngineState.error;
      _error = 'Analysis failed: $e';
      notifyListeners();
    }
  }

  /// Start analysis with a specific depth.
  Future<void> analyzeByDepth({required String fen, required int depth}) async {
    if (_engine == null || !_engine!.isReady) {
      _state = EngineState.error;
      _error = 'Engine not ready';
      notifyListeners();
      return;
    }

    _currentFen = fen;
    _allInfos.clear();
    _latestInfo = null;
    _state = EngineState.thinking;
    notifyListeners();

    try {
      await _engine!.analyzeByDepth(
        fen: fen,
        depth: depth,
        multiPV: _config.multiPV,
      );
    } catch (e) {
      _state = EngineState.error;
      _error = 'Analysis failed: $e';
      notifyListeners();
    }
  }

  /// Start analysis with a specific time limit.
  Future<void> analyzeByTime({required String fen, required int timeMs}) async {
    if (_engine == null || !_engine!.isReady) {
      _state = EngineState.error;
      _error = 'Engine not ready';
      notifyListeners();
      return;
    }

    _currentFen = fen;
    _allInfos.clear();
    _latestInfo = null;
    _state = EngineState.thinking;
    notifyListeners();

    try {
      await _engine!.analyzeByTime(
        fen: fen,
        timeMs: timeMs,
        multiPV: _config.multiPV,
      );
    } catch (e) {
      _state = EngineState.error;
      _error = 'Analysis failed: $e';
      notifyListeners();
    }
  }

  /// Start infinite analysis (runs until cancelled).
  Future<void> analyzeInfinite({required String fen}) async {
    if (_engine == null || !_engine!.isReady) {
      _state = EngineState.error;
      _error = 'Engine not ready';
      notifyListeners();
      return;
    }

    _currentFen = fen;
    _allInfos.clear();
    _latestInfo = null;
    _state = EngineState.thinking;
    notifyListeners();

    try {
      await _engine!.analyzeInfinite(fen);
    } catch (e) {
      _state = EngineState.error;
      _error = 'Infinite analysis failed: $e';
      notifyListeners();
    }
  }

  /// Cancel the current analysis.
  Future<void> cancelAnalysis() async {
    if (_engine == null) return;
    await _engine!.stopAnalysis();
    _state = EngineState.ready;
    notifyListeners();
  }

  /// 立即清除分析结果（不走子时调用，同步清除旧数据，避免 UI 闪烁旧 PV）
  void clearAnalysisResults() {
    _allInfos.clear();
    _latestInfo = null;
    _lastBestMove = null;
    _state = EngineState.ready;
  }

  /// Signal a new game (clear engine's hash/transposition table).
  Future<void> newGame() async {
    if (_engine == null || !_engine!.isReady) return;

    if (isThinking) {
      await cancelAnalysis();
    }

    await _engine!.newGame();
    _allInfos.clear();
    _latestInfo = null;
    _lastBestMove = null;
    _currentFen = null;
    _isAnalyzing = false;
    _state = EngineState.ready;
    notifyListeners();
  }

  // ---- Best Move Methods ----

  /// 开始分析（包装方法）
  Future<void> startAnalysis(String fen) async {
    _isAnalyzing = true;
    notifyListeners();
    await analyze(fen: fen);
  }

  /// 停止分析（包装方法）
  Future<void> stopAnalysis() async {
    _isAnalyzing = false;
    await cancelAnalysis();
    notifyListeners();
  }

  /// Get the best move for the current position (blocking call).
  /// Returns the best move in ICCS format (col1row1col2row2).
  ///
  /// Use this for engine fight mode where you need a single best move.
  Future<String?> getBestMove({
    required String fen,
    int? depth,
    int? timeMs,
  }) async {
    if (_engine == null || !_engine!.isReady) {
      _error = 'Engine not ready';
      notifyListeners();
      return null;
    }

    final searchDepth = depth ?? _config.depth;
    final searchTime = timeMs ?? _config.timeMs;

    _state = EngineState.thinking;
    _currentFen = fen;
    notifyListeners();

    try {
      final move = await _engine!.getBestMove(
        fen: fen,
        depth: searchDepth,
        timeMs: searchTime,
      );
      _lastBestMove = move;
      _state = EngineState.ready;
      notifyListeners();
      return move;
    } catch (e) {
      _state = EngineState.error;
      _error = 'Failed to get best move: $e';
      notifyListeners();
      return null;
    }
  }

  /// Get the best move for engine fight mode.
  /// Similar to [getBestMove] but optimized for fight mode with fixed settings.
  Future<String?> getFightMove({required String fen}) async {
    return getBestMove(fen: fen, depth: _config.depth, timeMs: _config.timeMs);
  }

  /// Get the best move from current analysis results (non-blocking).
  /// Returns null if no analysis is running or no results yet.
  String? getCurrentBestMove() {
    if (_allInfos.isEmpty) return null;
    final best = _allInfos.firstWhere(
      (info) => info.multipv == 1,
      orElse: () => _allInfos.first,
    );
    return best.bestMoveICCS;
  }

  /// Get the current evaluation score in centipawns.
  /// Positive = red advantage, negative = black advantage.
  /// Returns null if no analysis is running.
  int? getCurrentScore() {
    if (_allInfos.isEmpty) return null;
    final best = _allInfos.firstWhere(
      (info) => info.multipv == 1,
      orElse: () => _allInfos.first,
    );
    return best.adjustedScore;
  }

  /// Check if the current evaluation indicates a mate.
  bool? isInMateSituation() {
    if (_allInfos.isEmpty) return null;
    final best = _allInfos.firstWhere(
      (info) => info.multipv == 1,
      orElse: () => _allInfos.first,
    );
    return best.isMate;
  }

  // ---- Internal ----

  /// 冗余检测：引擎输出的走子方是否与当前 FEN 一致
  /// 不一致时丢弃（防止时序竞态导致的错误数据进入 UI）
  bool _isAnalysisForCurrentSide({EngineInfo? info}) {
    if (_currentFen == null) return true;
    final parts = _currentFen!.split(' ');
    if (parts.length < 2) return true;
    final isRedExpected = parts[1].toLowerCase() == 'r';
    if (info != null && (info.moveColor == PieceColor.red) != isRedExpected) {
      _log(
        'MISMATCH: FEN says ${isRedExpected ? "red" : "black"} to move, '
        'but EngineInfo says ${info.moveColor == PieceColor.red ? "red" : "black"} — discarded',
      );
      return false;
    }
    return true;
  }

  /// 重置引擎配置状态
  void reset() {
    _analysisMode = EngineAnalysisMode.deep;
    _priorityMode = PriorityMode.engine;
    _config.reset();
    _isAnalyzing = false;
    notifyListeners();
  }

  void _onEngineEvent(EngineEvent event) {
    switch (event) {
      case EngineReady():
        if (_state == EngineState.loading) {
          _state = EngineState.ready;
          // Apply configuration once engine is ready
          applyConfiguration();
        } else {
          _state = EngineState.ready;
        }
        notifyListeners();

      case EngineBestMove(iccsMove: final move):
        _lastBestMove = move;
        _state = EngineState.ready;
        notifyListeners();

      case EngineAnalysisUpdate(info: final info, allInfos: final allInfos):
        if (!_isAnalysisForCurrentSide(info: info)) {
          _log(
            'REJECTED EngineAnalysisUpdate depth=${info.depth} '
            'moveColor=${info.moveColor == PieceColor.red ? "red" : "black"} pv=${info.pv}',
          );
          break;
        }
        _log(
          'ACCEPTED EngineAnalysisUpdate depth=${info.depth} '
          'moveColor=${info.moveColor == PieceColor.red ? "red" : "black"} pv=${info.pv.take(2).join(" ")}',
        );
        _latestInfo = info;
        _allInfos = allInfos;
        notifyListeners();

      case EngineError(message: final message):
        _state = EngineState.error;
        _error = message;
        notifyListeners();

      case EngineExited():
        _state = EngineState.error;
        _error = 'Engine process exited unexpectedly';
        notifyListeners();

      case EngineUCIOk():
        // Engine responded to UCI command, still loading
        break;

      case EngineRawLine():
        // Raw line, no state change needed
        break;

      case EngineInfoEvent():
        // Engine info event, no state change needed
        break;
    }
  }

  Future<void> _cleanupEngine() async {
    await _eventSubscription?.cancel();
    _eventSubscription = null;
    await _engine?.dispose();
    _engine = null;
  }

  void _log(String message) {
    if (logEnabled) {
      AppLogger.debug('EngineManager', message);
    }
  }

  @override
  void dispose() {
    _cleanupEngine();
    super.dispose();
  }
}

/// Engine state enumeration.
enum EngineState {
  /// Engine is not loaded or has been unloaded.
  idle,

  /// Engine is being loaded (process starting, UCI handshake).
  loading,

  /// Engine is ready to accept commands.
  ready,

  /// Engine is currently analyzing a position.
  thinking,

  /// Engine encountered an error.
  error,
}
