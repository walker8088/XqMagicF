import 'package:flutter_test/flutter_test.dart';
import 'package:xqmagic/utils/coord.dart';

void main() {
  group('Coord', () {
    test('should create coord with col and row', () {
      const coord = Coord(3, 5);
      expect(coord.col, 3);
      expect(coord.row, 5);
    });

    test('should support const constructor', () {
      const c1 = Coord(0, 0);
      const c2 = Coord(8, 9);
      expect(c1.col, 0);
      expect(c1.row, 0);
      expect(c2.col, 8);
      expect(c2.row, 9);
    });

    group('equality', () {
      test('should be equal when col and row match', () {
        const c1 = Coord(4, 5);
        const c2 = Coord(4, 5);
        expect(c1, c2);
      });

      test('should not be equal when col differs', () {
        const c1 = Coord(3, 5);
        const c2 = Coord(4, 5);
        expect(c1 != c2, isTrue);
      });

      test('should not be equal when row differs', () {
        const c1 = Coord(4, 5);
        const c2 = Coord(4, 6);
        expect(c1 != c2, isTrue);
      });

      test('should use identical for same instance', () {
        const c = Coord(1, 2);
        // ignore: unnecessary_statements
        expect(c == c, isTrue);
      });

      test('should not be equal to non-Coord object', () {
        const c = Coord(1, 2);
        expect(c == 'not a coord', isFalse);
      });
    });

    group('hashCode', () {
      test('should produce same hashCode for equal coords', () {
        const c1 = Coord(3, 4);
        const c2 = Coord(3, 4);
        expect(c1.hashCode, c2.hashCode);
      });

      test('should produce different hashCode for different coords', () {
        const c1 = Coord(1, 2);
        const c2 = Coord(3, 4);
        expect(c1.hashCode != c2.hashCode, isTrue);
      });

      test('should use formula col * 10 + row', () {
        const c = Coord(3, 7);
        expect(c.hashCode, 37);
      });

      test('should work for edge coordinates', () {
        const topLeft = Coord(0, 9); // top-left (black side, row 9)
        const bottomRight = Coord(8, 0); // bottom-right (red side, row 0)
        expect(topLeft.hashCode, 9);
        expect(bottomRight.hashCode, 80);
      });
    });

    group('copyWith', () {
      test('should return same coord when no args', () {
        const c = Coord(2, 3);
        final copied = c.copyWith();
        expect(copied.col, 2);
        expect(copied.row, 3);
      });

      test('should update col when provided', () {
        const c = Coord(2, 3);
        final copied = c.copyWith(col: 5);
        expect(copied.col, 5);
        expect(copied.row, 3);
      });

      test('should update row when provided', () {
        const c = Coord(2, 3);
        final copied = c.copyWith(row: 7);
        expect(copied.col, 2);
        expect(copied.row, 7);
      });

      test('should update both when provided', () {
        const c = Coord(2, 3);
        final copied = c.copyWith(col: 6, row: 1);
        expect(copied.col, 6);
        expect(copied.row, 1);
      });
    });

    group('toString', () {
      test('should format as (col,row)', () {
        const c = Coord(3, 5);
        expect(c.toString(), '(3,5)');
      });

      test('should handle zero values', () {
        const c = Coord(0, 0);
        expect(c.toString(), '(0,0)');
      });

      test('should handle max values', () {
        const c = Coord(8, 9);
        expect(c.toString(), '(8,9)');
      });
    });

    group('board boundaries', () {
      test('should support valid board range', () {
        // Red side: row 0-4, col 0-8
        // Black side: row 5-9, col 0-8
        const redBase = Coord(4, 0);
        const blackBase = Coord(4, 9);
        expect(redBase.row, lessThanOrEqualTo(4));
        expect(blackBase.row, greaterThanOrEqualTo(5));
        expect(redBase.col, inInclusiveRange(0, 8));
        expect(blackBase.col, inInclusiveRange(0, 8));
      });
    });

    group('Map key usage', () {
      test('should work as Map key', () {
        final map = <Coord, String>{};
        const key = Coord(3, 4);
        map[key] = 'test';
        expect(map[const Coord(3, 4)], 'test');
      });

      test('should retrieve value with different instance of same coord', () {
        final map = <Coord, String>{};
        const key = Coord(5, 6);
        map[key] = 'value';
        final lookup = Coord(5, 6);
        expect(map[lookup], 'value');
      });
    });
  });
}
