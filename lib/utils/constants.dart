import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  // 棋盘尺寸
  static const int boardCols = 9; // 9条竖线
  static const int boardRows = 10; // 10条横线

  // 棋盘边距（格子数）
  static const int paddingCells = 1;

  /// 引擎 MultiPV 线路数量上限
  /// （下拉选项提供 1..maxMultiPV）
  static const int maxMultiPV = 5;

  /// 侧边面板默认尺寸
  static const double defaultSidePanelWidth = 260.0;
  static const double defaultRightPanelWidth = 280.0;
  static const double maxSidePanelWidth = 500.0;
  static const double minRightPanelWidth = 200.0;

  // 颜色
  static const Color boardBackground = Color(0xFFE8C576); // 木质底色
  static const Color gridLineColor = Color(0xFF5C3A1E); // 棋盘线
  static const Color redPieceColor = Color(0xFFCC0000); // 红方
  static const Color blackPieceColor = Color(0xFF1A1A1A); // 黑方
  static const Color pieceBackground = Color(0xFFF5E6C8); // 棋子底色
  static const Color pieceStroke = Color(0xFF8B6914); // 棋子描边
  static const Color selectedColor = Color(0xFF00CC44); // 选中高亮
  static const Color moveHintColor = Color(0x8800CC44); // 可走位置提示
  static const Color lastMoveColor = Color(0x66FFD700); // 上次移动高亮

  // 棋盘文字
  static const String redText = '红';
  static const String blackText = '黑';

  // 楚河汉界
  static const String riverText1 = '楚 河';
  static const String riverText2 = '汉 界';

  // 字体大小
  static const double pieceFontSize = 20.0;
  static const double riverFontSize = 18.0;

  // 棋子半径比例（占格子的比例）
  static const double pieceRadiusRatio = 0.45;
}

enum PieceColor { red, black }

enum PieceType {
  king, // 将/帅
  advisor, // 士/仕
  bishop, // 象/相
  knight, // 马/傌
  rook, // 车/俥
  cannon, // 炮/砲
  pawn, // 卒/兵
}

/// 棋子名称字表（中文，按 [PieceType] 索引顺序）。
///
/// 与 [ChineseNotation] 共享同一份数据源，避免记谱/界面两侧的繁简
/// 漂移。索引必须与 [PieceType] 一一对应（长度恒为 7）。
class PieceNames {
  PieceNames._();

  // ──── 简体中文（默认，与记谱一致） ────
  static const redSimple = ['帅', '仕', '相', '马', '车', '炮', '兵'];
  static const blackSimple = ['将', '士', '象', '马', '车', '炮', '卒'];

  // ──── 繁体中文 ────
  static const redTraditional = ['帥', '仕', '相', '傌', '俥', '砲', '兵'];
  static const blackTraditional = ['將', '士', '象', '馬', '車', '砲', '卒'];
}

extension PieceTypeExtension on PieceType {
  // 保留传统棋具的"红黑混繁简"显示习惯（红方马/车用傌/俥，黑方马/车/炮
  // 用馬/車/砲，其余简体）。该字表与 [PieceNames] 不可由简单公式推导，
  // 因此单独维护——如需统一为简体，调用方传 `useSimpleText: true`。
  static const _redMixed = ['帅', '仕', '相', '傌', '俥', '炮', '兵'];
  static const _blackMixed = ['将', '士', '象', '馬', '車', '砲', '卒'];

  /// 棋子显示名。
  ///
  /// - [useSimpleText] = false（默认）：保留"红黑混繁简"的传统显示习惯
  /// - [useSimpleText] = true：统一为简体（与 [ChineseNotation] 记谱一致）
  String displayName(PieceColor color, {bool useSimpleText = false}) {
    if (useSimpleText) {
      return color == PieceColor.red
          ? PieceNames.redSimple[index]
          : PieceNames.blackSimple[index];
    }
    return color == PieceColor.red ? _redMixed[index] : _blackMixed[index];
  }
}
