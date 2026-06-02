import 'package:flutter/material.dart';
import 'package:xqmagic/utils/constants.dart';
import 'package:xqmagic/viewmodels/game_viewmodel.dart';

/// 棋盘编辑面板：自由增删棋子、编辑局面
class BoardEditPanel extends StatelessWidget {
  const BoardEditPanel({super.key, required this.viewModel});

  final GameViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        border: Border(
          left: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildModeToggle(),
                  const SizedBox(height: 12),
                  _buildColorSelector(),
                  const SizedBox(height: 12),
                  _buildPiecePalette(),
                  const SizedBox(height: 16),
                  _buildSideToMove(),
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                  const SizedBox(height: 16),
                  _buildApplyButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.black.withValues(alpha: 0.3),
      child: Row(
        children: const [
          Icon(Icons.edit, size: 16, color: Color(0xFFF5DEB3)),
          SizedBox(width: 8),
          Text(
            '棋盘编辑',
            style: TextStyle(
              color: Color(0xFFF5DEB3),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 放置/删除模式切换
  Widget _buildModeToggle() {
    final placing = viewModel.editPlacing;
    return Row(
      children: [
        _modeButton(
          icon: Icons.add_circle_outline,
          label: '放置',
          isActive: placing,
          onTap: () => viewModel.setEditPlacing(true),
        ),
        const SizedBox(width: 8),
        _modeButton(
          icon: Icons.remove_circle_outline,
          label: '删除',
          isActive: !placing,
          onTap: () => viewModel.setEditPlacing(false),
        ),
      ],
    );
  }

  Widget _modeButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFF5DEB3).withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isActive
                  ? const Color(0xFFF5DEB3).withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive ? const Color(0xFFF5DEB3) : Colors.white54,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? const Color(0xFFF5DEB3) : Colors.white54,
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 红/黑方选择
  Widget _buildColorSelector() {
    return Row(
      children: [
        const Text(
          '棋子颜色',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(width: 12),
        _colorChip(PieceColor.red, '红', const Color(0xFFCC4444)),
        const SizedBox(width: 8),
        _colorChip(PieceColor.black, '黑', Colors.white70),
      ],
    );
  }

  /// 棋子类型选择面板
  Widget _buildPiecePalette() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '选择棋子',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 8),
        // 红方棋子
        _buildPieceRow(PieceColor.red),
        const SizedBox(height: 6),
        // 黑方棋子
        _buildPieceRow(PieceColor.black),
      ],
    );
  }

  Widget _buildPieceRow(PieceColor color) {
    final types = [
      PieceType.king,
      PieceType.advisor,
      PieceType.bishop,
      PieceType.knight,
      PieceType.rook,
      PieceType.cannon,
      PieceType.pawn,
    ];
    final redNames = ['帅', '仕', '相', '马', '车', '炮', '兵'];
    final blackNames = ['将', '士', '象', '马', '车', '炮', '卒'];

    return Row(
      children: List.generate(types.length, (i) {
        final type = types[i];
        final name = color == PieceColor.red ? redNames[i] : blackNames[i];
        final isActive =
            viewModel.editPieceType == type &&
            viewModel.editPieceColor == color;
        final pieceColor = color == PieceColor.red
            ? const Color(0xFFCC4444)
            : Colors.white70;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              onTap: () {
                viewModel.setEditPieceType(type);
                viewModel.setEditPieceColor(color);
              },
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isActive
                      ? pieceColor.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isActive
                        ? pieceColor
                        : Colors.white.withValues(alpha: 0.1),
                    width: isActive ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isActive ? pieceColor : Colors.white54,
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// 走子方选择
  Widget _buildSideToMove() {
    return Row(
      children: [
        const Text(
          '走子方',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(width: 12),
        _colorChip(
          PieceColor.red,
          '红方走',
          const Color(0xFFCC4444),
          isSideToMove: true,
        ),
        const SizedBox(width: 8),
        _colorChip(PieceColor.black, '黑方走', Colors.white70, isSideToMove: true),
      ],
    );
  }

  /// 带 isSideToMove 参数的 colorChip（复用于走子方选择）
  Widget _colorChip(
    PieceColor color,
    String label,
    Color chipColor, {
    bool isSideToMove = false,
  }) {
    final isActive = isSideToMove
        ? viewModel.editSideToMove == color
        : viewModel.editPieceColor == color;
    final onTap = isSideToMove
        ? () => viewModel.setEditSideToMove(color)
        : () => viewModel.setEditPieceColor(color);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? chipColor.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isActive ? chipColor : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? chipColor : Colors.white54,
            fontSize: 13,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// 操作按钮：清空、标准开局
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _actionButton(
            icon: Icons.delete_sweep,
            label: '清空',
            onTap: viewModel.editClearBoard,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _actionButton(
            icon: Icons.grid_on,
            label: '标准开局',
            onTap: viewModel.editInitStandard,
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.white70),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  /// 应用/取消按钮
  Widget _buildApplyButtons() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: viewModel.editCancel,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: const Text(
                '取消',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            onTap: viewModel.editApply,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF5DEB3).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFFF5DEB3).withValues(alpha: 0.5),
                ),
              ),
              child: const Text(
                '应用',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFF5DEB3),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
