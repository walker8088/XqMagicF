import 'package:flutter/foundation.dart';
import 'package:xqmagic/services/cloud_db.dart';
import 'package:xqmagic/services/engine_manager.dart';
import 'package:xqmagic/services/uci_engine.dart';

/// 分析服务：管理引擎分析和云库查询的触发
///
/// 负责：
/// - 触发引擎分析
/// - 触发云库查询
/// - 管理分析结果状态
/// - 提供分析结果给 UI 层
class AnalysisService extends ChangeNotifier {
  AnalysisService({
    required EngineManager engineManager,
    required CloudDBClient cloudDB,
  }) : _engineManager = engineManager,
       _cloudDB = cloudDB;

  final EngineManager _engineManager;
  final CloudDBClient _cloudDB;

  /// 云库查询结果
  CloudQueryResult? _cloudResult;
  CloudQueryResult? get cloudResult => _cloudResult;

  /// 是否正在查询云库
  bool _isCloudQuerying = false;
  bool get isCloudQuerying => _isCloudQuerying;

  // ──────────── 引擎分析结果代理 ────────────

  /// 获取当前最佳着法
  String? get engineBestMove => _engineManager.getCurrentBestMove();

  /// 获取当前评分
  int? get engineScore => _engineManager.getCurrentScore();

  /// 获取所有分析信息
  List<EngineInfo> get engineInfos => _engineManager.allInfos;

  /// 引擎是否正在思考
  bool get isEngineThinking => _engineManager.isThinking;

  /// 引擎是否就绪
  bool get isEngineReady => _engineManager.isReady;

  // ──────────── 云库缓存代理 ────────────

  /// 云库缓存大小
  int get cloudCacheSize => _cloudDB.cache.size;

  // ──────────── 分析触发方法 ────────────

  /// 触发位置分析（引擎 + 云库）
  void analyzePosition(String? fen) {
    if (fen == null) return;

    // 触发引擎分析
    _engineManager.analyze(fen: fen);

    // 触发云库查询
    _queryCloudForPosition(fen);
  }

  /// 触发云库查询
  void _queryCloudForPosition(String fen) {
    _isCloudQuerying = true;
    notifyListeners();

    _cloudDB
        .query(fen)
        .then((result) {
          _cloudResult = result;
          _isCloudQuerying = false;
          notifyListeners();
        })
        .catchError((error) {
          _isCloudQuerying = false;
          notifyListeners();
        });
  }

  /// 停止引擎分析
  Future<void> stopAnalysis() async {
    await _engineManager.cancelAnalysis();
    notifyListeners();
  }

  /// 清除分析结果
  void clearAnalysisResults() {
    _engineManager.clearAnalysisResults();
    _cloudResult = null;
    notifyListeners();
  }

  /// 清除云库查询结果
  void clearCloudResult() {
    _cloudResult = null;
    notifyListeners();
  }

  // ──────────── 云库查询方法 ────────────

  /// 手动触发云库查询
  Future<void> queryCloud(String fen) async {
    _isCloudQuerying = true;
    notifyListeners();

    try {
      _cloudResult = await _cloudDB.query(fen);
    } catch (e) {
      debugPrint('[AnalysisService] Cloud query failed: $e');
    } finally {
      _isCloudQuerying = false;
      notifyListeners();
    }
  }

  // ──────────── 状态重置 ────────────

  /// 重置分析服务状态
  void reset() {
    _cloudResult = null;
    _isCloudQuerying = false;
    notifyListeners();
  }
}
