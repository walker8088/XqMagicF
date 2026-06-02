import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:xqmagic/utils/app_logger.dart';
import 'package:xqmagic/utils/constants.dart';

/// 引擎单行输出处理函数
typedef _LineHandler = void Function(String line);

/// 引擎输出行的分派规则。
///
/// - [exact] = true 时要求与 [pattern] 完全匹配（例：`uciok`）
/// - [exact] = false 时要求以 [pattern] 开头（例：`info `）
class _LineRule {
  const _LineRule._(this.pattern, this.exact, this.handler);

  factory _LineRule.exact(String pattern, _LineHandler handler) =>
      _LineRule._(pattern, true, handler);

  factory _LineRule.startsWith(String pattern, _LineHandler handler) =>
      _LineRule._(pattern, false, handler);

  final String pattern;
  final bool exact;
  final _LineHandler handler;

  bool matches(String line) =>
      exact ? line == pattern : line.startsWith(pattern);
}

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
    this._enginePath,
    this.logEnabled = false,
    this._protocol = EngineProtocol.auto,
  });

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
  StreamSubscription<String>? _stdoutSubscription;
  StreamSubscription<String>? _stderrSubscription;
  Completer<String>? _bestMoveCompleter;
  Completer<void>? _stopCompleter;

  // Timeout defaults
  Duration _startupTimeout = const Duration(seconds: 30);

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

  // ---- Configuration ----

  void setStartupTimeout(Duration timeout) => _startupTimeout = timeout;

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
      await _startProcess(engineFile, absolutePath);
      _log('Engine process started (PID: ${_process!.pid})');

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
    await _stdoutSubscription?.cancel();
    _stdoutSubscription = null;
    await _stderrSubscription?.cancel();
    _stderrSubscription = null;
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

    _stdoutSubscription = _process!.stdout
        .transform(systemEncoding.decoder)
        .transform(const LineSplitter())
        .listen(
          _handleEngineOutput,
          onDone: _handleEngineExit,
          onError: _handleEngineError,
        );

    _stderrSubscription = _process!.stderr
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
    _log('position fen $fen');

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

    // 同步更新 _currentFen，确保 _fenToMoveColor 计算正确的 moveColor
    _currentFen = fen;

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

  /// 发送命令到引擎 stdin。所有调用方都 `await` 等待（约定俗成的 API 形状），
  /// 但实际实现是同步的（StreamController.add 是即时触发）—— 保留 async 关键字
  /// 以保持与现有 28 个 await 调用方兼容。未来如果引入真正的写入背压可改实现。
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

    // 兑底：超时定时器与事件到达路径都可能尝试 complete，必须检查 isCompleted
    // 避免重复 complete 报 `Bad state: Future already completed`
    timer = Timer(timeout, () {
      timer = null;
      sub.cancel();
      if (!completer.isCompleted) completer.complete(false);
    });

    sub = _eventController.stream.listen((event) {
      if (event is EngineRawLine && event.line.contains(pattern)) {
        timer?.cancel();
        timer = null;
        sub.cancel();
        if (!completer.isCompleted) completer.complete(true);
      }
    });

    return completer.future;
  }

  // 输出行分发表：按顺序匹配，第一个命中者处理。
  // 使用 late final + 函数引用，由于引用了实例方法不能设为 const。
  late final List<_LineRule> _lineRules = [
    _LineRule.exact('uciok', _onUciOk),
    _LineRule.startsWith('id name ', _onIdName),
    _LineRule.startsWith('id author ', _onIdAuthor),
    _LineRule.startsWith('option name ', _onOptionName),
    _LineRule.startsWith('bestmove ', _onBestMove),
    _LineRule.startsWith('info ', _onInfo),
  ];

  void _handleEngineOutput(String line) {
    _emitEvent(EngineRawLine(line));

    final trimmed = line.trim();
    if (trimmed.isEmpty) return;

    for (final rule in _lineRules) {
      if (rule.matches(trimmed)) {
        rule.handler(trimmed);
        return;
      }
    }
  }

  void _onUciOk(String line) {
    _emitEvent(EngineUCIOk());
  }

  void _onIdName(String line) {
    _engineName = line.substring('id name '.length).trim();
    _emitEvent(EngineInfoEvent(name: _engineName));
  }

  void _onIdAuthor(String line) {
    _engineAuthor = line.substring('id author '.length).trim();
    _emitEvent(EngineInfoEvent(author: _engineAuthor));
  }

  void _onOptionName(String line) {
    final option = _parseOption(line);
    if (option != null) {
      _options[option.name] = option;
      _emitEvent(EngineInfoEvent(option: option));
    }
  }

  void _onBestMove(String line) {
    _isAnalyzing = false;
    _parseBestMove(line);
    _bestMoveCompleter?.complete(_bestMove);
    _stopCompleter?.complete();
    _emitEvent(EngineBestMove(_bestMove ?? ''));
  }

  void _onInfo(String line) {
    final info = _parseInfo(line);
    if (info != null) {
      _currentInfos.add(info);
      _updateBestInfo(info);
      _emitEvent(EngineAnalysisUpdate(info, List.from(_currentInfos)));
    }
  }

  /// 维护主变着 (multipv=1) 中最新一条 _bestInfo。
  ///
  /// 原来的实现 _bestInfo 永远为 null（仅 newGame/analyze 中被重置为 null），
  /// 导致外部轮询 bestInfo!.pv.isNotEmpty 永远不会成立——属于死字段。
  /// 这里仅以 multipv=1 作为主变着信号，更新原则是“同深度下分数更高才覆盖”。
  void _updateBestInfo(EngineInfo info) {
    if (info.multipv != 1) return;
    final current = _bestInfo;
    // 冱度更大时无条件覆盖（深度优先）
    if (current == null || info.depth > current.depth) {
      _bestInfo = info;
      return;
    }
    // 同深度下，adjustedScore 更大才覆盖（红方视角）
    if (info.depth == current.depth &&
        info.adjustedScore > current.adjustedScore) {
      _bestInfo = info;
    }
  }

  void _parseBestMove(String line) {
    // bestmove h2e2 ponder h9g7
    final parts = line.split(' ');
    if (parts.length < 2) return;

    // 直接使用引擎原始输出，不做任何格式转换
    _bestMove = parts[1];
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
          // 直接使用引擎原始输出的 PV 着法，不做任何格式转换
          pv = parts.sublist(i + 1);
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
    // FEN 走子方：'w' = 红（white/red），'b' = 黑，'r' = 红（旧格式兼容）
    return parts[1].toLowerCase() == 'b' ? PieceColor.black : PieceColor.red;
  }

  UCIOption? _parseOption(String line) {
    // UCI 选项格式：
    //   option name <Name> type check [default <bool>]
    //   option name <Name> type spin  [default <n>] [min <n>] [max <n>]
    //   option name <Name> type string [default <text with spaces>]
    //   option name <Name> type combo [default <var>] [var <v1> [var <v2>] ...]
    //   option name <Name> type button
    //   option name <Name> type filename [default <text with spaces>]

    // 定位 "type" 关键字的下标—— name 可能含空格，但 type 以后是枚举值
    // 这样的逆向查找避免了 split(' ') 后的 i++ 走位
    final typeIdx = line.indexOf(' type ');
    if (typeIdx < 0) return null;
    final typeStart = typeIdx + 6; // " type " 长度

    // option name 的开头是固定的，取中间部分作为 name
    const prefix = 'option name ';
    if (!line.startsWith(prefix)) return null;
    final name = line.substring(prefix.length, typeIdx);

    // 从 type 之后扫描下一个空格作为 type 结束
    final tailStart = _skipChar(line, typeStart, ' ');
    if (tailStart >= line.length) return null;
    final typeEnd = line.indexOf(' ', tailStart);
    final typeStr = typeEnd < 0
        ? line.substring(tailStart)
        : line.substring(tailStart, typeEnd);

    UCIOptionType? type;
    String? defaultValue;
    int? min;
    int? max;

    switch (typeStr) {
      case 'check':
        type = UCIOptionType.check;
        final (val, _) = _consumeKeyValue(line, typeEnd, 'default');
        if (val != null) {
          defaultValue = val;
        } else {
          // UCI 规范中 `default` 必现，兑底是常见容错
          defaultValue = 'false';
        }
        break;
      case 'spin':
        type = UCIOptionType.spin;
        final (def, afterDefault) = _consumeKeyValue(line, typeEnd, 'default');
        defaultValue = def;
        final (lo, afterMin) = _consumeKeyValue(line, afterDefault, 'min');
        if (lo != null) min = int.tryParse(lo);
        final (hi, _) = _consumeKeyValue(line, afterMin, 'max');
        if (hi != null) max = int.tryParse(hi);
        break;
      case 'string':
        type = UCIOptionType.string;
        final (val, _) = _consumeKeyValueToEnd(line, typeEnd, 'default');
        defaultValue = val;
        break;
      case 'combo':
        type = UCIOptionType.combo;
        final (val, _) = _consumeKeyValue(line, typeEnd, 'default');
        defaultValue = val;
        // var <v1> [var <v2>] ... 暂不提取详细列表，需要可另行解析
        break;
      case 'button':
        type = UCIOptionType.button;
        break;
      case 'filename':
        type = UCIOptionType.filename;
        final (val, _) = _consumeKeyValueToEnd(line, typeEnd, 'default');
        defaultValue = val;
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

  /// 从 [startIdx] 开始跳过连续的 [ch]，返回跳过后的下标（可能 == length）
  static int _skipChar(String s, int startIdx, String ch) {
    var i = startIdx;
    while (i < s.length && s[i] == ch) {
      i++;
    }
    return i;
  }

  /// 从 [startIdx] 开始找 ` <key> ` 关键字，提取下一个空格分隔的值。
  /// 返回 (value, afterValue)——afterValue 是取值后的下标，可用于链式调用。
  /// 未找到时返回 (null, startIdx)。
  static (String?, int) _consumeKeyValue(
    String line,
    int startIdx,
    String key,
  ) {
    if (startIdx < 0 || startIdx >= line.length) return (null, startIdx);
    final keyIdx = line.indexOf(' $key ', startIdx);
    if (keyIdx < 0) return (null, startIdx);
    final valStart = keyIdx + key.length + 2; // " <key> " 长度
    if (valStart >= line.length) return (null, startIdx);
    final valEnd = line.indexOf(' ', valStart);
    final val = valEnd < 0
        ? line.substring(valStart)
        : line.substring(valStart, valEnd);
    return (val, valEnd < 0 ? line.length : valEnd);
  }

  /// 与 [_consumeKeyValue] 类似，但取值到行末（用于 string/filename 类型，
  /// 其 default 值可以含空格）。
  static (String?, int) _consumeKeyValueToEnd(
    String line,
    int startIdx,
    String key,
  ) {
    if (startIdx < 0 || startIdx >= line.length) return (null, startIdx);
    final keyIdx = line.indexOf(' $key ', startIdx);
    if (keyIdx < 0) return (null, startIdx);
    final valStart = keyIdx + key.length + 2;
    if (valStart >= line.length) return (null, startIdx);
    return (line.substring(valStart), line.length);
  }

  void _handleEngineExit() {
    _log('Engine process exited');
    _isRunning = false;
    _isReady = false;
    _isAnalyzing = false;

    // 兑底未完成的 Completer，避免调用方永久挂起
    // getBestMove 的调用者依赖 _bestMoveCompleter 完成来获取着法
    // stopAnalysis 的调用者依赖 _stopCompleter 完成
    if (_bestMoveCompleter != null && !_bestMoveCompleter!.isCompleted) {
      _bestMoveCompleter!.completeError(
        StateError('Engine exited before bestmove'),
      );
    }
    _bestMoveCompleter = null;
    if (_stopCompleter != null && !_stopCompleter!.isCompleted) {
      _stopCompleter!.completeError(
        StateError('Engine exited before stop acknowledged'),
      );
    }
    _stopCompleter = null;

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
    await _stdoutSubscription?.cancel();
    _stdoutSubscription = null;
    await _stderrSubscription?.cancel();
    _stderrSubscription = null;
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
    if (score == null) return 0;
    if (isMate) {
      // score > 0: side to move can mate (winning)
      // score < 0: side to move will be mated (losing)
      // Convert to red's perspective: preserve sign, then flip for black
      final mateScore = score!.abs();
      final signed = score! > 0 ? mateScore : -mateScore;
      return moveColor == PieceColor.black ? -signed : signed;
    }
    return moveColor == PieceColor.black ? -score! : score!;
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
