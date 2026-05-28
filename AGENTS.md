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
- `PVChineseConverter.singleMove()` 
- `PVChineseConverter.pvLine()`

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
- 走子方：`r` = 红，`b` = 黑

---

## Board 内部约定

- `row 0` = 红方底线（棋盘底部）、`row 9` = 黑方底线（棋盘顶部）
- `col 0` = 最左列（红方九路）、`col 8` = 最右列（红方一路）

## 禁止事项

- ❌ 不要做 `9 - row` 或 `9 - rank` 转换（除非是 `ChineseNotation.normalizeCoord` 的黑方视角旋转）
- ❌ 不要把 FEN 行序和内部 row 混淆（FEN 从上到下，内部从上到下的 row 9→0）
- ❌ 不要让外部参数覆盖记谱颜色，应读取棋盘上棋子的实际颜色
