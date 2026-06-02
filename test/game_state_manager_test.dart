import 'package:flutter_test/flutter_test.dart';
import 'package:xqmagic/game/game_state_manager.dart';
import 'package:xqmagic/models/panel_type.dart';
import 'package:xqmagic/utils/coord.dart';

void main() {
  group('GameStateManager - 批量通知', () {
    test('withBatchNotify 内多次 setter 只触发一次通知', () {
      final state = GameStateManager();
      var notifyCount = 0;
      state.addListener(() => notifyCount++);

      state.withBatchNotify(() {
        state.selectPosition(const Coord(0, 0));
        state.setPossibleMoves([const Coord(1, 1), const Coord(2, 2)]);
        state.setBestMoveHint('h2e2');
      });

      expect(notifyCount, 1);
      expect(state.selectedPosition, const Coord(0, 0));
      expect(state.possibleMoves.length, 2);
      expect(state.bestMoveHint, 'h2e2');
    });

    test('withBatchNotify 嵌套调用安全（仅最外层退出时通知）', () {
      final state = GameStateManager();
      var notifyCount = 0;
      state.addListener(() => notifyCount++);

      state.withBatchNotify(() {
        state.selectPosition(const Coord(0, 0));
        state.withBatchNotify(() {
          state.setPossibleMoves([const Coord(1, 1)]);
          state.setBestMoveHint('h2e2');
        });
        // 内层退出后不应触发
        state.setBestMoveHint('c3c4');
      });

      // 外层退出时统一触发
      expect(notifyCount, 1);
    });

    test('withBatchNotify 内部抛异常仍能正确退出批处理', () {
      final state = GameStateManager();
      var notifyCount = 0;
      state.addListener(() => notifyCount++);

      expect(
        () => state.withBatchNotify(() {
          state.selectPosition(const Coord(0, 0));
          throw StateError('oops');
        }),
        throwsA(isA<StateError>()),
      );

      // 设计选择：异常路径会 flush pending notify（部分状态变更已发生），
      // 后续 setter 还会再触发一次——总计 2 次。
      // 更重要的是：批处理应被清理，后续调用不会静默丢通知。
      state.setBestMoveHint('h2e2');
      expect(notifyCount, 2);
    });

    test('withBatchNotify 内无 setter 不会产生无意义的通知', () {
      final state = GameStateManager();
      var notifyCount = 0;
      state.addListener(() => notifyCount++);

      state.withBatchNotify(() {
        // 仅读取、不写入
        state.selectedPosition;
        state.possibleMoves;
      });

      expect(notifyCount, 0);
    });

    test('selectWithMoves 一次性设置 position + moves', () {
      final state = GameStateManager();
      var notifyCount = 0;
      state.addListener(() => notifyCount++);

      state.selectWithMoves(const Coord(2, 2), [
        const Coord(3, 3),
        const Coord(4, 4),
      ]);

      expect(notifyCount, 1);
      expect(state.selectedPosition, const Coord(2, 2));
      expect(state.possibleMoves.length, 2);
    });
  });

  group('GameStateManager - 面板状态', () {
    test('toggleCloudPanel 状态在 cloud 和 none 之间切换', () {
      final state = GameStateManager();
      expect(state.leftPanel, PanelType.cloud);

      state.toggleCloudPanel();
      expect(state.leftPanel, PanelType.none);

      state.toggleCloudPanel();
      expect(state.leftPanel, PanelType.cloud);
    });

    test('showCloudPanel 总是置为 cloud', () {
      final state = GameStateManager();
      state.hideLeftPanel();
      expect(state.leftPanel, PanelType.none);

      state.showCloudPanel();
      expect(state.leftPanel, PanelType.cloud);
    });
  });
}
