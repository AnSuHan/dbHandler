// test/unit/filter_sort_condition_frommap_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:db_handler/stateManagement/setState/data_editing_riverpod.dart';

void main() {
  // ──────────────────────────────────────────────
  // FilterCondition.fromMap (오늘 추가된 factory)
  // ──────────────────────────────────────────────
  group('FilterCondition.fromMap', () {
    test('모든 필드가 있을 때 정상 복원', () {
      final map = {
        'column': 'name',
        'operator': 'LIKE',
        'value': '%john%',
        'logicalOperator': 'OR',
        'openGroupCount': 1,
        'closeGroupCount': 2,
        'isNegated': true,
      };

      final fc = FilterCondition.fromMap(map);
      expect(fc.columnName, 'name');
      expect(fc.operator, 'LIKE');
      expect(fc.value, '%john%');
      expect(fc.logicalOperator, 'OR');
      expect(fc.openGroupCount, 1);
      expect(fc.closeGroupCount, 2);
      expect(fc.isNegated, isTrue);
    });

    test('누락된 선택 필드는 기본값으로 복원', () {
      final map = {'column': 'age', 'operator': '>', 'value': 18};
      final fc = FilterCondition.fromMap(map);

      expect(fc.columnName, 'age');
      expect(fc.operator, '>');
      expect(fc.value, 18);
      expect(fc.logicalOperator, isNull);
      expect(fc.openGroupCount, isNull);
      expect(fc.closeGroupCount, isNull);
      expect(fc.isNegated, isFalse);
    });

    test('column 키 없으면 빈 문자열', () {
      final map = {'operator': '=', 'value': 'x'};
      final fc = FilterCondition.fromMap(map);
      expect(fc.columnName, '');
    });

    test('operator 키 없으면 =', () {
      final map = {'column': 'col', 'value': 'v'};
      final fc = FilterCondition.fromMap(map);
      expect(fc.operator, '=');
    });

    test('isNegated 키 없으면 false', () {
      final map = {'column': 'col', 'operator': '=', 'value': 'v'};
      final fc = FilterCondition.fromMap(map);
      expect(fc.isNegated, isFalse);
    });

    test('value가 null이어도 정상 처리', () {
      final map = {'column': 'col', 'operator': 'IS NULL', 'value': null};
      final fc = FilterCondition.fromMap(map);
      expect(fc.value, isNull);
    });

    test('toMap → fromMap 왕복', () {
      final original = FilterCondition(
        columnName: 'price',
        operator: '>=',
        value: 100,
        logicalOperator: 'AND',
        openGroupCount: 1,
        closeGroupCount: 1,
        isNegated: false,
      );

      final restored = FilterCondition.fromMap(original.toMap());
      expect(restored.columnName, original.columnName);
      expect(restored.operator, original.operator);
      expect(restored.value, original.value);
      expect(restored.logicalOperator, original.logicalOperator);
      expect(restored.openGroupCount, original.openGroupCount);
      expect(restored.closeGroupCount, original.closeGroupCount);
      expect(restored.isNegated, original.isNegated);
    });
  });

  // ──────────────────────────────────────────────
  // SortCondition.fromMap (오늘 추가된 factory)
  // ──────────────────────────────────────────────
  group('SortCondition.fromMap', () {
    test('모든 필드가 있을 때 정상 복원', () {
      final map = {'column': 'created_at', 'ascending': false};
      final sc = SortCondition.fromMap(map);
      expect(sc.columnName, 'created_at');
      expect(sc.ascending, isFalse);
    });

    test('ascending 키 없으면 true(기본값)', () {
      final map = {'column': 'name'};
      final sc = SortCondition.fromMap(map);
      expect(sc.ascending, isTrue);
    });

    test('column 키 없으면 빈 문자열', () {
      final map = {'ascending': true};
      final sc = SortCondition.fromMap(map);
      expect(sc.columnName, '');
    });

    test('toMap → fromMap 왕복', () {
      const original = SortCondition(columnName: 'score', ascending: false);
      final restored = SortCondition.fromMap(original.toMap());
      expect(restored.columnName, original.columnName);
      expect(restored.ascending, original.ascending);
    });
  });
}
