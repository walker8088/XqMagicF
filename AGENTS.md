# XqMagicF 项目记忆

## 坐标系约定

### 三种坐标系统

| 系统 | `0` | `9` | 用途 |
|------|-----|-----|------|
| **内部 Board row** | 红方底线（底部） | 黑方底线（顶部） | 全代码库内部表示 |
| **ICCS rank** | 红方底线（底部） | 黑方底线（顶部） | 同内部 row，直接相等 |
| **FEN 行序** | 最后一段（底部） | 第一段（顶部） | FEN 从上到下=row9→row0 |

### Pikafish 引擎约定（已验证）

引擎测试输出：`bestmove h2e2`（初始局面红方炮二平五）
- 红炮在 col=7, row=2 → 引擎输出 rank=2 → **与 ICCS 一致**
- **关键结论：Pikafish 引擎输出与 ICCS rank 相同，与内部 row 相同，无需 `9-row` 转换**

### 中国记谱法的视角旋转（与 ICCS 无关）

`ChineseNotation.normalizeCoord()`：
- 仅黑方走棋时：`col' = 8 - col, row' = 9 - row`
- 用途：黑方记谱按传统习惯显示（马８进７ 而不是 马2进3）
- **不是 ICCS 转换**

---

## ICCS ↔ 内部坐标转换

**唯一入口**：`lib/utils/move_notation.dart` 的 `MoveNotation`

```dart
// toICCS: row 直接作为 rank
fromRank = move.from.row;

// fromICCS: rank 直接作为 row
fromRow = int.parse(iccs[1]);
```

**无转换，直接相等**。

---

## 记谱显示修复（重要！）

### Bug：`formatMoveDisplay` 用外部传入的 color 而非棋子实际颜色

```dart
// ❌ 旧代码：外部传什么 color 就用什么
MoveRecord(..., color: color, ...)

// ✅ 新代码：从棋盘取棋子的实际颜色
MoveRecord(..., color: piece.color, ...)
```

同样修复了：
- `PVChineseConverter.singleMove()` （已删除，功能由 `MoveNotation.formatMoveDisplay` 覆盖）
- `PVChineseConverter.pvLine()` （已删除，无外部调用方）

### Bug：分析面板 pvLines 为空时 bestColor 默认 Red

```dart
// ❌ 旧代码：pvLine 为 null → bestColor 永远 = Red
final bestColor = pvLine?.isRedToMove == false ? Black : Red;

// ✅ 新代码：pvLine 为 null → fallback 到 activeColor
final bestColor = pvLine != null
    ? (pvLine.isRedToMove ? Red : Black)
    : activeColor ?? Red;
```

### FEN 格式

- 行序：从上到下（FEN row 0 = 黑方底线 = 内部 row 9）
- 棋子：大写=红方，小写=黑方
- 走子方：`w` = 红（white/red），`b` = 黑
- 开局库内部 key 统一使用 `w`/`b`（与 UCI 标准一致）；`_normalizeFen` 将旧式 `r` 归一化为 `w`

---

## Board 内部约定

- `row 0` = 红方底线（棋盘底部）、`row 9` = 黑方底线（棋盘顶部）
- `col 0` = 最左列（红方九路）、`col 8` = 最右列（红方一路）

---

## 禁止事项

- ❌ 不要做 `9 - row` 或 `9 - rank` 转换（除非是 `ChineseNotation.normalizeCoord` 的黑方视角旋转）
- ❌ 不要把 FEN 行序和内部 row 混淆（FEN 从上到下，内部从上到下的 row 9→0）
- ❌ 不要让外部参数覆盖记谱颜色，应读取棋盘上棋子的实际颜色

---

## GameTree 行为契约（重要！）

- `makeMove` 永远**不**截断已有分支：
  - 当前节点**无** mainLine 续走（典型：主变着末端走子）→ 走子作为 mainLine
  - 当前节点**已有** mainLine 续走（典型：用户后退再走新棋）→ 走子自动作为 variation
- `makeVariation` 永远**不**截断已有分支，纯追加
- 强制覆盖 mainLine：调用方须显式 `_current.clearChildren()` 后再 `makeMove`
- **历史背景**：旧实现两个方法都 `clearChildren()`，导致"用户后退走变着"会静默删除主变着分支，已修复

---

## 类结构

### lib/game

| 文件 | 类 | 职责 |
|------|-----|------|
| `game_controller.dart` | `GameController` | 走子入口（手动/引擎）、导航（前进/后退）、游戏状态切换。依赖 `GameEngine`、`GameTree`、`EngineManager`，不负责分析触发 |
| `game_engine.dart` | `GameEngine` | 棋盘状态管理、合法走法生成、胜负判定、FEN 序列化。依赖 `Board`、`MoveValidator` |
| `game_state_manager.dart` | `GameStateManager` | UI 状态：棋子选中、可行走位置、最佳着法提示、残局状态、面板可见性 |
| `move_validator.dart` | `MoveValidator` | 走棋规则验证：将军、将帅对面、蹩腿、各棋子走法（纯静态方法） |
| `analysis_service.dart` | `AnalysisService` | 触发引擎分析 + 云库查询。依赖 `EngineManager`、`CloudDBClient` |

### lib/models

| 文件 | 类/Enum | 职责 |
|------|---------|------|
| `board.dart` | `Board` | 棋盘状态：二维数组存储 FEN 字符，棋子增删改查 |
| `chess_piece.dart` | `ChessPiece` | 棋子模型：type、color、coord |
| `move.dart` | `MoveRecord` | 走步记录：from、to、pieceType、capturedPiece、color、notation、nextColor、boardBefore/After、fenBefore/After |
| `game_tree.dart` | `GameTreeNode` | 棋谱树节点：fen、move、parent、children、comment、evaluation、moveAnnotation、cloudBestMove |
| | `GameTree` | 棋谱树管理：root/current 指针，主变着/变着，新增/导航 |
| `game_state.dart` | `GameState` | enum: `idle`、`playing`、`checkmate`、`draw` |
| `game_mode.dart` | `GameMode` | enum: `free`、`engineFight`、`engineEndGame`、`engineOnline` |
| | `EngineAnalysisMode` | enum: `quick`、`deep`、`fight`（含 depth/timeMs） |
| | `PriorityMode` | enum: `cloud`、`engine` |
| `board_render_data.dart` | `BoardRenderData` | 棋盘渲染数据纯类：pieces、selectedPosition、possibleMoves、lastMove、inCheckPosition |
| `panel_type.dart` | `PanelType` | enum: `cloud`、`none`（替代魔法字符串） |

### lib/services

| 文件 | 类 | 职责 |
|------|-----|------|
| `engine.dart` | `Engine` | UCI/UCCI 引擎进程通信：stdin/stdout、命令发送、事件流。状态：`isRunning/isReady/isAnalyzing` |
| | `EngineEvent` | sealed class: `EngineReady`、`EngineBestMove`、`EngineAnalysisUpdate`、`EngineInfoEvent`、`EngineExited`、`EngineError`、`EngineUCIOk`、`EngineRawLine` |
| | `EngineInfo` | 分析信息：depth、selDepth、score、isMate、pv、nodes、nps、timeMs、moveColor、multipv |
| | `UCIOption`、`UCIOptionType` | 引擎选项数据结构 |
| | `EngineProtocol` | enum: `uci`、`ucci` |
| `engine_manager.dart` | `EngineManager` | 引擎生命周期：加载/启动/重启 UCI 引擎，发送分析命令，事件订阅。状态机：`idle→loading→ready↔thinking/error` |
| `engine_configuration.dart` | `EngineConfiguration` | 引擎配置：depth、timeMs、threads、hash、MultiPV、自定义选项（ChangeNotifier） |
| `cloud_db.dart` | `CloudDBClient` | 云端棋库客户端（chessdb.cn）：HTTP 查询、LRU 缓存、结果解析。`query()` 返回 `CloudQueryResult?` |
| | `CloudQueryResult` | 云库查询结果：moves、bestMove、bestScore、isCache |
| | `CloudMoveInfo` | 云库着法信息：iccs、score、winRate、frequency、diff |
| `pgn_service.dart` | `PGNService` | PGN 格式读写：parse、write、splitGames、buildGameTree |
| | `GameRecord`、`PGNParseError`、`PGNParseResult` | PGN 数据结构 |
| | `GameResult` | enum: 红胜/黑胜/和棋/未知 |
| `opening_book.dart` | `OpeningBookService` | 开局库服务：Ecco 编号开局信息、lookup、FEN 缓存（单例） |
| | `OpeningInfo`、`OpeningMove`、`EccoEntry` | 开局信息、着法、Ecco 编号条目 |
| | `OpeningSource` | enum: 开局来源 |
| | `CacheStats` | 缓存统计 |
| `local_db.dart` | `BookmarkService` | 书签服务：add/remove/update/getAll（单例） |
| | `GameRecordService` | 游戏记录服务：save/load/delete（单例） |
| | `RecentFilesService` | 最近文件服务（单例） |
| | `Bookmark`、`GameMetadata`、`SavedGame`、`RecentFileEntry` | 本地存储数据模型 |

### lib/utils

| 文件 | 类 | 职责 |
|------|-----|------|
| `constants.dart` | `AppConstants` | 棋盘尺寸、颜色、字体、楚河汉界文字 |
| | `PieceColor` | enum: `red`、`black` |
| | `PieceType` | enum: `king`、`advisor`、`bishop`、`knight`、`rook`、`cannon`、`pawn` |
| | `PieceTypeExtension` | `displayName(color)` 扩展方法（简繁体） |
| `coord.dart` | `Coord` | 坐标：col（0-8）、row（0-9），含 `colToFile`/`fileToCol` 静态方法 |
| `fen.dart` | `FenParser` | FEN 解析/生成：`parse`、`generate`、`generateHash`。FEN row 0 = 内部 row 9（顶部黑方底线） |
| `move_notation.dart` | `MoveNotation` | **ICCS ↔ 内部坐标唯一入口**：`toICCS`、`fromICCS`（rank = row，无转换）；`formatMoveDisplay`（用棋子实际颜色）；`toText`/`toWXF` 委托给 ChineseNotation |
| | `MoveQuality` | 着法质量标注辅助类（best/good/ok/bad 阈值） |
| `chinese_notation.dart` | `ChineseNotation` | 中文记谱核心：`toText`（黑方走子时 normalizeCoord 旋转视角）、`toWXF`、`fromWXF`、`normalizeCoord`（仅黑方 `col'=8-col, row'=9-row`） |
| `move_quality_assessor.dart` | `MoveQualityAssessor` | 着法质量评估：比较实际走法与引擎推荐（静态方法 `assess(node)` ） |
| `app_settings.dart` | `AppSettings` | 应用设置持久化：boardScale、engineDepth、multiPV、enginePath 等（单例，JSON 文件） |
| `sound_manager.dart` | `SoundManager` | 音效管理：走子、吃子、将军、胜负音效（单例，自带默认蜂鸣 WAV） |
| `storage_service.dart` | `StorageService` | 统一持久化存储服务（基于 `path_provider`） |
| `lru_cache.dart` | `LRUCache<K,V>` | LRU 缓存：云库查询结果缓存，含命中率统计 |
| `app_logger.dart` | `AppLogger` | 统一日志管理：debug/info/warn/error，可选文件输出 |
| `data/endgame_puzzles.dart` | `EndgamePuzzle`、`EndgameCollection` | 残局谜题数据（位于 `lib/data/`，**不是** `lib/utils/data/`） |

### lib/viewmodels

| 文件 | 类 | 职责 |
|------|-----|------|
| `game_viewmodel.dart` | `GameViewModel` | **核心协调器**（继承 `ChangeNotifier`）：协调 `GameController`、`GameStateManager`、`EngineManager`、`AnalysisService`。`_init()` 创建所有 Manager；`selectPiece` 入口处理走子/残局；`_onMoveExecuted` 触发分析；`_onAnalysisChanged` 保存评分和最佳着法 |

### lib/screens

| 文件 | 类 |
|------|-----|
| `game_screen.dart` | `GameScreen` — 游戏主界面（MultiSplitView 分栏） |
| `menu_screen.dart` | `MenuScreen` — 菜单界面 |
| `pgn_dialog.dart` | `PGNDialog` — PGN 导入/导出对话框 |
| `settings_dialog.dart` | `SettingsDialog` — 设置对话框 |

### lib/widgets

| 目录 | 文件 | 类 |
|------|------|-----|
| `widgets/board/` | `chess_board.dart` | `ChessBoard` — 棋盘 Widget（依赖 `GameViewModel`） |
| | `chess_board_painter.dart` | `ChessBoardPainter` — CustomPainter 绘制棋盘 |
| `widgets/common/` | `analysis_panel.dart` | `AnalysisPanel`、`LiveAnalysisPanel`、`EnginePVLine`、`ScoreDisplay`、`CloudMoveList` |
| | `move_history_panel.dart` | `MoveHistoryPanel` — 着法历史面板 |
| | `engine_control_panel.dart` | `EngineControlPanel` — 引擎控制面板 |
| | `opening_browser.dart` | `OpeningBrowser` — 开局库浏览器 |
| | `bookmark_panel.dart` | `BookmarkPanel` — 书签面板 |
| | `game_library_panel.dart` | `GameLibraryPanel` — 游戏库面板 |
| | `game_status_bar.dart` | `GameStatusBar` — 状态栏 |
| | `navigation_toolbar.dart` | `NavigationToolbar`、`ModeSelector` — 导航工具栏 |
| | `review_shared.dart` | 复盘共享组件 |
| `widgets/piece/` | （棋子渲染相关） | 棋子图标组件 |

### lib/

| 文件 | 用途 |
|------|------|
| `main.dart` | 入口：`WidgetsFlutterBinding.ensureInitialized()` → `AppSettings.init()` → `runApp(ChessApp)` |

---

## 关键关系

```
GameViewModel（协调器，ChangeNotifier）
├── GameController
│   ├── GameEngine (棋盘状态 + 局面查询)
│   │   └── MoveValidator (走法规则验证，静态)
│   └── GameTree (棋谱树，root/current 指针)
├── GameStateManager (UI 交互状态，ChangeNotifier)
├── AnalysisService
│   ├── EngineManager (引擎生命周期，ChangeNotifier)
│   │   ├── EngineConfiguration (纯配置参数，ChangeNotifier)
│   │   └── Engine (进程 + UCI/UCCI)
│   └── CloudDBClient (HTTP + LRU 缓存)
└── EngineManager (同前述，单例级 ChangeNotifier)

MoveNotation ← ICCS 坐标转换唯一入口
ChineseNotation ← 中文记谱核心算法（含黑方视角旋转）
MoveQualityAssessor ← 着法质量评估（基于引擎评分变化）
```

---

## 待清理项

- `lib/data/endgame_puzzles.dart` 数据有严重 bug（纯数字假 ICCS、将帅对面 FEN、`r` 走子方），需改为从文件加载并重写数据
- `GameMode.engineOnline` 和菜单
