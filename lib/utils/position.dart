/// 棋盘坐标
class Position {
  const Position(this.col, this.row);

  final int col; // 0-8, 9条竖线
  final int row; // 0-9, 10条横线

  Position copyWith({int? col, int? row}) =>
      Position(col ?? this.col, row ?? this.row);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Position && col == other.col && row == other.row;

  @override
  int get hashCode => col * 10 + row;

  @override
  String toString() => '($col,$row)';
}
