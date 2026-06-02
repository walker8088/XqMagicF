# XqMagicF 修复清单

## 🔴 高优先级

- [x] #1 `GameViewModel` 未实现 `dispose()`，子模块 listener 未移除，引擎进程泄漏 ✅
- [x] #2 `_queryCloud()` 竞态条件，`_isCloudQuerying` 异常时可能卡为 true ✅
- [x] #3 `_engineTime` 永远不生效，UI 有选择但未保存/同步 ✅
- [x] #4 `Engine._handshake()` auto 模式重启后 stdout/stderr listener 重复注册 ✅
- [x] #5 兵卒过河后允许后退，违反中国象棋规则 ✅
- [x] #6 `soundEnabled` 双重存储不同步，设置关闭音效不影响实际播放 ✅

## 🟠 中优先级

- [x] #7 缺少困毙（stalemate）判断，`GameState.draw` 从未使用 ✅
- [x] #8 `EngineManager.dispose()` 中 `await _cleanupEngine()` 在同步方法中 ✅
- [x] #9 `ChessBoardPainter.shouldRepaint()` 只比较 `inCheckPosition` ✅
- [x] #10 `_lastShowLeft` 初始化为 `false` 但实际左面板初始可见 ✅
- [x] #11 PV 模拟走子时 `piece.coord` 未更新 ✅
- [x] #12 `getWithStats()` 用 `value != null` 判断命中，统计错误；统计代码从未调用 ✅
- [ ] #13 `_dropdown<T>()` 方法在 game_screen 和 engine_control_panel 完全重复
- [ ] #14 `_getMultiPiecePrefixFromRed()` 与 `_getWXFMultiPiecePrefixFromRed()` 逻辑重复
- [ ] #15 棋子中文名不一致：PieceTypeExtension 用繁体，记谱用简体
- [x] #16 将军/胜负音效从未触发 ✅
- [x] #17 `CloudQueryResult.parseResponse` 的 `moveColor` 参数从未使用 ✅
- [x] #18 4 个 analyze 方法重复约 40 行相同的前置检查代码 ✅

## 🟡 低优先级

- [x] #19 `GameState.idle` 和 `GameState.draw` 从未使用 ✅
- [x] #20 `GameMode.engineOnline` 未实现 ✅
- [x] #21 `_levelTag()` 未使用，`_write()` 硬编码字符 ✅
- [x] #22 `newGame()` 与 `reset()` 功能重复 ✅
- [x] #23 3 个 `with*()` 方法手动拷贝所有字段，改用 `copyWith()` ✅
- [x] #24 `Engine.start()` 与 `_startProcess()` 代码重复 ✅
- [x] #25 FEN 走子方 `w`/`b` 与 `r` 兼容性不一致 ✅
- [x] #26 兵卒过河后退测试期望 `isTrue`（配合 #5 bug） ✅
- [x] #27 兵卒后退记谱测试（非法走法） ✅
- [x] #28 engine_test 用 `return` 静默跳过测试而非 `markAsSkip` ✅
- [x] #29 lru_cache 空值测试无断言 ✅
- [x] #30 `unrelated_type_equality_checks` 误报加 ignore 注释 ✅
