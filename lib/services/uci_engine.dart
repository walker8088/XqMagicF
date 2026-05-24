import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// UCI (Universal Chess Interface) protocol handler for Xiangqi engines.
///
/// Communicates with external chess engines (e.g., Pikafish) via stdin/stdout
/// using the UCI-Xiangqi protocol variant.
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
class UCIEngine {
  UCIEngine({String? enginePath, this.logEnabled = false})
    : _enginePath = enginePath;

  final String? _enginePath;
  final bool logEnabled;

  Process? _process;
  bool _isRunning = false;
  bool _isReady = false;

  // Engine info
  String _engineName = 'Unknown';
  String _engineAuthor = 'Unknown';
  final Map<String, UCIOption> _options = {};

  // Analysis state
  final List<EngineInfo> _currentInfos = [];
  EngineInfo? _bestInfo;
  String? _bestMove;

  // Streams for external consumers
  final StreamController<EngineEvent> _eventController =
      StreamController<EngineEvent>.broadcast();

  // Internal command queue
  final StreamController<String> _stdinController =
      StreamController<String>.broadcast();
  StreamSubscription<String>? _stdinSubscription;
  Completer<void>? _readyCompleter;
  Completer<String>? _bestMoveCompleter;

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

      _process = await Process.start(
        Platform.isWindows ? 'cmd' : _enginePath,
        Platform.isWindows ? ['/c', _enginePath] : [],
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

      // Send UCI command and wait for uciok
      await _sendCommand('uci');
      final uciOk = await _waitForPattern('uciok', timeout: _startupTimeout);
      if (!uciOk) {
        _emitEvent(EngineError('Engine did not respond to uci command'));
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
    _process = null;
    _isRunning = false;
    _isReady = false;
    _log('Engine stopped');
  }

  /// Restart the engine.
  Future<bool> restart() async {
    await stop();
    return start();
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

  /// Start analysis on a position using depth limit.
  /// [fen] - FEN string of the position
  /// [depth] - Search depth limit
  /// [multiPV] - Number of principal variations to return
  Future<void> analyzeByDepth({
    required String fen,
    required int depth,
    int? multiPV,
  }) async {
    if (!_isReady) {
      _emitEvent(EngineError('Engine not ready'));
      return;
    }

    _currentInfos.clear();
    _bestInfo = null;
    _bestMove = null;

    final positionCmd = 'position fen $fen';
    await _sendCommand(positionCmd);

    if (multiPV != null && multiPV > 1) {
      await setOption('MultiPV', multiPV);
    }

    final goCmd = 'go depth $depth';
    await _sendCommand(goCmd);
    _log('Analyzing by depth: $depth');
  }

  /// Start analysis on a position using time limit.
  /// [fen] - FEN string of the position
  /// [timeMs] - Maximum search time in milliseconds
  /// [multiPV] - Number of principal variations to return
  Future<void> analyzeByTime({
    required String fen,
    required int timeMs,
    int? multiPV,
  }) async {
    if (!_isReady) {
      _emitEvent(EngineError('Engine not ready'));
      return;
    }

    _currentInfos.clear();
    _bestInfo = null;
    _bestMove = null;

    final positionCmd = 'position fen $fen';
    await _sendCommand(positionCmd);

    if (multiPV != null && multiPV > 1) {
      await setOption('MultiPV', multiPV);
    }

    final goCmd = 'go movetime $timeMs';
    await _sendCommand(goCmd);
    _log('Analyzing by time: ${timeMs}ms');
  }

  /// Start infinite analysis (must be stopped with [stopAnalysis]).
  Future<void> analyzeInfinite(String fen) async {
    if (!_isReady) {
      _emitEvent(EngineError('Engine not ready'));
      return;
    }

    _currentInfos.clear();
    _bestInfo = null;
    _bestMove = null;

    await _sendCommand('position fen $fen');
    await _sendCommand('go infinite');
    _log('Infinite analysis started');
  }

  /// Start analysis with both depth and time constraints.
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

    _currentInfos.clear();
    _bestInfo = null;
    _bestMove = null;

    await _sendCommand('position fen $fen');

    if (multiPV != null && multiPV > 1) {
      await setOption('MultiPV', multiPV);
    }

    String goCmd;
    if (depth != null && timeMs != null) {
      goCmd = 'go depth $depth movetime $timeMs';
    } else if (depth != null) {
      goCmd = 'go depth $depth';
    } else if (timeMs != null) {
      goCmd = 'go movetime $timeMs';
    } else {
      goCmd = 'go depth 20'; // default
    }

    await _sendCommand(goCmd);
    _log('Analysis started: $goCmd');
  }

  /// Stop the current analysis.
  Future<void> stopAnalysis() async {
    if (!_isRunning) return;
    await _sendCommand('stop');
    _log('Analysis stop requested');
  }

  /// Get the best move for the current position (blocking).
  /// Returns the best move in ICCS format, or null if no move found.
  Future<String?> getBestMove({
    required String fen,
    int depth = 15,
    int? timeMs,
  }) async {
    if (!_isReady) return null;

    _bestMoveCompleter = Completer<String>();

    await _sendCommand('position fen $fen');

    final goCmd = timeMs != null ? 'go movetime $timeMs' : 'go depth $depth';
    await _sendCommand(goCmd);

    try {
      return await _bestMoveCompleter!.future.timeout(_analysisTimeout);
    } on TimeoutException {
      _log('Best move request timed out');
      await stopAnalysis();
      return _bestMove;
    }
  }

  /// Check if the engine is still responsive.
  Future<bool> ping() async {
    if (!_isRunning) return false;
    try {
      await _sendCommand('isready');
      return await _waitForPattern(
        'readyok',
        timeout: const Duration(seconds: 5),
      );
    } catch (_) {
      return false;
    }
  }

  // ---- Move Format Conversion ----

  /// Convert ICCS move format (col1row1col2row2) to UCI move format.
  /// ICCS: "1214" (col=1, row=2 to col=1, row=4)
  /// UCI: "h2e2" style (file letter + rank digit)
  ///
  /// Chinese Chess UCI uses files a-i (left to right, col 0-8)
  /// and ranks 0-9 (bottom to top from engine's perspective).
  ///
  /// For Xiangqi engines, row in FEN is 0=top, 9=bottom.
  /// UCI engines typically use: rank = 9 - row (so rank 0 = FEN row 9 = red's back rank).
  static String iccsToUCI(String iccsMove) {
    if (iccsMove.length != 4) return iccsMove;

    final fromCol = int.tryParse(iccsMove[0]) ?? 0;
    final fromRow = int.tryParse(iccsMove[1]) ?? 0;
    final toCol = int.tryParse(iccsMove[2]) ?? 0;
    final toRow = int.tryParse(iccsMove[3]) ?? 0;

    return convertToUCIMove(fromCol, fromRow, toCol, toRow);
  }

  /// Convert UCI move format back to ICCS format.
  static String uciToICCS(String uciMove) {
    if (uciMove.length < 4) return uciMove;

    // Parse UCI format: file (a-i) + rank (0-9)
    final fromCol = _fileToCol(uciMove[0]);
    final fromRank = int.tryParse(uciMove[1]) ?? 0;
    final toCol = _fileToCol(uciMove[2]);
    final toRank = int.tryParse(uciMove[3]) ?? 0;

    // Convert ranks back to FEN rows
    final fromRow = 9 - fromRank;
    final toRow = 9 - toRank;

    return '$fromCol$fromRow$toCol$toRow';
  }

  /// Convert (col, row) in FEN coordinates to UCI move string.
  static String convertToUCIMove(
    int fromCol,
    int fromRow,
    int toCol,
    int toRow,
  ) {
    final fromFile = _colToFile(fromCol);
    final fromRank = 9 - fromRow;
    final toFile = _colToFile(toCol);
    final toRank = 9 - toRow;
    return '$fromFile$fromRank$toFile$toRank';
  }

  /// Convert UCI move string to ICCS format (col1row1col2row2).
  static String convertToICCS(String uciMove) {
    if (uciMove.length < 4) return uciMove;
    final fromCol = _fileToCol(uciMove[0]);
    final fromRank = int.tryParse(uciMove[1]) ?? 0;
    final toCol = _fileToCol(uciMove[2]);
    final toRank = int.tryParse(uciMove[3]) ?? 0;
    final fromRow = 9 - fromRank;
    final toRow = 9 - toRank;
    return '$fromCol$fromRow$toCol$toRow';
  }

  static String _colToFile(int col) {
    // col 0-8 -> file a-i
    return String.fromCharCode('a'.codeUnitAt(0) + col);
  }

  static int _fileToCol(String file) {
    final lower = file.toLowerCase();
    return lower.codeUnitAt(0) - 'a'.codeUnitAt(0);
  }

  // ---- Internal ----

  Future<void> _sendCommand(String command) async {
    if (!_isRunning || _process == null) {
      throw StateError('Engine is not running');
    }
    _stdinController.add(command);
  }

  Future<bool> _waitForPattern(String pattern, {Duration? timeout}) async {
    final completer = Completer<bool>();
    StreamSubscription<EngineEvent>? subscription;

    subscription = _eventController.stream.listen((event) {
      if (event is EngineRawLine && event.line.contains(pattern)) {
        completer.complete(true);
        subscription?.cancel();
      } else if (event is EngineError) {
        completer.complete(false);
        subscription?.cancel();
      }
    });

    // Timeout
    Future.delayed(timeout ?? const Duration(seconds: 10), () {
      if (!completer.isCompleted) {
        completer.complete(false);
        subscription?.cancel();
      }
    });

    try {
      return await completer.future;
    } catch (_) {
      return false;
    }
  }

  void _handleEngineOutput(String line) {
    _log('<< $line');
    _emitEvent(EngineRawLine(line));

    final trimmed = line.trim();
    if (trimmed.isEmpty) return;

    if (trimmed == 'uciok') {
      _emitEvent(EngineUCIOk());
    } else if (trimmed == 'readyok') {
      _isReady = true;
      _readyCompleter?.complete();
      _readyCompleter = null;
    } else if (trimmed.startsWith('id name ')) {
      _engineName = trimmed.substring(8).trim();
      _emitEvent(EngineInfoEvent.name(_engineName));
    } else if (trimmed.startsWith('id author ')) {
      _engineAuthor = trimmed.substring(10).trim();
      _emitEvent(EngineInfoEvent.author(_engineAuthor));
    } else if (trimmed.startsWith('option ')) {
      final option = _parseOption(trimmed);
      if (option != null) {
        _options[option.name] = option;
        _emitEvent(EngineInfoEvent.option(option));
      }
    } else if (trimmed.startsWith('bestmove')) {
      _parseBestMove(trimmed);
    } else if (trimmed.startsWith('info')) {
      _parseInfo(trimmed);
    } else if (trimmed.startsWith('info string')) {
      _log('Engine info string: ${trimmed.substring(11)}');
    }
  }

  void _parseBestMove(String line) {
    // "bestmove <move> [ponder <move>]"
    final parts = line.split(' ');
    if (parts.length >= 2) {
      final uciMove = parts[1];
      _bestMove = uciMove;
      _bestInfo = EngineInfo(
        depth: _bestInfo?.depth ?? 0,
        score: _bestInfo?.score ?? 0,
        isMate: _bestInfo?.isMate ?? false,
        pv: [uciMove],
        multipv: 1,
        nodes: _bestInfo?.nodes ?? 0,
        nps: _bestInfo?.nps ?? 0,
        timeMs: _bestInfo?.timeMs ?? 0,
      );

      // Convert to ICCS for the event
      final iccsMove = convertToICCS(uciMove);
      _emitEvent(EngineBestMove(iccsMove, uciMove: uciMove));

      // Complete the best move completer if waiting
      if (_bestMoveCompleter != null && !_bestMoveCompleter!.isCompleted) {
        _bestMoveCompleter!.complete(iccsMove);
        _bestMoveCompleter = null;
      }
    }
  }

  void _parseInfo(String line) {
    final info = _parseInfoLine(line);
    if (info == null) return;

    // Update current infos (replace same multipv entry)
    bool found = false;
    for (int i = 0; i < _currentInfos.length; i++) {
      if (_currentInfos[i].multipv == info.multipv) {
        _currentInfos[i] = info;
        found = true;
        break;
      }
    }
    if (!found) {
      _currentInfos.add(info);
    }

    // Sort by multipv
    _currentInfos.sort((a, b) => a.multipv.compareTo(b.multipv));

    // First PV line is the best
    if (_currentInfos.isNotEmpty) {
      _bestInfo = _currentInfos[0];
    }

    _emitEvent(EngineAnalysisUpdate(info, allInfos: List.from(_currentInfos)));
  }

  EngineInfo? _parseInfoLine(String line) {
    // Remove "info " prefix
    final content = line.substring(5);
    final tokens = content.split(' ');

    int depth = 0;
    int selDepth = 0;
    int multipv = 1;
    int score = 0;
    bool isMate = false;
    int nodes = 0;
    int nps = 0;
    int timeMs = 0;
    int hashfull = 0;
    int tbhits = 0;
    final pv = <String>[];

    String? currToken;
    bool inPV = false;
    bool expectingValue = false;

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];

      if (inPV) {
        if (token.startsWith('multipv') ||
            token.startsWith('depth') ||
            token.startsWith('score') ||
            token.startsWith('nodes') ||
            token.startsWith('nps') ||
            token.startsWith('time') ||
            token.startsWith('hashfull') ||
            token.startsWith('tbhits') ||
            token.startsWith('seldepth') ||
            token.startsWith('currmove') ||
            token.startsWith('currmovenumber') ||
            token.startsWith('string')) {
          inPV = false;
          // Re-process this token
          i--;
          continue;
        }
        pv.add(token);
        continue;
      }

      switch (token) {
        case 'depth':
          currToken = 'depth';
          expectingValue = true;
          break;
        case 'seldepth':
          currToken = 'seldepth';
          expectingValue = true;
          break;
        case 'time':
          currToken = 'time';
          expectingValue = true;
          break;
        case 'nodes':
          currToken = 'nodes';
          expectingValue = true;
          break;
        case 'nps':
          currToken = 'nps';
          expectingValue = true;
          break;
        case 'hashfull':
          currToken = 'hashfull';
          expectingValue = true;
          break;
        case 'tbhits':
          currToken = 'tbhits';
          expectingValue = true;
          break;
        case 'multipv':
          currToken = 'multipv';
          expectingValue = true;
          break;
        case 'score':
          currToken = 'score';
          expectingValue = true;
          break;
        case 'pv':
          inPV = true;
          currToken = null;
          expectingValue = false;
          break;
        case 'cp':
          if (currToken == 'score') {
            currToken = 'cp';
            expectingValue = true;
          }
          break;
        case 'mate':
          if (currToken == 'score') {
            currToken = 'mate';
            isMate = true;
            expectingValue = true;
          }
          break;
        default:
          if (expectingValue && currToken != null) {
            final value = int.tryParse(token);
            if (value != null) {
              switch (currToken) {
                case 'depth':
                  depth = value;
                  break;
                case 'seldepth':
                  selDepth = value;
                  break;
                case 'time':
                  timeMs = value;
                  break;
                case 'nodes':
                  nodes = value;
                  break;
                case 'nps':
                  nps = value;
                  break;
                case 'hashfull':
                  hashfull = value;
                  break;
                case 'tbhits':
                  tbhits = value;
                  break;
                case 'multipv':
                  multipv = value;
                  break;
                case 'cp':
                  score = value;
                  isMate = false;
                  break;
                case 'mate':
                  score = value;
                  isMate = true;
                  break;
              }
            }
            expectingValue = false;
            currToken = null;
          }
          break;
      }
    }

    if (depth == 0 && pv.isEmpty && !isMate) {
      return null;
    }

    return EngineInfo(
      depth: depth,
      selDepth: selDepth,
      score: score,
      isMate: isMate,
      pv: pv,
      multipv: multipv,
      nodes: nodes,
      nps: nps,
      timeMs: timeMs,
      hashfull: hashfull,
      tbhits: tbhits,
    );
  }

  UCIOption? _parseOption(String line) {
    // "option name <name> type <type> [default <default>] [min <min>] [max <max>] [var <var>]"
    final nameMatch = RegExp(r'name\s+(.+?)\s+type\s+').firstMatch(line);
    final typeMatch = RegExp(r'type\s+(\w+)').firstMatch(line);

    if (nameMatch == null || typeMatch == null) return null;

    final name = nameMatch.group(1)?.trim();
    final type = typeMatch.group(1);

    if (name == null || type == null) return null;

    final defaultMatch = RegExp(
      r'default\s+(.*?)(?:\s+min|\s+max|\s+var|$)',
    ).firstMatch(line);
    final minMatch = RegExp(r'min\s+(\-?\d+)').firstMatch(line);
    final maxMatch = RegExp(r'max\s+(\-?\d+)').firstMatch(line);

    return UCIOption(
      name: name,
      type: UCIOptionType.values.byName(type.toLowerCase()),
      defaultValue: defaultMatch?.group(1)?.trim(),
      min: int.tryParse(minMatch?.group(1) ?? ''),
      max: int.tryParse(maxMatch?.group(1) ?? ''),
    );
  }

  void _handleEngineExit() {
    _log('Engine process exited');
    _isRunning = false;
    _isReady = false;
    _emitEvent(EngineExited());

    // Complete any pending completers with error
    if (_bestMoveCompleter != null && !_bestMoveCompleter!.isCompleted) {
      _bestMoveCompleter!.completeError('Engine exited unexpectedly');
      _bestMoveCompleter = null;
    }
  }

  void _handleEngineError(dynamic error) {
    _log('Engine error: $error');
    _emitEvent(EngineError(error.toString()));
    _isRunning = false;
    _isReady = false;
  }

  void _emitEvent(EngineEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  void _log(String message) {
    if (logEnabled) {
      debugPrint('[UCIEngine] $message');
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

/// Engine has responded to "uci" command.
class EngineUCIOk extends EngineEvent {
  EngineUCIOk();
}

/// Engine has responded to "isready" command and is ready.
class EngineReady extends EngineEvent {
  EngineReady();
}

/// Engine sent a raw line output.
class EngineRawLine extends EngineEvent {
  EngineRawLine(this.line);
  final String line;
}

/// Engine info (name, author, option).
class EngineInfoEvent extends EngineEvent {
  EngineInfoEvent.name(this.name) : author = null, option = null;
  EngineInfoEvent.author(this.author) : name = null, option = null;
  EngineInfoEvent.option(this.option) : name = null, author = null;

  final String? name;
  final String? author;
  final UCIOption? option;
}

/// Engine analysis update with info line.
class EngineAnalysisUpdate extends EngineEvent {
  EngineAnalysisUpdate(this.info, {this.allInfos = const []});
  final EngineInfo info;
  final List<EngineInfo> allInfos;
}

/// Engine found the best move.
class EngineBestMove extends EngineEvent {
  EngineBestMove(this.iccsMove, {this.uciMove});
  final String iccsMove;
  final String? uciMove;
}

/// Engine process exited.
class EngineExited extends EngineEvent {
  EngineExited();
}

/// Engine error occurred.
class EngineError extends EngineEvent {
  EngineError(this.message);
  final String message;
}

/// Parsed engine info from "info" line.
class EngineInfo {
  const EngineInfo({
    required this.depth,
    this.selDepth = 0,
    required this.score,
    required this.isMate,
    required this.pv,
    this.multipv = 1,
    this.nodes = 0,
    this.nps = 0,
    this.timeMs = 0,
    this.hashfull = 0,
    this.tbhits = 0,
  });

  /// Search depth
  final int depth;

  /// Selective depth
  final int selDepth;

  /// Evaluation in centipawns (positive = side to move advantage)
  final int score;

  /// Whether the score is mate-in-N
  final bool isMate;

  /// Principal variation moves (UCI format)
  final List<String> pv;

  /// MultiPV index (1-based)
  final int multipv;

  /// Nodes searched
  final int nodes;

  /// Nodes per second
  final int nps;

  /// Time spent in milliseconds
  final int timeMs;

  /// Hash table fullness (per mille)
  final int hashfull;

  /// Tablebase hits
  final int tbhits;

  /// Convert score to the convention: positive = red advantage.
  /// The engine reports from the perspective of the side to move.
  int get adjustedScore => isMate ? score : score;

  /// Get the best move from the PV in ICCS format.
  String get bestMoveICCS {
    if (pv.isEmpty) return '';
    return UCIEngine.convertToICCS(pv.first);
  }

  /// Get the best move from the PV in UCI format.
  String get bestMoveUCI => pv.isNotEmpty ? pv.first : '';

  @override
  String toString() {
    final scoreStr = isMate ? 'M$score' : '$score';
    return 'EngineInfo(depth=$depth, score=$scoreStr, pv=${pv.take(3).join(" ")}, nps=$nps)';
  }
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
