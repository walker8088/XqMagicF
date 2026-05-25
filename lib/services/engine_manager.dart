import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:xqmagic/services/uci_engine.dart';

/// Manages the lifecycle and analysis requests for a UCI Xiangqi engine.
///
/// Provides a higher-level API over [UCIEngine] for common use cases:
/// - Loading and starting engines from configurable paths
/// - Requesting position analysis with depth or time constraints
/// - Cancelling ongoing analysis
/// - Getting best moves for engine-vs-human (fight) mode
/// - Engine state management
class EngineManager extends ChangeNotifier {
  EngineManager({String? defaultEnginePath, this.logEnabled = false})
    : _defaultEnginePath = defaultEnginePath;

  final String? _defaultEnginePath;
  final bool logEnabled;

  UCIEngine? _engine;
  EngineState _state = EngineState.idle;

  // Engine configuration
  int _depth = 15;
  int _timeMs = 3000;
  int _threads = 1;
  int _hash = 64;
  int _multiPV = 1;
  final Map<String, dynamic> _customOptions = {};

  // Current analysis
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

  // Configuration
  int get depth => _depth;
  int get timeMs => _timeMs;
  int get threads => _threads;
  int get hash => _hash;
  int get multiPV => _multiPV;
  Map<String, dynamic> get customOptions => Map.unmodifiable(_customOptions);

  // ---- Configuration Methods ----

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
  Future<void> applyConfiguration() async {
    if (_engine == null || !_engine!.isReady) return;

    await _engine!.configure(
      threads: _threads,
      hash: _hash,
      multiPV: _multiPV,
      customOptions: _customOptions,
    );

    _log(
      'Configuration applied: depth=$_depth, time=$_timeMs, '
      'threads=$_threads, hash=$_hash, multiPV=$_multiPV',
    );
  }

  // ---- Engine Lifecycle ----

  /// Load and start the engine.
  /// If [enginePath] is null, uses the default path.
  Future<bool> loadEngine({String? enginePath}) async {
    final path = enginePath ?? _defaultEnginePath;
    if (path == null || path.isEmpty) {
      _state = EngineState.error;
      _error = 'Engine path not configured';
      notifyListeners();
      return false;
    }

    await _cleanupEngine();

    _state = EngineState.loading;
    _error = null;
    notifyListeners();

    try {
      _engine = UCIEngine(enginePath: path, logEnabled: logEnabled);

      // Subscribe to engine events
      _eventSubscription = _engine!.events.listen(_onEngineEvent);

      final started = await _engine!.start();
      if (!started) {
        _state = EngineState.error;
        _error = 'Failed to start engine';
        notifyListeners();
        return false;
      }

      _state = EngineState.ready;
      notifyListeners();
      _log('Engine loaded: ${_engine!.engineName}');
      return true;
    } catch (e) {
      _state = EngineState.error;
      _error = 'Failed to load engine: $e';
      notifyListeners();
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
    _allInfos.clear();
    _latestInfo = null;
    _state = EngineState.thinking;
    notifyListeners();

    try {
      await _engine!.analyze(
        fen: fen,
        depth: _depth,
        timeMs: _timeMs,
        multiPV: _multiPV,
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
      await _engine!.analyzeByDepth(fen: fen, depth: depth, multiPV: _multiPV);
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
      await _engine!.analyzeByTime(fen: fen, timeMs: timeMs, multiPV: _multiPV);
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
    _state = EngineState.ready;
    notifyListeners();
  }

  // ---- Best Move Methods ----

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

    final searchDepth = depth ?? _depth;
    final searchTime = timeMs ?? _timeMs;

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
    return getBestMove(fen: fen, depth: _depth, timeMs: _timeMs);
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
    return best.score;
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
      debugPrint('[EngineManager] $message');
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
