import 'package:xqmagic/models/game_tree.dart';
import 'package:xqmagic/services/cloud_db.dart';
import 'package:xqmagic/services/engine.dart';
import 'package:xqmagic/services/engine_manager.dart';
import 'package:xqmagic/utils/app_logger.dart';
import 'package:xqmagic/utils/move_quality_assessor.dart';

/// 局面分析服务：触发引擎分析 + 云库查询
///
/// 从 GameViewModel 中提取，职责单一：
/// - 在走子/导航后触发引擎分析
/// - 触发云库查询
/// - 将分析结果写入 GameTreeNode
///
/// 不负责：
/// - 引擎生命周期管理（由 EngineManager 负责）
/// - 走子执行（由 GameController 负责）
/// - UI 交互状态（由 GameStateManager 负责）
class AnalysisService {
  AnalysisService({
    required this._engineManager,
    required this._cloudDB,
    this.logEnabled = false,
  });

  final EngineManager _engineManager;
  final CloudDBClient _cloudDB;
  final bool logEnabled;

  /// 云库查询结果（可由外部读取）
  CloudQueryResult? cloudResult;

  /// 是否正在查询云库
  bool get isCloudQuerying => _isCloudQuerying;
  bool _isCloudQuerying = false;

  // ──────────── 分析触发 ────────────

  /// 在走子/导航后触发分析
  ///
  /// [fen] 当前局面的 FEN
  /// [currentNode] 当前的 GameTreeNode（用于写入分析结果）
  void onPositionChanged(String fen, GameTreeNode? currentNode) {
    _engineManager.analyze(fen: fen);
    _queryCloud(fen);
  }

  // ──────────── 云库查询 ────────────

  void _queryCloud(String fen) {
    _isCloudQuerying = true;

    _cloudDB
        .query(fen)
        .then((result) {
          cloudResult = result;
          _isCloudQuerying = false;
        })
        .catchError((error) {
          _isCloudQuerying = false;
        });
  }

  /// 手动触发云库查询
  Future<void> queryCloud(String fen) async {
    _isCloudQuerying = true;

    try {
      cloudResult = await _cloudDB.query(fen);
    } catch (e) {
      _log('Cloud query failed: $e');
    } finally {
      _isCloudQuerying = false;
    }
  }

  /// 清除云库查询结果
  void clearCloudResult() {
    cloudResult = null;
  }

  // ──────────── 分析结果写入 ────────────

  /// 将引擎分析结果写入当前节点
  ///
  /// 在 _onAnalysisChanged 中调用。
  /// [currentNode] 当前 GameTreeNode（走子后的节点）
  void writeAnalysisToNode(GameTreeNode? currentNode) {
    if (currentNode == null) return;

    // 保存引擎评分到当前节点
    final score = _engineManager.getCurrentScore();
    if (score != null) {
      currentNode.evaluation = score;
    }

    // 保存引擎最佳着法
    final best = _engineManager.getCurrentBestMove();
    if (best != null) {
      currentNode.engineBestMove = best;
    }

    // 评估着法质量（需要父节点有评分 + 当前节点有走法）
    if (currentNode.parent != null &&
        currentNode.move != null &&
        currentNode.moveAnnotation == null) {
      MoveQualityAssessor.assess(currentNode);
    }
  }

  // ──────────── 引擎状态访问 ────────────

  bool get isAnalyzing => _engineManager.isAnalyzing;
  String? get bestMove => _engineManager.getCurrentBestMove();
  int? get score => _engineManager.getCurrentScore();
  List<EngineInfo> get engineInfos => _engineManager.allInfos;

  // ──────────── 分析控制 ────────────

  Future<void> stopAnalysis() async {
    await _engineManager.cancelAnalysis();
  }

  void clearAnalysisResults() {
    _engineManager.clearAnalysisResults();
    cloudResult = null;
  }

  // ──────────── 云库缓存 ────────────

  int get cloudCacheSize => _cloudDB.cache.size;

  void _log(String message) {
    if (logEnabled) {
      AppLogger.debug('AnalysisService', message);
    }
  }
}
