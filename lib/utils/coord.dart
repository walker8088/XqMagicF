/// 棋盘坐标
class Coord {
  const Coord(this.col, this.row);

  final int col; // 0-8, 9条竖线
  final int row; // 0-9, 10条横线

  Coord copyWith({int? col, int? row}) =>
      Coord(col ?? this.col, row ?? this.row);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Coord && col == other.col && row == other.row;

  @override
  int get hashCode => col * 10 + row;

  @override
  String toString() => '($col,$row)';

  /// col 0-8 → file 'a'-'i'
  static String colToFile(int col) =>
      String.fromCharCode('a'.codeUnitAt(0) + col);

  /// file 'a'-'i' → col 0-8
  static int fileToCol(String file) =>
      file.toLowerCase().codeUnitAt(0) - 'a'.codeUnitAt(0);
}
