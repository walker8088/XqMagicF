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

  /// 云库查询完成回调（用于通知 UI 刷新）
  Function()? onCloudResultUpdated;

  /// 是否正在查询云库
  bool get isCloudQuerying => _isCloudQuerying;
  bool _isCloudQuerying = false;

  /// 云库查询代次（用于丢弃过期结果）
  int _cloudQueryGeneration = 0;

  /// 分析开始时的节点引用（用于防止导航竞争写入错误节点）
  GameTreeNode? _analysisTargetNode;

  // ──────────── 分析触发 ────────────

  /// 在走子/导航后触发分析
  ///
  /// [fen] 当前局面的 FEN
  /// [currentNode] 当前的 GameTreeNode（用于写入分析结果）
  void onPositionChanged(String fen, GameTreeNode? currentNode) {
    _analysisTargetNode = currentNode; // 记录分析目标节点
    _engineManager.analyze(fen: fen);
    _queryCloud(fen);
  }

  // ──────────── 云库查询 ────────────

  Future<void> _queryCloud(String fen) async {
    _isCloudQuerying = true;
    final generation = ++_cloudQueryGeneration;

    try {
      final result = await _cloudDB.query(fen);
      // 仅当代次匹配时才更新（丢弃过期查询结果）
      if (generation == _cloudQueryGeneration) {
        cloudResult = result;
      }
    } catch (e) {
      _log('Cloud query failed: $e');
    } finally {
      if (generation == _cloudQueryGeneration) {
        _isCloudQuerying = false;
      }
      onCloudResultUpdated?.call();
    }
  }

  /// 手动触发云库查询
  ///
  /// 复用 [_queryCloud] 的 generation 保护逻辑，避免快速连续调用时
  /// 过期结果覆盖最新结果。
  Future<void> queryCloud(String fen) async {
    await _queryCloud(fen);
  }

  /// 清除云库查询结果
  void clearCloudResult() {
    cloudResult = null;
  }

  // ──────────── 分析结果写入 ────────────

  /// 将引擎分析结果写入分析开始时的目标节点
  ///
  /// 在 _onAnalysisChanged 中调用。
  /// 使用 [_analysisTargetNode] 而非当前节点，防止用户导航后
  /// 将旧位置的分析结果写入新位置节点。
  void writeAnalysisToNode() {
    final targetNode = _analysisTargetNode;
    if (targetNode == null) return;

    // 保存引擎评分到目标节点
    final score = _engineManager.getCurrentScore();
    if (score != null) {
      targetNode.evaluation = score;
    }

    // 保存引擎最佳着法
    final best = _engineManager.getCurrentBestMove();
    if (best != null) {
      targetNode.engineBestMove = best;
    }

    // 评估着法质量（需要父节点有评分 + 当前节点有走法）
    if (targetNode.parent != null &&
        targetNode.move != null &&
        targetNode.moveAnnotation == null) {
      MoveQualityAssessor.assess(targetNode);
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
