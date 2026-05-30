import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:xqmagic/utils/app_logger.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/utils/coord.dart';

/// Protocol enumeration for engine communication.
enum EngineProtocol {
  /// UCI (Universal Chess Interface) - used by most modern engines
  uci('uci', 'uciok'),

  /// UCCI (Universal Chinese Chess Interface) - used by some Chinese chess engines
  ucci('ucci', 'ucciok'),

  /// Auto-detect: try UCI first, then UCCI on failure
  auto('uci', 'uciok');

  const EngineProtocol(this.initCommand, this.okPattern);

  /// Command sent to initialize the protocol
  final String initCommand;

  /// Pattern to wait for to confirm protocol handshake succeeded
  final String okPattern;
}

/// UCI/UCCI protocol handler for Xiangqi engines.
///
/// Communicates with external chess engines (e.g., Pikafish) via stdin/stdout.
///
/// ## Move Format
/// Uses ICCS coordinate format: 4-digit string `col1row1col2row2`
/// where col is 0-8 and row is 0-9. Example: "1214" means from (1,2) to (1,4).
///
/// Internally, this class converts between ICCS format and the engine's native
/// UCI move format (alphanumeric like "h2e2").
///
/// ## Score Convention
/// Scores are in centipawns. Positive = red advantage, negative = black advantage.
class Engine {
  Engine({
    String? enginePath,
    this.logEnabled = false,
    EngineProtocol protocol = EngineProtocol.auto,
  }) : _enginePath = enginePath,
       _protocol = protocol;

  final String? _enginePath;
  final bool logEnabled;
  final EngineProtocol _protocol;

  Process? _process;
  bool _isRunning = false;
  bool _isReady = false;
  bool _isAnalyzing = false;

  // Engine info
  String _engineName = 'Unknown';
  String _engineAuthor = 'Unknown';
  final Map<String, UCIOption> _options = {};

  // Analysis state
  final List<EngineInfo> _currentInfos = [];
  EngineInfo? _bestInfo;
  String? _bestMove;
  String? _currentFen;

  // Streams for external consumers
  final StreamController<EngineEvent> _eventController =
      StreamController<EngineEvent>.broadcast();

  // Internal command queue
  final StreamController<String> _stdinController =
      StreamController<String>.broadcast();
  StreamSubscription<String>? _stdinSubscription;
  Completer<void>? _readyCompleter;
  Completer<String>? _bestMoveCompleter;
  Completer<void>? _stopCompleter;

  // Timeout defaults
  Duration _startupTimeout = const Duration(seconds: 30);
  Duration _analysisTimeout = const Duration(seconds: 60);

  // ---- Getters ----

  String get engineName => _engineName;
  String get engineAuthor => _engineAuthor;
  Map<String, UCIOption> get options => Map.unmodifiable(_options);
  bool get isRunning => _isRunning;
  bool get isReady => _isReady;
  String? get bestMove => _bestMove;
  List<EngineInfo> get currentInfos => List.unmodifiable(_currentInfos);
  EngineInfo? get bestInfo => _bestInfo;

  /// Stream of engine events (ready, info, bestmove, error, etc.)
  Stream<EngineEvent> get events => _eventController.stream;

  /// Stdin sink for sending raw UCI commands
  StreamSink<String> get stdin => _stdinController.sink;

  // ---- Configuration ----

  void setStartupTimeout(Duration timeout) => _startupTimeout = timeout;
  void setAnalysisTimeout(Duration timeout) => _analysisTimeout = timeout;

  // ---- Lifecycle ----

  /// Start the engine process and initialize UCI communication.
  /// Returns true if the engine started successfully and is ready.
  Future<bool> start() async {
    if (_isRunning) {
      _log('Engine already running');
      return _isReady;
    }

    if (_enginePath == null || _enginePath.isEmpty) {
      _emitEvent(EngineError('Engine path not configured'));
      return false;
    }

    try {
      _log('Starting engine: $_enginePath');
      final engineFile = File(_enginePath);
      if (!await engineFile.exists()) {
        _emitEvent(EngineError('Engine executable not found: $_enginePath'));
        return false;
      }

      // 使用绝对路径，避免 cmd /c 无法解析相对路径
      final absolutePath = engineFile.absolute.path;
      _process = await Process.start(
        Platform.isWindows ? 'cmd' : absolutePath,
        Platform.isWindows ? ['/c', absolutePath] : [],
        workingDirectory: engineFile.parent.path,
      );

      _isRunning = true;
      _log('Engine process started (PID: ${_process!.pid})');

      // Listen to stdout
      _process!.stdout
          .transform(systemEncoding.decoder)
          .transform(const LineSplitter())
          .listen(
            _handleEngineOutput,
            onDone: _handleEngineExit,
            onError: _handleEngineError,
          );

      // Listen to stderr
      _process!.stderr
          .transform(systemEncoding.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) => _log('STDERR: $line'),
            onDone: () {},
            onError: (e) => _emitEvent(EngineError('Engine stderr: $e')),
          );

      // Feed stdin from our controller
      _stdinSubscription = _stdinController.stream.listen((cmd) {
        if (_process != null) {
          _process!.stdin.writeln(cmd);
        }
        _log('>> $cmd');
      }, onError: (e) => _log('stdin error: $e'));

      // Send UCI/UCCI command based on protocol setting
      final protocolOk = await _handshake();
      if (!protocolOk) {
        _emitEvent(EngineError('Engine did not respond to uci/ucci command'));
        await stop();
        return false;
      }

      // Send isready and wait for readyok
      await _sendCommand('isready');
      final readyOk = await _waitForPattern(
        'readyok',
        timeout: _startupTimeout,
      );
      if (!readyOk) {
        _emitEvent(EngineError('Engine did not respond to isready command'));
        await stop();
        return false;
      }

      _isReady = true;
      _emitEvent(EngineReady());
      _log('Engine ready');
      return true;
    } catch (e) {
      _emitEvent(EngineError('Failed to start engine: $e'));
      _isRunning = false;
      return false;
    }
  }

  /// Stop the engine process gracefully.
  Future<void> stop() async {
    if (!_isRunning) {
      _isReady = false;
      return;
    }

    try {
      await _sendCommand('quit');
      // Give the process a moment to exit gracefully
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (_) {
      // Ignore errors during quit
    }

    _process?.kill();
    await _cleanupProcess();
    _isRunning = false;
    _isReady = false;
    _log('Engine stopped');
  }

  /// Restart the engine (stop + start).
  Future<bool> restart() async {
    await stop();
    return start();
  }

  Future<void> _cleanupProcess() async {
    await _stdinSubscription?.cancel();
    _stdinSubscription = null;
    _process = null;
  }

  Future<void> _startProcess(File engineFile, String absolutePath) async {
    _process = await Process.start(
      Platform.isWindows ? 'cmd' : absolutePath,
      Platform.isWindows ? ['/c', absolutePath] : [],
      workingDirectory: engineFile.parent.path,
    );
    _isRunning = true;

    _process!.stdout
        .transform(systemEncoding.decoder)
        .transform(const LineSplitter())
        .listen(
          _handleEngineOutput,
          onDone: _handleEngineExit,
          onError: _handleEngineError,
        );

    _process!.stderr
        .transform(systemEncoding.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) => _log('STDERR: $line'),
          onDone: () {},
          onError: (e) => _emitEvent(EngineError('Engine stderr: $e')),
        );

    _stdinSubscription = _stdinController.stream.listen((cmd) {
      if (_process != null) {
        _process!.stdin.writeln(cmd);
      }
      _log('>> $cmd');
    }, onError: (e) => _log('stdin error: $e'));
  }

  /// 协议握手：根据 _protocol 发送 uci/ucci 命令并等待响应
  /// - 'uci': 只尝试 uci，等待 uciok
  /// - 'ucci': 只尝试 ucci，等待 ucciok
  /// - 'auto': 先试 uci，失败后重启试 ucci
  Future<bool> _handshake() async {
    switch (_protocol) {
      case EngineProtocol.uci:
        await _sendCommand('uci');
        final ok = await _waitForPattern('uciok', timeout: _startupTimeout);
        if (ok) _log('Engine using UCI protocol');
        return ok;

      case EngineProtocol.ucci:
        await _sendCommand('ucci');
        final ok = await _waitForPattern('ucciok', timeout: _startupTimeout);
        if (ok) _log('Engine using UCCI protocol');
        return ok;

      case EngineProtocol.auto:
      default:
        // 先尝试 UCI
        await _sendCommand('uci');
        final uciOk = await _waitForPattern(
          'uciok',
          timeout: const Duration(seconds: 5),
        );
        if (uciOk) {
          _log('Engine using UCI protocol (auto-detected)');
          return true;
        }

        // UCI 失败，重启进程尝试 UCCI
        _log('UCI handshake failed, trying UCCI protocol...');
        final engineFile = File(_enginePath!);
        final absolutePath = engineFile.absolute.path;
        await _cleanupProcess();
        await _startProcess(engineFile, absolutePath);

        await _sendCommand('ucci');
        final ucciOk = await _waitForPattern(
          'ucciok',
          timeout: _startupTimeout,
        );
        if (ucciOk) {
          _log('Engine using UCCI protocol (auto-detected)');
          return true;
        }

        _log('Both UCI and UCCI handshakes failed');
        return false;
    }
  }

  // ---- UCI Commands ----

  /// Send "ucinewgame" to signal a new game.
  Future<void> newGame() async {
    if (!_isReady) return;
    _currentInfos.clear();
    _bestInfo = null;
    _bestMove = null;
    await _sendCommand('ucinewgame');
    _log('New game signaled');
  }

  /// Set an engine option.
  Future<void> setOption(String name, dynamic value) async {
    if (!_isReady) return;

    String valueStr;
    if (value is bool) {
      valueStr = value ? 'true' : 'false';
    } else {
      valueStr = value.toString();
    }

    await _sendCommand('setoption name $name value $valueStr');
    _log('Set option: $name = $valueStr');
  }

  /// Set multiple engine options at once.
  Future<void> setOptions(Map<String, dynamic> opts) async {
    for (final entry in opts.entries) {
      await setOption(entry.key, entry.value);
    }
  }

  /// Configure common engine options: threads, hash size, MultiPV.
  Future<void> configure({
    int? threads,
    int? hash,
    int? multiPV,
    Map<String, dynamic>? customOptions,
  }) async {
    if (threads != null) await setOption('Threads', threads);
    if (hash != null) await setOption('Hash', hash);
    if (multiPV != null) await setOption('MultiPV', multiPV);
    if (customOptions != null) {
      await setOptions(customOptions);
    }
  }

  /// Start analysis on a position.
  /// [fen] - FEN string of the position
  /// [depth] - Search depth limit (optional)
  /// [timeMs] - Maximum search time in milliseconds (optional)
  /// [multiPV] - Number of principal variations to return (optional)
  /// If both depth and timeMs are provided, uses both.
  Future<void> analyze({
    required String fen,
    int? depth,
    int? timeMs,
    int? multiPV,
  }) async {
    if (!_isReady) {
      _emitEvent(EngineError('Engine not ready'));
      return;
    }

    // Stop any ongoing analysis first
    if (_isAnalyzing) {
      await stopAnalysis();
    }

    _currentInfos.clear();
    _bestInfo = null;
    _bestMove = null;
    _currentFen = fen;

    // Send position
    await _sendCommand('position fen $fen');

    // Set MultiPV if specified
    if (multiPV != null) {
      await setOption('MultiPV', multiPV);
    }

    // Build go command
    String goCmd;
    if (depth != null && timeMs != null) {
      goCmd = 'go depth $depth movetime $timeMs';
    } else if (depth != null) {
      goCmd = 'go depth $depth';
    } else if (timeMs != null) {
      goCmd = 'go movetime $timeMs';
    } else {
      goCmd = 'go infinite';
    }

    await _sendCommand(goCmd);
    _isAnalyzing = true;
    _log('Analyzing: $goCmd');
  }

  /// Stop any ongoing analysis.
  Future<void> stopAnalysis() async {
    if (!_isAnalyzing) return;

    _stopCompleter = Completer<void>();
    await _sendCommand('stop');

    // Wait for bestmove or timeout
    try {
      await _stopCompleter!.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _log('stopAnalysis timed out');
          _isAnalyzing = false;
          return;
        },
      );
    } catch (_) {
      _isAnalyzing = false;
    }

    _stopCompleter = null;
    _log('Analysis stopped');
  }

  /// Request best move from the current position (blocking).
  Future<String?> getBestMove({
    required String fen,
    int? depth,
    int? timeMs,
  }) async {
    if (!_isReady) {
      _emitEvent(EngineError('Engine not ready'));
      return null;
    }

    if (_isAnalyzing) {
      await stopAnalysis();
    }

    _bestMoveCompleter = Completer<String>();

    await _sendCommand('position fen $fen');
    final goCmd = timeMs != null
        ? 'go movetime $timeMs'
        : (depth != null ? 'go depth $depth' : 'go infinite');
    await _sendCommand(goCmd);

    return _bestMoveCompleter!.future;
  }

  /// Ping the engine to check if it's responsive.
  Future<bool> ping() async {
    if (!_isReady) return false;
    try {
      await _sendCommand('isready');
      final ok = await _waitForPattern(
        'readyok',
        timeout: const Duration(seconds: 5),
      );
      return ok;
    } catch (_) {
      return false;
    }
  }

  // ---- Coordinate Conversion ----

  /// Convert UCCI numeric format (digits for cols) to ICCS alphanumeric format (file letters).
  ///
  /// UCCI numeric: columns are 0-8 digits (e.g. "7242" = h2e2)
  /// ICCS:          columns are a-i letters (e.g. "h2e2")
  ///
  /// If input is already in ICCS letter format, returns unchanged.
  static String numericToICCS(String input) {
    if (input.length != 4) return input;
    // Only convert digits → letters; if already letters, keep as-is
    if (!RegExp(r'^\d{4}$').hasMatch(input)) return input;

    final fromCol = int.parse(input[0]);
    final fromRank = input[1];
    final toCol = int.parse(input[2]);
    final toRank = input[3];
    final fromFile = String.fromCharCode('a'.codeUnitAt(0) + fromCol);
    final toFile = String.fromCharCode('a'.codeUnitAt(0) + toCol);
    return '$fromFile$fromRank$toFile$toRank';
  }

  /// Convert ICCS alphanumeric format (file letters) to UCCI numeric format (digits for cols).
  ///
  /// ICCS:          columns are a-i letters (e.g. "h2e2")
  /// UCCI numeric: columns are 0-8 digits (e.g. "7242" = h2e2)
  ///
  /// If input is already in numeric format, returns unchanged.
  static String iccsToNumeric(String input) {
    if (input.length != 4) return input;
    // Only convert letters → digits; if already digits, keep as-is
    if (!RegExp(r'^[a-i]\d[a-i]\d$').hasMatch(input)) return input;

    final fromFile = input[0];
    final fromRank = input[1];
    final toFile = input[2];
    final toRank = input[3];
    final fromCol = fromFile.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final toCol = toFile.codeUnitAt(0) - 'a'.codeUnitAt(0);
    return '$fromCol$fromRank$toCol$toRank';
  }

  /// Convert board coordinates to ICCS string.
  static String coordsToICCS(int fromCol, int fromRow, int toCol, int toRow) {
    final fromFile = Coord.colToFile(fromCol);
    final toFile = Coord.colToFile(toCol);
    return '$fromFile$fromRow$toFile$toRow';
  }

  // ---- Internal Methods ----

  Future<void> _sendCommand(String cmd) async {
    _stdinController.add(cmd);
  }

  Future<bool> _waitForPattern(
    String pattern, {
    required Duration timeout,
  }) async {
    final completer = Completer<bool>();

    late StreamSubscription sub;
    Timer? timer;

    timer = Timer(timeout, () {
      sub.cancel();
      completer.complete(false);
    });

    sub = _eventController.stream.listen((event) {
      if (event is EngineRawLine && event.line.contains(pattern)) {
        timer?.cancel();
        sub.cancel();
        completer.complete(true);
      }
    });

    return completer.future;
  }

  void _handleEngineOutput(String line) {
    _log('<< $line');
    _emitEvent(EngineRawLine(line));

    final trimmed = line.trim();
    if (trimmed.isEmpty) return;

    if (trimmed == 'uciok') {
      _emitEvent(EngineUCIOk());
    } else if (trimmed == 'readyok') {
      // Complete ready completer if waiting
      _readyCompleter?.complete();
    } else if (trimmed.startsWith('id name ')) {
      _engineName = trimmed.substring(8).trim();
      _emitEvent(EngineInfoEvent(name: _engineName));
    } else if (trimmed.startsWith('id author ')) {
      _engineAuthor = trimmed.substring(10).trim();
      _emitEvent(EngineInfoEvent(author: _engineAuthor));
    } else if (trimmed.startsWith('option name ')) {
      final option = _parseOption(trimmed);
      if (option != null) {
        _options[option.name] = option;
        _emitEvent(EngineInfoEvent(option: option));
      }
    } else if (trimmed.startsWith('bestmove ')) {
      _isAnalyzing = false;
      _parseBestMove(trimmed);
      _bestMoveCompleter?.complete(_bestMove);
      _stopCompleter?.complete();
      _emitEvent(EngineBestMove(_bestMove ?? ''));
    } else if (trimmed.startsWith('info ')) {
      final info = _parseInfo(trimmed);
      if (info != null) {
        _currentInfos.add(info);
        _emitEvent(EngineAnalysisUpdate(info, List.from(_currentInfos)));
      }
    }
  }

  void _parseBestMove(String line) {
    // bestmove h2e2 ponder h9g7
    final parts = line.split(' ');
    if (parts.length < 2) return;

    final move = parts[1];
    _bestMove = numericToICCS(move);
  }

  EngineInfo? _parseInfo(String line) {
    return _parseInfoLine(line);
  }

  EngineInfo? _parseInfoLine(String line) {
    // info depth 15 seldepth 17 score cp 32 nodes 123456 nps 500000 time 1234 pv h2e2 h9g7 ...
    // info depth 20 seldepth 25 score mate 3 nodes 99999 nps 450000 time 222 pv h2e2 ...

    final parts = line.split(' ');
    if (parts.length < 4) return null;

    int depth = 0;
    int seldepth = 0;
    int? score;
    bool? isMate;
    List<String> pv = [];
    int? nodes;
    int? nps;
    int? timeMs;
    int? hashfull;
    int? tbhits;
    int? multiPv;

    int i = 1;
    while (i < parts.length) {
      switch (parts[i]) {
        case 'depth':
          depth = int.tryParse(parts[++i]) ?? 0;
          break;
        case 'seldepth':
          seldepth = int.tryParse(parts[++i]) ?? 0;
          break;
        case 'score':
          if (parts[i + 1] == 'cp') {
            score = int.tryParse(parts[i + 2]) ?? 0;
            i += 2;
          } else if (parts[i + 1] == 'mate') {
            isMate = true;
            score = int.tryParse(parts[i + 2]) ?? 0;
            i += 2;
          }
          break;
        case 'nodes':
          nodes = int.tryParse(parts[++i]);
          break;
        case 'nps':
          nps = int.tryParse(parts[++i]);
          break;
        case 'time':
          timeMs = int.tryParse(parts[++i]);
          break;
        case 'hashfull':
          hashfull = int.tryParse(parts[++i]);
          break;
        case 'tbhits':
          tbhits = int.tryParse(parts[++i]);
          break;
        case 'multipv':
          multiPv = int.tryParse(parts[++i]);
          break;
        case 'pv':
          // Everything after 'pv' is the principal variation
          pv = parts.sublist(i + 1).map((m) => numericToICCS(m)).toList();
          i = parts.length; // exit loop
          break;
        case 'string':
          // Skip debug strings
          i = parts.length;
          break;
        default:
          break;
      }
      i++;
    }

    if (depth == 0 && pv.isEmpty) return null;

    final moveColor = _fenToMoveColor(_currentFen ?? '');

    return EngineInfo(
      depth: depth,
      selDepth: seldepth,
      score: score,
      isMate: isMate ?? false,
      pv: pv,
      nodes: nodes,
      nps: nps,
      timeMs: timeMs,
      hashfull: hashfull,
      tbhits: tbhits,
      moveColor: moveColor,
      multipv: multiPv ?? 1,
    );
  }

  static PieceColor _fenToMoveColor(String fen) {
    final parts = fen.split(' ');
    if (parts.length < 2) return PieceColor.red;
    return parts[1].toLowerCase() == 'r' ? PieceColor.red : PieceColor.black;
  }

  UCIOption? _parseOption(String line) {
    // option name Hash type spin default 128 min 16 max 8192
    // option name Clear Hash type button
    // option name MultiPV type spin default 1 min 1 max 64
    // option name UCI_EngineMode type check default true

    final parts = line.split(' ');
    if (parts.length < 5) return null;

    if (parts[2] != 'name') return null;

    int i = 3;
    String name = parts[i++];

    // Collect rest of line for type and optional params
    if (i >= parts.length) return null;
    if (parts[i++] != 'type') return null;
    if (i >= parts.length) return null;

    final typeStr = parts[i++];
    UCIOptionType? type;
    String? defaultValue;
    int? min;
    int? max;

    switch (typeStr) {
      case 'check':
        type = UCIOptionType.check;
        if (i < parts.length && parts[i] != 'default') {
          defaultValue = parts[i++];
        } else {
          defaultValue = 'false';
        }
        break;
      case 'spin':
        type = UCIOptionType.spin;
        if (i < parts.length && parts[i] == 'default') {
          defaultValue = parts[++i];
          i++;
        }
        if (i < parts.length && parts[i] == 'min') {
          min = int.tryParse(parts[++i]);
          i++;
        }
        if (i < parts.length && parts[i] == 'max') {
          max = int.tryParse(parts[++i]);
        }
        break;
      case 'string':
        type = UCIOptionType.string;
        if (i < parts.length && parts[i] == 'default') {
          defaultValue = parts.sublist(++i).join(' ');
          i = parts.length;
        }
        break;
      case 'combo':
        type = UCIOptionType.combo;
        if (i < parts.length && parts[i] == 'default') {
          defaultValue = parts[++i];
          i++;
        }
        break;
      case 'button':
        type = UCIOptionType.button;
        break;
      case 'filename':
        type = UCIOptionType.filename;
        if (i < parts.length && parts[i] == 'default') {
          defaultValue = parts.sublist(++i).join(' ');
          i = parts.length;
        }
        break;
      default:
        return null;
    }

    return UCIOption(
      name: name,
      type: type,
      defaultValue: defaultValue,
      min: min,
      max: max,
    );
  }

  void _handleEngineExit() {
    _log('Engine process exited');
    _isRunning = false;
    _isReady = false;
    _isAnalyzing = false;
    _emitEvent(EngineExited());
  }

  void _handleEngineError(Object error) {
    _log('Engine error: $error');
    _emitEvent(EngineError('Engine error: $error'));
  }

  void _emitEvent(EngineEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  void _log(String message) {
    if (logEnabled) {
      AppLogger.debug('Engine', message);
    }
  }

  /// Dispose resources.
  Future<void> dispose() async {
    await _stdinSubscription?.cancel();
    _stdinSubscription = null;
    await stop();
    await _eventController.close();
    await _stdinController.close();
  }
}

// ============================================================
// Data Models
// ============================================================

/// Base class for all engine events.
sealed class EngineEvent {}

/// Emitted when the engine confirms UCI/UCCI mode.
class EngineUCIOk extends EngineEvent {
  EngineUCIOk();
}

/// Emitted when the engine is ready after `isready`.
class EngineReady extends EngineEvent {
  EngineReady();
}

/// Raw line received from engine (for debugging).
class EngineRawLine extends EngineEvent {
  EngineRawLine(this.line);
  final String line;
}

/// Engine info: name, author, or option.
class EngineInfoEvent extends EngineEvent {
  EngineInfoEvent({this.name, this.author, this.option});
  final String? name;
  final String? author;
  final UCIOption? option;
}

/// Engine analysis update with current evaluation info.
class EngineAnalysisUpdate extends EngineEvent {
  EngineAnalysisUpdate(this.info, this.allInfos);
  final EngineInfo info;
  final List<EngineInfo> allInfos;
}

/// Engine has produced a best move.
class EngineBestMove extends EngineEvent {
  EngineBestMove(this.iccsMove);
  final String iccsMove;
}

/// Engine process has exited.
class EngineExited extends EngineEvent {
  EngineExited();
}

/// Engine error occurred.
class EngineError extends EngineEvent {
  EngineError(this.message);
  final String message;
}

/// Engine analysis info including depth, score, PV, etc.
class EngineInfo {
  const EngineInfo({
    required this.depth,
    this.selDepth,
    this.score,
    required this.isMate,
    required this.pv,
    this.nodes,
    this.nps,
    this.timeMs,
    this.hashfull,
    this.tbhits,
    required this.moveColor,
    required this.multipv,
  });

  final int depth;
  final int? selDepth;
  final int? score;
  final bool isMate;
  final List<String> pv;
  final int? nodes;
  final int? nps;
  final int? timeMs;
  final int? hashfull;
  final int? tbhits;
  final PieceColor moveColor;
  final int multipv;

  /// Score adjusted to red's perspective (positive = red better).
  int get adjustedScore {
    if (isMate) {
      return score != null ? score!.abs() : 0;
    }
    if (moveColor == PieceColor.black) {
      return score != null ? -score! : 0;
    }
    return score ?? 0;
  }

  /// Best move in ICCS format.
  String get bestMoveICCS => pv.isNotEmpty ? pv.first : '';

  @override
  String toString() =>
      'EngineInfo(depth=$depth, score=$score, pv=${pv.take(3).join(" ")})';
}

/// UCI engine option.
class UCIOption {
  const UCIOption({
    required this.name,
    required this.type,
    this.defaultValue,
    this.min,
    this.max,
  });

  final String name;
  final UCIOptionType type;
  final String? defaultValue;
  final int? min;
  final int? max;

  @override
  String toString() =>
      'UCIOption(name=$name, type=$type, default=$defaultValue)';
}

enum UCIOptionType { check, spin, combo, button, string, filename }
