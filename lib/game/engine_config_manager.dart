import 'package:flutter/foundation.dart';
import 'package:xqmagic/models/game_mode.dart';
import 'package:xqmagic/services/engine_manager.dart';
import 'package:xqmagic/services/uci_engine.dart';
import 'package:xqmagic/utils/app_settings.dart';

/// 引擎配置管理器：管理引擎的加载、配置和分析模式
///
/// 负责管理：
/// - 引擎加载/卸载
/// - 分析模式配置
/// - MultiPV 配置
/// - 引擎参数同步
class EngineConfigManager extends ChangeNotifier {
  EngineConfigManager(this._engineManager);

  final EngineManager _engineManager;

  /// 引擎分析模式
  EngineAnalysisMode _analysisMode = EngineAnalysisMode.deep;
  EngineAnalysisMode get analysisMode => _analysisMode;

  /// 优先级模式
  PriorityMode _priorityMode = PriorityMode.engine;
  PriorityMode get priorityMode => _priorityMode;

  /// MultiPV 数量
  int _multiPV = 1;
  int get multiPV => _multiPV;

  /// 是否正在分析
  bool _isAnalyzing = false;
  bool get isAnalyzing => _isAnalyzing;

  // ──────────── 引擎状态代理 ────────────

  /// 引擎是否就绪
  bool get isEngineReady => _engineManager.isReady;

  /// 引擎是否正在思考
  bool get isEngineThinking => _engineManager.isThinking;

  /// 引擎名称
  String get engineName => _engineManager.engineName;

  /// 引擎错误信息
  String? get engineError => _engineManager.error;

  // ──────────── 分析结果代理 ────────────

  /// 获取当前最佳着法
  String? get engineBestMove => _engineManager.getCurrentBestMove();

  /// 获取当前评分
  int? get engineScore => _engineManager.getCurrentScore();

  /// 获取所有分析信息
  List<EngineInfo> get engineInfos => _engineManager.allInfos;

  // ──────────── 引擎管理方法 ────────────

  /// 加载引擎
  Future<bool> loadEngine(String enginePath) async {
    _engineManager.setProtocol(AppSettings.instance.engineProtocol);
    final success = await _engineManager.loadEngine(enginePath: enginePath);
    if (success) {
      _engineManager.setDepth(_analysisMode.depth);
      _engineManager.setTimeMs(_analysisMode.timeMs);
      _engineManager.setMultiPV(_multiPV);
    }
    notifyListeners();
    return success;
  }

  /// 卸载引擎
  Future<void> unloadEngine() async {
    _isAnalyzing = false;
    await _engineManager.unloadEngine();
    notifyListeners();
  }

  /// 同步设置到引擎
  Future<void> syncSettingsToEngine() async {
    final settings = AppSettings.instance;
    _engineManager.setProtocol(settings.engineProtocol);
    _engineManager.setDepth(settings.engineDepth);
    _engineManager.setThreads(settings.engineThreads);
    _engineManager.setHash(settings.engineHash);
    _engineManager.setSkillLevel(settings.engineSkillLevel);
    _engineManager.setMultiPV(settings.multiPV);
    await _engineManager.applyConfiguration();
    notifyListeners();
  }

  // ──────────── 分析模式配置 ────────────

  /// 设置分析模式
  void setAnalysisMode(EngineAnalysisMode mode) {
    _analysisMode = mode;
    notifyListeners();
  }

  /// 设置优先级模式
  void setPriorityMode(PriorityMode mode) {
    _priorityMode = mode;
    notifyListeners();
  }

  /// 设置 MultiPV 数量
  void setMultiPV(int count) {
    if (count < 1) return;
    _multiPV = count;
    _engineManager.setMultiPV(count);
    notifyListeners();
  }

  /// 设置分析状态
  void setAnalyzing(bool analyzing) {
    _isAnalyzing = analyzing;
    notifyListeners();
  }

  // ──────────── 引擎操作代理 ────────────

  /// 开始分析
  Future<void> startAnalysis(String fen) async {
    _isAnalyzing = true;
    notifyListeners();
    await _engineManager.analyze(fen: fen);
  }

  /// 停止分析
  Future<void> stopAnalysis() async {
    _isAnalyzing = false;
    await _engineManager.cancelAnalysis();
    notifyListeners();
  }

  /// 清除分析结果
  void clearAnalysisResults() {
    _engineManager.clearAnalysisResults();
    notifyListeners();
  }

  /// 新局
  Future<void> newGame() async {
    _isAnalyzing = false;
    await _engineManager.newGame();
    notifyListeners();
  }

  // ──────────── 状态重置 ────────────

  /// 重置配置状态
  void reset() {
    _analysisMode = EngineAnalysisMode.deep;
    _priorityMode = PriorityMode.engine;
    _multiPV = 1;
    _isAnalyzing = false;
    notifyListeners();
  }
}
