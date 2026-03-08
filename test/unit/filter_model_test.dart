import 'package:flutter_test/flutter_test.dart';
import 'package:db_handler/lib/db/models/filter_model.dart';

void main() {
  group('FilterModel Tests', () {
    test('FilterModel toMap and fromMap should be consistent', () {
      final filter = FilterModel(
        column: 'name',
        operator: '=',
        value: 'John',
        logicalOperator: LogicalOperator.or,
        isNegated: true,
        openGroupCount: 1,
        closeGroupCount: 0,
        groupIndex: 0,
      );

      final map = filter.toMap();
      final fromMap = FilterModel.fromMap(map);

      expect(fromMap.id, filter.id);
      expect(fromMap.column, filter.column);
      expect(fromMap.operator, filter.operator);
      expect(fromMap.value, filter.value);
      expect(fromMap.logicalOperator, filter.logicalOperator);
      expect(fromMap.isNegated, filter.isNegated);
      expect(fromMap.openGroupCount, filter.openGroupCount);
      expect(fromMap.closeGroupCount, filter.closeGroupCount);
      expect(fromMap.groupIndex, filter.groupIndex);
    });

    test('FilterModel copyWith should update specific fields', () {
      final filter = FilterModel(
        column: 'age',
        operator: '>',
        value: 20,
      );

      final updated = filter.copyWith(value: 30, logicalOperator: LogicalOperator.or);

      expect(updated.id, filter.id);
      expect(updated.column, filter.column);
      expect(updated.operator, filter.operator);
      expect(updated.value, 30);
      expect(updated.logicalOperator, LogicalOperator.or);
    });
  });
}
