import 'package:flutter_test/flutter_test.dart';
import 'package:db_handler/stateManagement/setState/data_editing_riverpod.dart';
import 'package:db_handler/db/database_handler.dart';
import 'package:db_handler/sqflite/models/server_model.dart';

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

    test('Should handle sort order reordering', () {
      final sorts = [
        SortCondition(columnName: 'col1', isAscending: true),
        SortCondition(columnName: 'col2', isAscending: false),
      ];
      
      notifier.updateSorts(sorts);
      
      // Swap order
      final reordered = [sorts[1], sorts[0]];
      notifier.updateSorts(reordered);
      
      expect(notifier.state.sorts[0].columnName, 'col2');
      expect(notifier.state.sorts[1].columnName, 'col1');
    });

    test('Should detect group boundary correctly', () {
      final rows = [
        {'id': 1, 'category': 'A', 'name': 'Item 1'},
        {'id': 2, 'category': 'A', 'name': 'Item 2'},
        {'id': 3, 'category': 'B', 'name': 'Item 3'},
      ];
      
      // 이 테스트는 Notifier의 내부 상태나 Helper 메서드를 테스트해야 함
      // 현재는 UI에서 그룹 구분선을 표시하는 로직이 있으므로, Notifier가 groupByColumns를 잘 유지하는지 확인
      notifier.updateGroupBy(['category']);
      expect(notifier.state.groupByColumns, contains('category'));
    });
  });
}
