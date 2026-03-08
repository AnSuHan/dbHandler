import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:db_handler/stateManagement/setState/data_editing_riverpod.dart';
import 'package:db_handler/db/database_handler.dart';

// 간단한 Mock DatabaseHandler
class MockDatabaseHandler implements DatabaseHandler {
  @override
  Future<List<Map<String, dynamic>>> getColumns(String tableName) async => [];
  @override
  Future<String?> getPrimaryKey(String tableName) async => null;
  @override
  Future<List<Map<String, dynamic>>> getData(String tableName) async => [];
  @override
  Future<List<Map<String, dynamic>>> getDataWithFilters(String tableName, {List<Map<String, dynamic>>? filters, List<Map<String, dynamic>>? sorts, List<String>? groupByColumns}) async => [];
  
  // 나머지 메서드들은 구현 생략 (필요 시 추가)
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late DataEditingNotifier notifier;
  late MockDatabaseHandler mockDb;

  setUp(() {
    mockDb = MockDatabaseHandler();
    notifier = DataEditingNotifier(mockDb, 'test_table');
  });

  group('DataEditingNotifier Filter Logic Tests', () {
    test('Should validate balanced parentheses', () {
      final filters = [
        FilterCondition(columnName: 'col1', operator: '=', value: 'v1', openGroupCount: 1, logicalOperator: 'AND'),
        FilterCondition(columnName: 'col2', operator: '=', value: 'v2', closeGroupCount: 1),
      ];
      
      notifier.updateFilters(filters);
      expect(notifier.getValidationError(), isNull);
    });

    test('Should detect unbalanced parentheses (missing close)', () {
      final filters = [
        FilterCondition(columnName: 'col1', operator: '=', value: 'v1', openGroupCount: 1, logicalOperator: 'AND'),
        FilterCondition(columnName: 'col2', operator: '=', value: 'v2'),
      ];
      
      notifier.updateFilters(filters);
      expect(notifier.getValidationError(), contains('괄호 불균형'));
    });

    test('Should detect unbalanced parentheses (missing open)', () {
      final filters = [
        FilterCondition(columnName: 'col1', operator: '=', value: 'v1', logicalOperator: 'AND'),
        FilterCondition(columnName: 'col2', operator: '=', value: 'v2', closeGroupCount: 1),
      ];
      
      notifier.updateFilters(filters);
      expect(notifier.getValidationError(), contains('괄호 순서 오류'));
    });

    test('Should validate required fields in filters', () {
      final filters = [
        FilterCondition(columnName: '', operator: '=', value: 'v1'),
      ];
      
      notifier.updateFilters(filters);
      expect(notifier.getValidationError(), contains('컬럼명 필요'));
    });

    test('Should validate required value in filters except for NULL operators', () {
      final filters = [
        FilterCondition(columnName: 'col1', operator: 'IS NULL', value: null),
      ];
      
      notifier.updateFilters(filters);
      expect(notifier.getValidationError(), isNull);
      
      notifier.updateFilters([
        FilterCondition(columnName: 'col1', operator: '=', value: ''),
      ]);
      expect(notifier.getValidationError(), contains('값 필요'));
    });

    test('finalizeFilters should correctly calculate structure from blocks', () {
      // (col1 = v1) AND col2 = v2
      final filters = [
        FilterCondition(columnName: 'col1', operator: '=', value: 'v1', openGroupCount: 1, closeGroupCount: 1, logicalOperator: 'AND'),
        FilterCondition(columnName: 'col2', operator: '=', value: 'v2'),
      ];
      
      notifier.updateFilters(filters);
      notifier.finalizeFilters();
      
      expect(notifier.state.filters[0].openGroupCount, 1);
      expect(notifier.state.filters[0].closeGroupCount, 1);
      expect(notifier.state.filters[0].logicalOperator, 'AND');
    });

    test('Complex Nested Filter Logic: (A AND B) OR NOT C', () {
      // (col1 = 'v1' AND col2 = 'v2') OR NOT (col3 = 'v3')
      final filters = [
        FilterCondition(columnName: 'col1', operator: '=', value: 'v1', openGroupCount: 1, logicalOperator: 'AND'),
        FilterCondition(columnName: 'col2', operator: '=', value: 'v2', closeGroupCount: 1, logicalOperator: 'OR'),
        FilterCondition(columnName: 'col3', operator: '=', value: 'v3', isNegated: true),
      ];
      
      notifier.updateFilters(filters);
      expect(notifier.getValidationError(), isNull);
      
      final stateFilters = notifier.state.filters;
      expect(stateFilters[0].logicalOperator, 'AND');
      expect(stateFilters[1].logicalOperator, 'OR');
      expect(stateFilters[2].isNegated, isTrue);
    });

    test('Should handle sort order reordering', () {
      notifier.addSort(const SortCondition(columnName: 'col1', ascending: true));
      notifier.addSort(const SortCondition(columnName: 'col2', ascending: false));
      
      expect(notifier.state.sorts.length, 2);
      
      // Swap order
      notifier.reorderSorts(0, 1);
      
      expect(notifier.state.sorts[0].columnName, 'col2');
      expect(notifier.state.sorts[1].columnName, 'col1');
    });

    test('Complex Sort and GroupBy: Group by Category, then Sort by Price DESC', () {
      notifier.addGroupByColumn('category');
      notifier.addSort(const SortCondition(columnName: 'price', ascending: false));
      
      expect(notifier.state.groupByColumns, contains('category'));
      expect(notifier.state.sorts[0].columnName, 'price');
      expect(notifier.state.sorts[0].ascending, isFalse);
    });

    test('Should detect group boundary correctly', () {
      notifier.addGroupByColumn('category');
      expect(notifier.state.groupByColumns, contains('category'));
    });
  });
}
