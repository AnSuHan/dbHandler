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
    notifier = DataEditingNotifier(mockDb, 'test_table', 'localhost:5432', 'test_db');
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

    // reorderFilterBlock operator preservation tests
    test('reorderFilterBlock: A OR B reordered to B OR A keeps OR operator', () {
      // Setup: A OR B
      // A has logicalOperator='OR' (operator between A and B)
      final filters = [
        FilterCondition(columnName: 'A', operator: '=', value: '1', logicalOperator: 'OR'),
        FilterCondition(columnName: 'B', operator: '=', value: '2'),
      ];
      notifier.updateFilters(filters);

      // _buildFilterBlockList() produces:
      //   index 0: filter(A)
      //   index 1: operator('OR')
      //   index 2: filter(B)
      // Move filter B (block 2) before filter A (block 0) → newIdx=0
      notifier.reorderFilterBlock(2, 0, null);

      // After reorder: B OR A
      // The OR operator should be preserved (not defaulted to AND)
      final result = notifier.state.filters;
      expect(result.length, 2);
      expect(result[0].columnName, 'B');
      expect(result[1].columnName, 'A');
      expect(result[0].logicalOperator, 'OR',
          reason: 'OR operator must be preserved after reorder (not defaulted to AND)');
    });

    test('reorderFilterBlock: A AND B OR C reordered to A OR C AND B keeps operators correctly', () {
      // Setup: A AND B OR C
      // A has logicalOperator='AND', B has logicalOperator='OR'
      final filters = [
        FilterCondition(columnName: 'A', operator: '=', value: '1', logicalOperator: 'AND'),
        FilterCondition(columnName: 'B', operator: '=', value: '2', logicalOperator: 'OR'),
        FilterCondition(columnName: 'C', operator: '=', value: '3'),
      ];
      notifier.updateFilters(filters);

      // _buildFilterBlockList() produces:
      //   index 0: filter(A)
      //   index 1: operator('AND')
      //   index 2: filter(B)
      //   index 3: operator('OR')
      //   index 4: filter(C)
      // Move filter C (block 4) to block index 2 (before B) → result: A, C, B
      // Operators in order after move: AND, OR (sequential assignment)
      // So result: A AND C OR B
      notifier.reorderFilterBlock(4, 2, null);

      final result = notifier.state.filters;
      expect(result.length, 3);
      expect(result[0].columnName, 'A');
      expect(result[1].columnName, 'C');
      expect(result[2].columnName, 'B');
      // Sequential operator assignment: AND goes between A-C, OR goes between C-B
      expect(result[0].logicalOperator, 'AND',
          reason: 'First operator (AND) must be preserved after reorder');
      expect(result[1].logicalOperator, 'OR',
          reason: 'Second operator (OR) must be preserved after reorder');
      expect(result[2].logicalOperator, isNull,
          reason: 'Last filter should have no logical operator');
    });
  });
}
