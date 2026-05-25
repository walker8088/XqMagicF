import 'package:flutter/material.dart';

class AppConstants {
  AppConstants._();

  // 棋盘尺寸
  static const int boardCols = 9; // 9条竖线
  static const int boardRows = 10; // 10条横线

  // 棋盘边距（格子数）
  static const int paddingCells = 2;

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
  static const double pieceRadiusRatio = 0.42;
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

extension PieceTypeExtension on PieceType {
  String displayName(PieceColor color) {
    const redNames = ['帅', '仕', '相', '傌', '俥', '炮', '兵'];
    const blackNames = ['将', '士', '象', '馬', '車', '砲', '卒'];
    final names = color == PieceColor.red ? redNames : blackNames;
    return names[index];
  }
}
