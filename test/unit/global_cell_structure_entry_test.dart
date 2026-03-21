// test/unit/global_cell_structure_entry_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:db_handler/stateManagement/setState/cell_structure_global_store.dart';
import 'package:db_handler/stateManagement/setState/cell_structure.dart';

void main() {
  // ──────────────────────────────────────────────
  // GlobalCellStructureEntry toJson / fromJson
  // ──────────────────────────────────────────────
  group('GlobalCellStructureEntry 컬럼 폭 직렬화', () {
    test('columnWidths / displayColumnWidths가 있을 때 toJson에 포함됨', () {
      final entry = GlobalCellStructureEntry(
        server: 'srv',
        database: 'db',
        table: 'tbl',
        structures: const {},
        columnWidths: [0.3, 0.4, 0.3],
        displayColumnWidths: [0.5, 0.5],
      );

      final json = entry.toJson();
      expect(json['columnWidths'], [0.3, 0.4, 0.3]);
      expect(json['displayColumnWidths'], [0.5, 0.5]);
    });

    test('columnWidths가 null이면 toJson에서 키 생략', () {
      final entry = GlobalCellStructureEntry(
        server: 'srv',
        database: 'db',
        table: 'tbl',
        structures: const {},
      );

      final json = entry.toJson();
      expect(json.containsKey('columnWidths'), isFalse);
      expect(json.containsKey('displayColumnWidths'), isFalse);
    });

    test('columnWidths가 빈 리스트이면 toJson에서 키 생략', () {
      final entry = GlobalCellStructureEntry(
        server: 'srv',
        database: 'db',
        table: 'tbl',
        structures: const {},
        columnWidths: [],
        displayColumnWidths: [],
      );

      final json = entry.toJson();
      expect(json.containsKey('columnWidths'), isFalse);
      expect(json.containsKey('displayColumnWidths'), isFalse);
    });

    test('fromJson으로 columnWidths 복원 (int → double 변환)', () {
      final json = <String, dynamic>{
        'server': 'srv',
        'database': 'db',
        'table': 'tbl',
        'structures': <String, dynamic>{},
        'columnWidths': [1, 2, 3],            // int로 저장된 경우
        'displayColumnWidths': [10, 20],
      };

      final entry = GlobalCellStructureEntry.fromJson(json);
      expect(entry.columnWidths, [1.0, 2.0, 3.0]);
      expect(entry.displayColumnWidths, [10.0, 20.0]);
    });

    test('fromJson: columnWidths 없으면 null', () {
      final json = <String, dynamic>{
        'server': 'srv',
        'database': 'db',
        'table': 'tbl',
        'structures': <String, dynamic>{},
      };

      final entry = GlobalCellStructureEntry.fromJson(json);
      expect(entry.columnWidths, isNull);
      expect(entry.displayColumnWidths, isNull);
    });

    test('fromJson: 잘못된 타입의 columnWidths → null', () {
      final json = <String, dynamic>{
        'server': 'srv',
        'database': 'db',
        'table': 'tbl',
        'structures': <String, dynamic>{},
        'columnWidths': 'not-a-list',
      };

      final entry = GlobalCellStructureEntry.fromJson(json);
      expect(entry.columnWidths, isNull);
    });

    test('toJson → fromJson 왕복 (double 정밀도 유지)', () {
      final original = GlobalCellStructureEntry(
        server: 'host:5432',
        database: 'mydb',
        table: 'users',
        structures: const {},
        columnWidths: [0.25, 0.50, 0.25],
        displayColumnWidths: [0.6, 0.4],
      );

      final restored = GlobalCellStructureEntry.fromJson(original.toJson());
      expect(restored.columnWidths, original.columnWidths);
      expect(restored.displayColumnWidths, original.displayColumnWidths);
    });
  });

  // ──────────────────────────────────────────────
  // GlobalCellStructureExport
  // ──────────────────────────────────────────────
  group('GlobalCellStructureExport fromJson', () {
    test('isGlobalFormat: formatVersion 키 있으면 true', () {
      expect(
        GlobalCellStructureExport.isGlobalFormat({'formatVersion': 'multi-table-1', 'entries': []}),
        isTrue,
      );
    });

    test('isGlobalFormat: entries 키만 있어도 true', () {
      expect(
        GlobalCellStructureExport.isGlobalFormat({'entries': []}),
        isTrue,
      );
    });

    test('isGlobalFormat: 둘 다 없으면 false', () {
      expect(
        GlobalCellStructureExport.isGlobalFormat({'foo': 'bar'}),
        isFalse,
      );
    });

    test('fromJson으로 entries 복원', () {
      final json = <String, dynamic>{
        'formatVersion': 'multi-table-1',
        'metadata': <String, dynamic>{'name': 'test', 'createdAt': '2026-01-01', 'table': 'tbl'},
        'entries': [
          <String, dynamic>{
            'server': 'srv',
            'database': 'db',
            'table': 'tbl',
            'structures': <String, dynamic>{},
            'columnWidths': [0.5, 0.5],
          }
        ],
      };

      final export = GlobalCellStructureExport.fromJson(json);
      expect(export.entries.length, 1);
      expect(export.entries[0].columnWidths, [0.5, 0.5]);
    });
  });
}
